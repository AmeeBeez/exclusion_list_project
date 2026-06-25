# C4 Component Diagram

This page maps the main application components inside the Django reporting app and the cleanup scripts.

```mermaid
C4Component
    title Exclusion List Project Component Diagram

    Container(djangoApp, "Django Reporting App", "Python / Django") {
        Component(views, "reports.views", "Django view functions", "Handles dashboard rendering and CSV export.")
        Component(services, "reports.services", "Reporting helpers", "Discovers reporting tables, builds filters, and fetches staging records.")
        Component(templates, "reports/templates/reports/dashboard.html", "HTML template", "Displays report summary, filters, and records.")
    }

    Container(cleanPipeline, "Cleanup Scripts", "Python / PowerShell") {
        Component(cleanScript, "scripts/clean_to_schema.py", "Cleaning script", "Maps raw input columns to staging schema, infers entity category, and writes cleaned CSV.")
        Component(importScript, "scripts/import_all_staging_csvs.ps1", "Import script", "Loads processed CSVs into PostgreSQL staging tables.")
        Component(validateSchema, "scripts/validate_csv_schema.py", "Schema validator", "Checks processed CSV headers against expected staging columns.")
    }

    Container(postgresDb, "PostgreSQL Database", "PostgreSQL") {
        Component(stagingTables, "exclusion_project staging tables", "SQL tables", "Store cleaned state staging data.")
        Component(consolidatedTable, "all_state_exclusions", "SQL table", "Optional consolidated reporting source if available.")
    }

    Rel(djangoApp, postgresDb, "Queries report data from")
    Rel(cleanPipeline, postgresDb, "Imports cleaned CSV data into")
    Rel(views, services, "Uses")
    Rel(views, templates, "Renders")
    Rel(services, postgresDb, "Reads")
    Rel(cleanScript, stagingTables, "Writes")
    Rel(importScript, stagingTables, "Loads")
    Rel(validateSchema, stagingTables, "Verifies schema for")
```