# Exclusion List Database Runbook Blueprint

## 1. Overview

This runbook documents the workflow used to collect, clean, import, and validate provider exclusion list data for assigned states. The project uses PostgreSQL staging tables under the `exclusion_project` schema.

## 2. Source Collection

Raw state files are saved in `data/raw/`. Sources may be CSV, Excel, PDF, or copied text. Each state may use different terminology, including exclusion, suspension, sanction, termination, debarment, or administrative action.

## 3. File Organization

```text
data/raw/        Original source files
data/processed/  Cleaned PostgreSQL-ready CSVs
data/summaries/  Row counts and processing summaries
schema/          SQL scripts
scripts/         Python and PowerShell scripts
outputs/         Final runbook PDFs
```

## 4. Database Design

Database: `exclusion_lists_db`  
Schema: `exclusion_project`

The staging design uses one table per state. This allows messy state-specific data to be loaded and reviewed before later consolidation.

## 5. Staging Schema

The standard staging schema uses an auto-incrementing `id` primary key. All other columns are `VARCHAR NOT NULL` and blanks are filled with `N/A` during cleanup.

## 6. Cleaning Process

The cleanup script standardizes provider names, business names, NPIs, provider types, license numbers, action dates, reinstatement dates, authority fields, source URLs, and notes.

Typical cleanup steps:

1. Read raw source file.
2. Map original columns to staging columns.
3. Split individual names when possible.
4. Move organization names into `business_name`.
5. Standardize dates.
6. Fill blanks with `N/A`.
7. Remove exact duplicate rows.
8. Export clean CSV.

## 7. CSV Import Process

CSV files can be imported manually through pgAdmin or by using the command-line PowerShell script.

Manual pgAdmin path:

```text
Right-click staging table > Import/Export Data > Import > Select CSV > Header = Yes > Format = CSV
```

Command-line script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\import_all_staging_csvs.ps1
```

## 8. Validation

After import, run row counts:

```sql
SELECT COUNT(*) FROM exclusion_project.stg_california_exclusions;
```

Use the summary files in `data/summaries/` to compare expected row counts against imported row counts.

## 9. GitHub Maintenance

This repository can be maintained with GitHub CI/CD. Workflows in `.github/workflows/` validate the repository structure, check Python scripts, check CSV schemas, and build the runbook PDF.
