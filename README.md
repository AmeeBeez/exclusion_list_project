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
- all required columns set as `NOT NULL`
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

## Important Scripts

| Script | Purpose |
|---|---|
| `scripts/clean_schema.py` | Cleans raw or processed CSVs into the staging schema |
| `scripts/import_all_staging_csvs.ps1` | Imports multiple processed CSVs into PostgreSQL using `psql` |
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
