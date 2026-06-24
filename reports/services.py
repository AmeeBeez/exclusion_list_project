"""Database access helpers for the exclusion-list report."""

from __future__ import annotations

from math import ceil
import re
from typing import Any

from django.conf import settings
from django.db import connection


EXPECTED_COLUMNS = [
    "id",
    "record_type",
    "source_state",
    "source_state_abbr",
    "source_name",
    "provider_name",
    "first_name",
    "middle_name",
    "last_name",
    "business_name",
    "aka",
    "dba",
    "npi",
    "provider_type",
    "license_number",
    "provider_number",
    "action_type",
    "action_effective_date",
    "active_period",
    "exclusion_authority",
    "exclusion_reason",
    "reinstatement_date",
    "source_url",
    "source_file_url",
    "source_file_date",
    "date_accessed",
    "data_quality_status",
    "notes",
]

SEARCH_COLUMNS = [
    "provider_name",
    "business_name",
    "first_name",
    "last_name",
    "npi",
    "license_number",
    "provider_number",
    "exclusion_reason",
    "notes",
]

NAME_SEARCH_COLUMNS = [
    "provider_name",
    "business_name",
    "first_name",
    "middle_name",
    "last_name",
    "aka",
    "dba",
]

PROVIDER_CATEGORY_OPTIONS = ["Company", "Individual", "Unclassified"]

EXPORT_LIMIT = 100000


def _schema_name() -> str:
    return getattr(settings, "EXCLUSION_SCHEMA", "exclusion_project")


