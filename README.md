# Amalin's Exclusion List Runbook Project


## Full Project Description

The Exclusion List Project is a data science and documentation project focused on building a repeatable workflow for collecting, cleaning, staging, importing, validating, and documenting provider exclusion-list data from state sources.

The project supports the creation of a consolidated exclusion-list database using PostgreSQL and pgAdmin. The workflow begins with researching assigned state program-integrity websites, locating available exclusion, sanction, termination, suspension, debarment, or administrative-action lists, downloading or converting available source files, and preserving the raw files for auditability.

Because each state publishes data differently, the project uses a staging-table approach. Each state has its own PostgreSQL staging table under the `exclusion_project` schema. Raw files are cleaned with Python and transformed into a common staging schema before being imported into PostgreSQL. This keeps the workflow flexible enough to handle CSV, Excel, PDF, pasted text, and portal-based sources while still producing a consistent table structure for database loading.

The project also includes a reusable runbook blueprint. The runbook documents how the database was created, how the schema was designed, how source files are organized, how files are cleaned, how CSVs are imported into pgAdmin, how command-line imports can be performed with PowerShell and `psql`, and how imported records are validated with SQL row-count checks. This documentation is intended to help interns and team members explain the process clearly and repeat it for future projects.

## Main Goals

- Research official state exclusion-list sources.
- Preserve raw source files separately from cleaned outputs.
- Convert inconsistent source formats into standardized staging CSV files.
- Build and maintain PostgreSQL staging tables under the `exclusion_project` schema.
- Import cleaned CSV files into pgAdmin or through command-line `psql` workflows.
- Validate imports with SQL queries and row-count checks.
- Maintain a professional runbook blueprint with screenshots, diagrams, SQL snippets, Python scripts, and troubleshooting notes.
- Use GitHub as the project documentation and version-control hub.
- Use GitHub Actions CI/CD to validate the repository structure, Python scripts, CSV schema, and PDF runbook generation.

## Technologies Used

- PostgreSQL
- pgAdmin 4
- Django
- psycopg PostgreSQL driver
- Python
- PowerShell
- CSV and Excel file processing
- PDF-to-CSV conversion workflow
- SQL schema migration scripts
- GitHub version control
- GitHub Actions CI/CD
- Markdown runbook documentation
- PDF runbook outputs

## Repository Purpose

This repository stores the full working blueprint for the exclusion-list database workflow. It includes documentation, schema files, cleaning scripts, import scripts, processed-data structure, screenshots, and runbook outputs. It is designed to make the project explainable, repeatable, and auditable.

## Workflow Summary

```text
State or source website
        ↓
Raw source file download or conversion
        ↓
Python cleaning and standardization
        ↓
staging CSV
        ↓
PostgreSQL staging table import
        ↓
SQL validation and row-count checks
        ↓
Runbook documentation and GitHub version control
        ↓
CI/CD validation and PDF runbook generation
```

## Database Design Summary

The PostgreSQL database uses a project schema named `exclusion_project`. Each assigned state has a separate staging table, for example:
- `stg_alabama_exclusions`
- `stg_alaska_exclusions`
- `stg_arizona_exclusions`
- `stg_arkansas_exclusions`
- `stg_california_exclusions`
- `stg_colorado_exclusions`
- `stg_connecticut_exclusions`
- `stg_delaware_exclusions`
- `stg_district_of_columbia_exclusions`
- `stg_florida_exclusions`

The staging schema follows the updated approach:

- `id` as an auto-incrementing primary key
- all remaining columns as `VARCHAR`
- workflow/source fields required with `NOT NULL`
- sparse source-provided fields nullable so blank CSV values import as database `NULL`
- individual names split into `first_name`, `middle_name`, and `last_name`
- organization names stored in `business_name`
- source details preserved through `source_url`, `source_file_url`, `source_file_date`, `date_accessed`, and `notes`

## Documentation Purpose

The runbook blueprint is the main explanation document for the project. It is designed to show:

- what problem the project solves
- where the data comes from
- how files are organized
- how data is cleaned
- how the database schema is created
- how CSV files are imported
- how validation is performed
- what errors were encountered and how they were fixed
- how the workflow can be reused in future projects

## CI/CD Purpose

GitHub Actions workflows are included to support project maintenance. The CI/CD setup is intended to:

- confirm required folders and files exist
- compile Python scripts for syntax errors
- validate processed CSV headers against the expected staging schema
- build the Markdown runbook into a PDF artifact
- support a professional documentation workflow with version history

## Current Status

The repository package includes the organized runbook structure, schema scripts, Python cleaning scripts, import scripts, GitHub Actions workflow files, and PDF runbook outputs. Additional source files, screenshots, and processed CSVs can be added as the project continues.



