{% macro vertica__create_table_as(temporary, relation, sql) -%}
  {%- set sql_header = config.get('sql_header', none) -%}
  {{ sql_header if sql_header is not none }}
  {%- set order_by = config.get('order_by', none) -%}
  {%- set segmented_by_string = config.get('segmented_by_string', default=none) -%}
  {%- set segmented_by_all_nodes = config.get('segmented_by_all_nodes', default=True) -%}
  {%- set no_segmentation = config.get('no_segmentation', default=False) -%}
  {%- set ksafe = config.get('ksafe', default=none) -%}
  {%- set partition_by_string = config.get('partition_by_string', default=none) -%}
  {%- set partition_by_group_by_string = config.get('partition_by_group_by_string', default=none) -%}
  {%- set partition_by_active_count = config.get('partition_by_active_count', default=none) -%}
  {%- set primary_key_columns_by_string = config.get('primary_key_columns_by_string', default=none) -%}

  create {% if temporary: -%}local temporary{%- endif %} table
    {{ relation.include(database=(not temporary), schema=(not temporary)) }}
    {% if temporary: -%}on commit preserve rows{%- endif %}
    INCLUDE SCHEMA PRIVILEGES as (
    {{ sql }}
  )

  {% if not temporary: %}
    {% if order_by is not none  -%}
        order by {{ order_by }}
    {% endif -%}

    {% if segmented_by_string is not none -%}
                segmented  BY  {{ segmented_by_string }} {% if segmented_by_all_nodes %} ALL NODES {% endif %}
    {% endif %}

    {% if no_segmentation =='True' or no_segmentation=='true'  -%}
      UNSEGMENTED ALL NODES
    {% endif -%}

    {% if ksafe is not none -%}
      ksafe {{ ksafe }}
    {% endif -%}

    {% if partition_by_string is not none -%}
      ; ALTER TABLE {{ relation.include(database=(not temporary), schema=(not temporary)) }} PARTITION BY {{ partition_by_string }}
      {% if partition_by_group_by_string is not none -%}
        GROUP BY {{ partition_by_group_by_string }}
      {% endif %}
      {% if partition_by_active_count is not none %}
        SET ACTIVEPARTITIONCOUNT {{ partition_by_active_count }}
      {% endif %}
      ; ALTER TABLE {{ relation.include(database=(not temporary), schema=(not temporary)) }} REORGANIZE;
    {% endif %}

    {% if primary_key_columns_by_string is not none -%}
      ; ALTER TABLE {{ relation.include(database=(not temporary), schema=(not temporary)) }} ADD CONSTRAINT pk PRIMARY KEY ({{ primary_key_columns_by_string }}) ENABLED
    {% endif -%}
  {% endif %}
  ;
{% endmacro %}
