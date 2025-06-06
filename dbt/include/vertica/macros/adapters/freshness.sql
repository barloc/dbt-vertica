{% macro vertica__current_timestamp() -%}
  current_timestamp
{%- endmacro %}


{% macro vertica__collect_freshness(source, loaded_at_field, filter) -%}
  {% call statement('collect_freshness', fetch_result=True, auto_begin=False) -%}
    select
      max({{ loaded_at_field }}) as max_loaded_at,
      {{ current_timestamp() }} as snapshotted_at
    from {{ source }}
    {% if filter %}
    where {{ filter }}
    {% endif %}
  {% endcall %}
  {{ return(load_result('collect_freshness').table) }}
{%- endmacro %}