This repository documents the exclusion list database project workflow: source collection, data cleaning, PostgreSQL staging schema, CSV import, validation, and runbook documentation.

## Project Purpose

The goal is to create a repeatable workflow for collecting state provider exclusion data, cleaning inconsistent source files, loading the standardized results into PostgreSQL staging tables, and documenting the process with a runbook blueprint.

## Main Folders

| Folder | Purpose |
|---|---|
| `docs/` | Meeting notes and runbook source documentation |
| `schema/` | SQL scripts for backup, schema replacement, and table creation |
| `scripts/` | Python and PowerShell scripts for cleanup and import |
| `exclusion_report/` | Django project settings and URL routing for the local report |
| `reports/` | Django report views, database-query helpers, templates, and styling |
| `data/raw/` | Original files downloaded/uploaded from state sources |
| `data/processed/` | Cleaned CSV files ready for staging tables |
| `data/summaries/` | Row counts, conversion summaries, and source confirmation files |
| `assets/screenshots/` | Screenshots used in the runbook |
| `outputs/` | Generated PDFs and final deliverables |
| `.github/workflows/` | CI/CD workflows for validation and PDF build automation |

## Current Workflow

1. Collect official exclusion/sanction/termination files from state websites.
2. Save raw files in `data/raw/`.
3. Clean and standardize files using scripts in `scripts/`.
4. Save PostgreSQL-ready CSVs in `data/processed/`.
5. Run SQL scripts in `schema/` to create or replace staging tables.
6. Import CSVs into pgAdmin or with the PowerShell command-line script.
7. Validate row counts and data quality using SQL.
8. Update the runbook PDF in `outputs/`.

## PostgreSQL Location

Database:

```text
exclusion_lists_db
```

Schema:

```text
exclusion_project
```

Tables follow this naming pattern:

```text
stg_<state>_exclusions
```

Example:

```text
stg_california_exclusions
```

## Django Exclusion Report

This repository now includes a local Django report for professionally displaying the exclusion-list data already imported into PostgreSQL. The report reads the existing `exclusion_project` schema and does not require changing the staging-table workflow.

### Default PostgreSQL connection

The Django settings use the local PostgreSQL defaults for this project:

| Setting | Default |
|---|---|
| Database engine | PostgreSQL |
| Database name | `exclusion_lists_db` |
| User | `postgres` |
| Password | prompted at server startup if not already set |
| Host | `localhost` |
| Port | `5432` |
| Schema search path | `exclusion_project,public` |

When you start the Django report, it prompts for the local `postgres` password. Press Enter if your local PostgreSQL user does not use a password.

Optional overrides are also supported. Set `POSTGRES_PASSWORD` first if you want to skip the startup prompt:

```powershell
$env:POSTGRES_PASSWORD="your_postgres_password"
$env:POSTGRES_DB="exclusion_lists_db"
$env:POSTGRES_USER="postgres"
$env:POSTGRES_HOST="localhost"
$env:POSTGRES_PORT="5432"
$env:EXCLUSION_SCHEMA="exclusion_project"
```

### Process files before generating the report

Run these steps from the repository root. The report reads PostgreSQL, so the CSV files must be cleaned, validated, and imported before the Django page can show records.

1. Create a Python environment and install the project dependencies.

Choose one setup option. After the environment is activated, the remaining commands use `python` and work the same way for standard Python, Anaconda, conda, or `uv`.

Option A: standard Python

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Option B: Anaconda or conda

Open Anaconda Prompt or a PowerShell terminal where `conda` is available, then run either:

```powershell
conda env create -f environment.yml
conda activate exclusion_list_project
```

or, if you prefer a named environment and direct pip install:

```powershell
conda create -n exclusion-report python=3.12 -y
conda activate exclusion-report
python -m pip install -r requirements.txt
```

Option C: `uv`

Use this option when regular Python or global `pip` is not available.

```powershell
uv venv .venv
.\.venv\Scripts\Activate.ps1
uv pip install -r requirements.txt
```

2. Put uploaded source CSV files in `assets/` or `data/raw/`. If the files are already cleaned and already match the staging schema, put them directly in `data/processed/` and skip to step 4.

3. Clean uploaded CSV files into the standard staging schema.

If the uploaded files are in `assets/`:

```powershell
python .\scripts\clean_to_schema.py --input-dir .\assets --output-dir .\data\processed
```

If the uploaded files are in `data/raw/`:

```powershell
python .\scripts\clean_to_schema.py --input-dir .\data\raw --output-dir .\data\processed
```

The cleaner detects the state from the file contents when possible and writes PostgreSQL-ready files to `data/processed/` using names like:

```text
stg_alabama_exclusions.csv
```

4. Validate the processed CSV headers before importing them.