def quote_identifier(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", value):
        raise ValueError(f"Unsafe SQL identifier: {value}")
    return f'"{value}"'


def _dictfetchall(cursor) -> list[dict[str, Any]]:
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def _run_query(sql: str, params: list[Any] | None = None) -> list[dict[str, Any]]:
    with connection.cursor() as cursor:
        cursor.execute(sql, params or [])
        return _dictfetchall(cursor)


def discover_report_tables() -> tuple[list[str], list[dict[str, Any]]]:
    """Return valid reporting tables and skipped tables with reasons."""
    schema = _schema_name()
    table_rows = _run_query(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = %s
          AND table_type = 'BASE TABLE'
          AND (
              table_name = 'all_state_exclusions'
              OR table_name LIKE 'stg\\_%%\\_exclusions' ESCAPE '\\'
          )
        ORDER BY
          CASE WHEN table_name = 'all_state_exclusions' THEN 0 ELSE 1 END,
          table_name;
        """,
        [schema],
    )
    candidate_tables = [row["table_name"] for row in table_rows]
    if not candidate_tables:
        return [], []

    column_rows = _run_query(
        """
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = %s
          AND table_name = ANY(%s)
        ORDER BY table_name, ordinal_position;
        """,
        [schema, candidate_tables],
    )
    columns_by_table: dict[str, set[str]] = {table_name: set() for table_name in candidate_tables}
    for row in column_rows:
        columns_by_table[row["table_name"]].add(row["column_name"])

    valid_tables: list[str] = []
    skipped_tables: list[dict[str, Any]] = []
    expected = set(EXPECTED_COLUMNS)
    for table_name in candidate_tables:
        missing = sorted(expected - columns_by_table.get(table_name, set()))
        if missing:
            skipped_tables.append({"table_name": table_name, "missing_columns": missing})
        else:
            valid_tables.append(table_name)
    return valid_tables, skipped_tables


def _source_table_sql(table_names: list[str]) -> tuple[str, list[Any]]:
    schema = quote_identifier(_schema_name())
    column_sql = ", ".join(quote_identifier(column) for column in EXPECTED_COLUMNS)
    selects = []
    params: list[Any] = []
    for table_name in table_names:
        table_sql = f"{schema}.{quote_identifier(table_name)}"
        selects.append(f"SELECT %s AS staging_table, {column_sql} FROM {table_sql}")
        params.append(table_name)
    return " UNION ALL ".join(selects), params


def _has_value_sql(column: str) -> str:
    column_sql = quote_identifier(column)
    return f"NULLIF(NULLIF(BTRIM({column_sql}), ''), 'N/A') IS NOT NULL"


def _provider_category_sql() -> str:
    organization_markers = (
        "llc|inc|corp|company|clinic|center|services|group|hospital|"
        "facility|pharmacy|laboratory|labs|home health|agency|partners|"
        "associates|practice|medical|healthcare|care center|nursing|rehab"
    )
    return f"""
        CASE
            WHEN record_type ILIKE ANY (ARRAY['%%company%%', '%%organization%%', '%%business%%', '%%entity%%', '%%facility%%'])
                THEN 'Company'
            WHEN record_type ILIKE ANY (ARRAY['%%individual%%', '%%person%%'])
                THEN 'Individual'
            WHEN {_has_value_sql("business_name")}
                AND (
                    NOT ({_has_value_sql("first_name")} OR {_has_value_sql("last_name")})
                    OR LOWER(NULLIF(BTRIM(provider_name), '')) = LOWER(NULLIF(BTRIM(business_name), ''))
                )
                THEN 'Company'
            WHEN provider_name ~* %s
                THEN 'Company'
            WHEN {_has_value_sql("first_name")} OR {_has_value_sql("last_name")}
                THEN 'Individual'
            ELSE 'Unclassified'
        END
    """


def _where_clause(filters: dict[str, str]) -> tuple[str, list[Any]]:
    clauses: list[str] = []
    params: list[Any] = []

    query = filters.get("q", "").strip()
    if query:
        search_value = f"%{query}%"
        clauses.append("(" + " OR ".join(f"{column} ILIKE %s" for column in SEARCH_COLUMNS) + ")")
        params.extend([search_value] * len(SEARCH_COLUMNS))

    name = filters.get("name", "").strip()
    if name:
        search_value = f"%{name}%"
        clauses.append("(" + " OR ".join(f"{quote_identifier(column)} ILIKE %s" for column in NAME_SEARCH_COLUMNS) + ")")
        params.extend([search_value] * len(NAME_SEARCH_COLUMNS))

    npi = filters.get("npi", "").strip()
    if npi:
        clauses.append("npi ILIKE %s")
        params.append(f"%{npi}%")

    provider_category = filters.get("provider_category", "").strip()
    if provider_category in PROVIDER_CATEGORY_OPTIONS:
        clauses.append(f"({_provider_category_sql()}) = %s")
        params.extend([
            "llc|inc|corp|company|clinic|center|services|group|hospital|"
            "facility|pharmacy|laboratory|labs|home health|agency|partners|"
            "associates|practice|medical|healthcare|care center|nursing|rehab",
            provider_category,
        ])

    state = filters.get("state", "").strip()
    if state:
        clauses.append("source_state = %s")
        params.append(state)

    action_type = filters.get("action_type", "").strip()
    if action_type:
        clauses.append("action_type = %s")
        params.append(action_type)

    if not clauses:
        return "", []
    return "WHERE " + " AND ".join(clauses), params


def _query_from_tables(table_names: list[str], filters: dict[str, str]) -> tuple[str, list[Any]]:
    source_sql, source_params = _source_table_sql(table_names)
    where_sql, where_params = _where_clause(filters)
    return f"FROM ({source_sql}) records {where_sql}", source_params + where_params


def count_rows(table_names: list[str]) -> list[dict[str, Any]]:
    if not table_names:
        return []

    schema = quote_identifier(_schema_name())
    selects = []
    params: list[Any] = []
    for table_name in table_names:
        selects.append(
            f"SELECT %s AS table_name, COUNT(*)::bigint AS row_count FROM {schema}.{quote_identifier(table_name)}"
        )
        params.append(table_name)
    return _run_query(" UNION ALL ".join(selects) + " ORDER BY table_name;", params)


def choose_active_tables(table_names: list[str], table_counts: list[dict[str, Any]]) -> tuple[list[str], str]:
    counts = {row["table_name"]: int(row["row_count"]) for row in table_counts}
    if counts.get("all_state_exclusions", 0) > 0:
        return ["all_state_exclusions"], "Using consolidated all_state_exclusions as the report source."
    staging_tables = [table_name for table_name in table_names if table_name != "all_state_exclusions"]
    if staging_tables:
        return staging_tables, "Using individual staging tables because the consolidated table is empty or unavailable."
    return table_names, "Using available reporting tables."


def count_filtered_records(table_names: list[str], filters: dict[str, str] | None = None) -> int:
    if not table_names:
        return 0
    from_sql, params = _query_from_tables(table_names, filters or {})
    rows = _run_query(f"SELECT COUNT(*)::bigint AS record_count {from_sql};", params)
    return int(rows[0]["record_count"]) if rows else 0


def fetch_records(
    table_names: list[str],
    filters: dict[str, str],
    limit: int,
    offset: int = 0,
) -> list[dict[str, Any]]:
    if not table_names:
        return []
    from_sql, params = _query_from_tables(table_names, filters)
    params.extend([limit, offset])
    return _run_query(
        f"""
        SELECT *, {_provider_category_sql()} AS provider_category
        {from_sql}
        ORDER BY NULLIF(source_state, 'N/A'), NULLIF(provider_name, 'N/A'), id
        LIMIT %s OFFSET %s;
        """,
        [
            "llc|inc|corp|company|clinic|center|services|group|hospital|"
            "facility|pharmacy|laboratory|labs|home health|agency|partners|"
            "associates|practice|medical|healthcare|care center|nursing|rehab",
        ]
        + params,
    )


def distinct_values(table_names: list[str], column: str) -> list[str]:
    if not table_names:
        return []
    if column not in EXPECTED_COLUMNS:
        raise ValueError(f"Unsupported filter column: {column}")
    source_sql, params = _source_table_sql(table_names)
    rows = _run_query(
        f"""
        SELECT DISTINCT {quote_identifier(column)} AS value
        FROM ({source_sql}) records
        WHERE {quote_identifier(column)} IS NOT NULL
          AND {quote_identifier(column)} <> ''
          AND {quote_identifier(column)} <> 'N/A'
        ORDER BY value;
        """,
        params,
    )
    return [row["value"] for row in rows]


def summarize_by_state(table_names: list[str]) -> list[dict[str, Any]]:
    if not table_names:
        return []
    source_sql, params = _source_table_sql(table_names)
    return _run_query(
        f"""
        SELECT source_state, COUNT(*)::bigint AS row_count
        FROM ({source_sql}) records
        GROUP BY source_state
        ORDER BY row_count DESC, source_state
        LIMIT 12;
        """,
        params,
    )


def summarize_by_provider_category(table_names: list[str]) -> list[dict[str, Any]]:
    if not table_names:
        return []
    source_sql, params = _source_table_sql(table_names)
    category_params = [
        "llc|inc|corp|company|clinic|center|services|group|hospital|"
        "facility|pharmacy|laboratory|labs|home health|agency|partners|"
        "associates|practice|medical|healthcare|care center|nursing|rehab"
    ]
    return _run_query(
        f"""
        SELECT provider_category, COUNT(*)::bigint AS row_count
        FROM (
            SELECT {_provider_category_sql()} AS provider_category
            FROM ({source_sql}) records
        ) categorized
        GROUP BY provider_category
        ORDER BY
            CASE provider_category
                WHEN 'Company' THEN 1
                WHEN 'Individual' THEN 2
                ELSE 3
            END;
        """,
        category_params + params,
    )


def build_dashboard_context(filters: dict[str, str], requested_page: int) -> dict[str, Any]:
    page_size = max(1, int(getattr(settings, "REPORT_PAGE_SIZE", 50)))
    all_tables, skipped_tables = discover_report_tables()
    table_counts = count_rows(all_tables)
    active_tables, source_note = choose_active_tables(all_tables, table_counts)

    total_records = count_filtered_records(active_tables, {})
    filtered_records = count_filtered_records(active_tables, filters)
    page_count = max(1, ceil(filtered_records / page_size)) if filtered_records else 1
    page = min(max(1, requested_page), page_count)
    records = fetch_records(active_tables, filters, page_size, (page - 1) * page_size)
    states = distinct_values(active_tables, "source_state")
    action_types = distinct_values(active_tables, "action_type")
    provider_categories = PROVIDER_CATEGORY_OPTIONS

    return {
        "connected": True,
        "schema": _schema_name(),
        "all_tables": table_counts,
        "active_tables": active_tables,
        "skipped_tables": skipped_tables,
        "source_note": source_note,
        "states": states,
        "action_types": action_types,
        "provider_categories": provider_categories,
        "state_summary": summarize_by_state(active_tables),
        "provider_category_summary": summarize_by_provider_category(active_tables),
        "records": records,
        "filters": filters,
        "summary": {
            "total_records": total_records,
            "filtered_records": filtered_records,
            "source_table_count": len(active_tables),
            "state_count": len(states),
        },
        "pagination": {
            "page": page,
            "page_count": page_count,
            "has_previous": page > 1,
            "has_next": page < page_count,
            "previous_page": page - 1,
            "next_page": page + 1,
            "page_size": page_size,
        },
    }


def fetch_export_records(filters: dict[str, str]) -> list[dict[str, Any]]:
    all_tables, _skipped_tables = discover_report_tables()
    table_counts = count_rows(all_tables)
    active_tables, _source_note = choose_active_tables(all_tables, table_counts)
    return fetch_records(active_tables, filters, EXPORT_LIMIT, 0)
