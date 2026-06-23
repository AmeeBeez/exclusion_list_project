from django.urls import path

from . import views


app_name = "reports"

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("export.csv", views.export_csv, name="export_csv"),
]
