"""URL routes for the exclusion report project."""

from django.urls import include, path


urlpatterns = [
    path("", include("reports.urls")),
]
