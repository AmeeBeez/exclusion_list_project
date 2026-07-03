from __future__ import annotations

import csv

from django.contrib.auth.decorators import login_required
from django.db import DatabaseError, OperationalError
from django.http import HttpResponse
from django.shortcuts import render

from .services import EXPECTED_COLUMNS, build_dashboard_context, fetch_export_records


def _report_filters(request) -> dict[str, str]:
    return {
        "q": request.GET.get("q", "").strip(),
        "name": request.GET.get("name", "").strip(),
        "npi": request.GET.get("npi", "").strip(),
        "provider_category": request.GET.get("provider_category", "").strip(),
        "state": request.GET.get("state", "").strip(),
        "action_type": request.GET.get("action_type", "").strip(),
    }


def _page_number(request) -> int:
    try:
        return int(request.GET.get("page", "1"))
    except ValueError:
        return 1


def _querystring_without_page(request) -> str:
    params = request.GET.copy()
    params.pop("page", None)
    return params.urlencode()


@login_required
def dashboard(request):
    filters = _report_filters(request)
    querystring = _querystring_without_page(request)
    context = {
        "filters": filters,
        "querystring": querystring,
        "page_url_prefix": f"?{querystring}&page=" if querystring else "?page=",
    }

    try:
        context.update(build_dashboard_context(filters, _page_number(request)))
    except (DatabaseError, OperationalError) as exc:
        context.update(
            {
                "connected": False,
                "database_error": str(exc),
                "records": [],
                "summary": {
                    "total_records": 0,
                    "filtered_records": 0,
                    "source_table_count": 0,
                    "state_count": 0,
                },
                "pagination": {
                    "page": 1,
                    "page_count": 1,
                    "has_previous": False,
                    "has_next": False,
                },
            }
        )
    return render(request, "reports/dashboard.html", context)


@login_required
def export_csv(request):
    filters = _report_filters(request)
    try:
        rows = fetch_export_records(filters)
    except (DatabaseError, OperationalError) as exc:
        return HttpResponse(f"Database export failed: {exc}", status=503, content_type="text/plain")

    response = HttpResponse(content_type="text/csv")
    response["Content-Disposition"] = 'attachment; filename="exclusion_report_export.csv"'
    writer = csv.DictWriter(response, fieldnames=["staging_table"] + EXPECTED_COLUMNS, extrasaction="ignore")
    writer.writeheader()
    writer.writerows(rows)
    return response