```powershell
python .\scripts\validate_csv_schema.py
```

5. Create or replace the PostgreSQL staging tables.

Use pgAdmin Query Tool to run:

```text
schema/001_backup_and_replace_schema.sql
```

Or run the same SQL file from PowerShell with the local PostgreSQL defaults:

```powershell
$env:PGPASSWORD="your_postgres_password"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -p 5432 -U postgres -d exclusion_lists_db -f .\schema\001_backup_and_replace_schema.sql
```

6. Import the processed CSV files into PostgreSQL.

The import script defaults to `data/processed/` and imports files into the matching `exclusion_project.stg_<state>_exclusions` tables.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\import_all_staging_csvs.ps1
```

If your processed files are in another folder, pass it explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\import_all_staging_csvs.ps1 -CsvFolder .\assets
```

7. Prepare the Django user interface.

The report uses Django's built-in authentication and admin interface. Run migrations once, then create a Django user account for signing in.

If your virtual environment is activated:

```powershell
python manage.py migrate
python manage.py createsuperuser
```

If you are using the repository `.venv` without activating it:

```powershell
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py createsuperuser
```

Use the superuser account to sign in at `/login/`. Staff users can also open the Django admin at `/admin/`.

8. Start the Django report after the database import and Django setup are complete. Enter your PostgreSQL password when prompted, or press Enter for a blank password.

Recommended launcher:

```powershell
powershell -ExecutionPolicy Bypass -File .\launch_site.ps1
```

The launcher loads optional settings from `.env`, prompts for the PostgreSQL password, uses `.venv` when it exists, opens the local report URL, and starts Django.

To start the server without opening a browser:

```powershell
powershell -ExecutionPolicy Bypass -File .\launch_site.ps1 -NoBrowser
```

Manual command:

```powershell
python manage.py runserver
```

Or, without activating `.venv`:

```powershell
.\.venv\Scripts\python.exe manage.py runserver
```

Open the report at:

```text
http://127.0.0.1:8000/
```

Useful Django UI routes:

| Route | Purpose |
|---|---|
| `/login/` | Sign in with a Django user account |
| `/logout/` | Sign out |
| `/admin/` | Django admin interface for staff users |
| `/` | Authenticated exclusion-list dashboard |
| `/export.csv` | Authenticated CSV export for the current filters |

The report includes:

- summary totals for records, matched rows, source tables, and represented states
- search across provider, business, NPI, license, provider number, reason, and notes
- filters for state and action type
- source-table coverage counts
- top state coverage counts
- CSV export at `/export.csv`

### Data source behavior

The report checks PostgreSQL tables in this order:

1. If `exclusion_project.all_state_exclusions` exists and contains rows, the report uses it as the consolidated reporting source.
2. If `all_state_exclusions` is empty or unavailable, the report unions the individual staging tables named `stg_<state>_exclusions`.
3. Tables are skipped if they do not match the expected staging columns used by the cleaning and validation scripts.

### Relational database direction

The current staging-table design is good for loading inconsistent state files because every source can be preserved with minimal transformation. For a stronger relational reporting layer, keep the staging tables as audit-friendly raw imports and add normalized reporting tables such as:

| Table | Purpose |
|---|---|
| `states` | One row per state or jurisdiction |
| `sources` | Source website, file URL, access date, and source-file date |
| `providers` | Provider or business identity fields such as names, NPI, license, and provider number |
| `exclusion_actions` | Action type, effective date, authority, reason, reinstatement date, and data-quality status |

Recommended path:

1. Continue importing uploaded CSVs into `exclusion_project.stg_<state>_exclusions`.
2. Validate the staging tables with row counts and schema checks.
3. Add a consolidation SQL step that inserts clean, deduplicated rows into normalized reporting tables.
4. Point Django models at the normalized tables when the structure is stable.
5. Keep the current raw-SQL dashboard as the staging report until the normalized layer is ready.

## Important Scripts

| Script | Purpose |
|---|---|
| `scripts/clean_to_schema.py` | Cleans uploaded CSVs into the standard staging schema |
| `scripts/import_all_staging_csvs.ps1` | Imports processed CSVs from `data/processed/` into PostgreSQL using `psql` |
| `scripts/validate_csv_schema.py` | CI validation script that checks processed CSV headers |

## Important SQL

| File | Purpose |
|---|---|
| `schema/001_backup_and_replace_schema.sql` | Backs up old project tables and recreates staging tables using the updated schema |

## Runbook Output

The expanded runbook blueprint is stored in:

```text
outputs/amalin_exclusion_database_runbook_blueprint_expanded.pdf
```

Use this PDF to explain the project workflow, database structure, cleanup process, import process, validation steps, and future GitHub CI/CD plan.
