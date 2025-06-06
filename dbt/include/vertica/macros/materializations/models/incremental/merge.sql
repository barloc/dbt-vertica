{% macro vertica__get_merge_sql(target_relation, tmp_relation, unique_key, dest_columns) %}
  {%- set dest_columns_csv =  get_quoted_csv(dest_columns | map(attribute="name")) -%}
  {%- set merge_columns = config.get("unique_key", default=None)%}
  {%- set merge_update_columns = config.get("merge_update_columns", default=dest_columns)-%}
  {% if merge_update_columns %}
    {%- set merge_update_columns = dest_columns -%}
  {% endif %}

  merge into {{ target_relation }} as DBT_INTERNAL_DEST
  using {{ tmp_relation }} as DBT_INTERNAL_SOURCE

  {#-- Test 1, find the provided merge columns #}
  {% if merge_columns %}
    on 
    {% for column in [merge_columns] %}
      DBT_INTERNAL_DEST.{{ adapter.quote(column) }} = DBT_INTERNAL_SOURCE.{{ adapter.quote(column) }}
      {%- if not loop.last %} AND {% endif %} 
    {%- endfor %}
  {#-- Test 2, use all columns in the destination table #}
  {% else %}
    on
    {% for column in dest_columns -%}
      DBT_INTERNAL_DEST.{{ adapter.quote(column.name) }} = DBT_INTERNAL_SOURCE.{{ adapter.quote(column.name) }} 
      {%- if not loop.last %} AND {% endif %}
    {%- endfor %}
  {% endif %}

  when matched then update set
  {% for column in merge_update_columns -%}
    {{ adapter.quote(column.name) }} = DBT_INTERNAL_SOURCE.{{ adapter.quote(column.name) }}
    {%- if not loop.last %}, {% endif %}
  {%- endfor %}

  when not matched then insert
    ({{ dest_columns_csv }})
  values
  (
    {% for column in dest_columns -%}
       DBT_INTERNAL_SOURCE.{{ adapter.quote(column.name) }}
       {%- if not loop.last %}, {% endif %}
    {%- endfor %}
  )
{%- endmacro %}

{% macro vertica__get_delete_insert_merge_sql(target, source, unique_key, dest_columns) -%}

    {%- set dest_cols_csv = get_quoted_csv(dest_columns | map(attribute="name")) -%}

    {% if unique_key %}
        delete from {{ target }}
            where (
                {{ unique_key }}) in (
                select {{ unique_key }}
                from {{ source }}
            );

    {% endif %}

    insert into {{ target }} ({{ dest_cols_csv }})
    (
        select {{ dest_cols_csv }}
        from {{ source }}
    );

{%- endmacro %}


{% macro vertica__get_insert_overwrite_merge_sql(target_relation, source, dest_columns) -%}
    {%- set partition_by_string = config.get('partition_by_string', default=none) -%}
    {%- set partitions = config.get('partitions') -%}
    {%- set dest_cols_csv = get_quoted_csv(dest_columns | map(attribute="name")) -%}

    {% if partition_by_string == none %}
      DELETE FROM {{ target_relation }};

      insert into {{ target_relation }} ({{ dest_cols_csv }})
      (
          select {{ dest_cols_csv }}
          from {{ source }}
      );
    {% else %}     

      select PARTITION_TABLE('{{ target_relation.schema }}.{{ target_relation.table }}');
      
      {% if partitions == none %}
        {% set get_distinct_partitions %}
          SELECT DISTINCT {{ partition_by_string }} from {{ source }}
        {% endset %}

        {% set results =  run_query(get_distinct_partitions) %}
        {% set partitions = results.columns[0].values() %}
      {% endif %}

      {% for partition in partitions %}
          SELECT DROP_PARTITIONS('{{ target_relation.schema }}.{{ target_relation.table }}', '{{ partition }}', '{{ partition }}');
          SELECT PURGE_PARTITION('{{ target_relation.schema }}.{{ target_relation.table }}', '{{ partition }}');
      {% endfor %}

      insert into {{ target_relation }} ({{ dest_cols_csv }})
      (
        select {{ dest_cols_csv }}
        from {{ source }}
      );

    {% endif %}


{% endmacro %}

