<#
Import all staging CSV files into PostgreSQL using psql from PowerShell.

How to use:
1. Put this script in the same folder as your processed CSV files, OR update $CsvFolder below.
2. Update $PsqlPath, $Database, $Username, $Host, $Port if needed.
3. Run PowerShell as normal user.
4. Execute:
   powershell -ExecutionPolicy Bypass -File .\import_all_staging_csvs.ps1

Assumptions:
- Database: exclusion_lists_db
- Schema: exclusion_project
- Tables already exist with schema.
- CSV files have headers matching the table columns.
- If the CSV contains an id column, the script imports it and then resets the sequence.
#>

$ErrorActionPreference = "Stop"

# ---------- EDIT THESE SETTINGS ----------
$PsqlPath = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$Database = "exclusion_lists_db"
$Username = "postgres"
$HostName = "localhost"
$Port = "5432"
$Schema = "exclusion_project"

# Use the folder where this script is located.
$CsvFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
# ----------------------------------------

if (-not (Test-Path $PsqlPath)) {
    Write-Host "psql.exe was not found at: $PsqlPath" -ForegroundColor Red
    Write-Host "Update `$PsqlPath in this script to your PostgreSQL bin folder." -ForegroundColor Yellow
    exit 1
}

$Imports = @(
    @{ File = "stg_alabama_exclusions_processed.csv"; Table = "stg_alabama_exclusions" },
    @{ File = "stg_alaska_exclusions_processed.csv"; Table = "stg_alaska_exclusions" },
    @{ File = "stg_arizona_exclusions_processed.csv"; Table = "stg_arizona_exclusions" },
    @{ File = "stg_arkansas_exclusions_processed.csv"; Table = "stg_arkansas_exclusions" },
    @{ File = "stg_california_exclusions_processed.csv"; Table = "stg_california_exclusions" },
    @{ File = "stg_colorado_exclusions_processed.csv"; Table = "stg_colorado_exclusions" },
    @{ File = "stg_connecticut_exclusions_processed.csv"; Table = "stg_connecticut_exclusions" },
    @{ File = "stg_delaware_exclusions_processed.csv"; Table = "stg_delaware_exclusions" },
    @{ File = "stg_district_of_columbia_exclusions_processed.csv"; Table = "stg_district_of_columbia_exclusions" },
    @{ File = "stg_florida_exclusions_processed.csv"; Table = "stg_florida_exclusions" }
)

Write-Host "Starting CSV import..." -ForegroundColor Cyan
Write-Host "Database: $Database" -ForegroundColor Cyan
Write-Host "Schema:   $Schema" -ForegroundColor Cyan
Write-Host "Folder:   $CsvFolder" -ForegroundColor Cyan
Write-Host ""

foreach ($item in $Imports) {
    $CsvPath = Join-Path $CsvFolder $item.File
    $TableName = $item.Table
    $FullTable = "$Schema.$TableName"

    if (-not (Test-Path $CsvPath)) {
        Write-Host "SKIPPED: $($item.File) not found." -ForegroundColor Yellow
        continue
    }

    # Convert backslashes to forward slashes for psql \copy compatibility.
    $PsqlCsvPath = $CsvPath.Replace("\", "/")

    Write-Host "Importing $($item.File) -> $FullTable" -ForegroundColor Green

    $Sql = @"
TRUNCATE TABLE $FullTable RESTART IDENTITY;
\copy $FullTable FROM '$PsqlCsvPath' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');
SELECT '$TableName' AS table_name, COUNT(*) AS imported_rows FROM $FullTable;
SELECT setval(pg_get_serial_sequence('$FullTable', 'id'), COALESCE((SELECT MAX(id) FROM $FullTable), 1), true);
"@

    $TempSql = Join-Path $env:TEMP "import_$TableName.sql"
    Set-Content -Path $TempSql -Value $Sql -Encoding UTF8

    & $PsqlPath -h $HostName -p $Port -U $Username -d $Database -f $TempSql

    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $($item.File)" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Remove-Item $TempSql -Force
    Write-Host "Done: $TableName" -ForegroundColor Green
    Write-Host ""
}

Write-Host "All available CSV imports completed." -ForegroundColor Cyan

Write-Host "Final row counts:" -ForegroundColor Cyan
$CountSql = @"
SELECT 'stg_alabama_exclusions' AS table_name, COUNT(*) AS rows FROM $Schema.stg_alabama_exclusions
UNION ALL SELECT 'stg_alaska_exclusions', COUNT(*) FROM $Schema.stg_alaska_exclusions
UNION ALL SELECT 'stg_arizona_exclusions', COUNT(*) FROM $Schema.stg_arizona_exclusions
UNION ALL SELECT 'stg_arkansas_exclusions', COUNT(*) FROM $Schema.stg_arkansas_exclusions
UNION ALL SELECT 'stg_california_exclusions', COUNT(*) FROM $Schema.stg_california_exclusions
UNION ALL SELECT 'stg_colorado_exclusions', COUNT(*) FROM $Schema.stg_colorado_exclusions
UNION ALL SELECT 'stg_connecticut_exclusions', COUNT(*) FROM $Schema.stg_connecticut_exclusions
UNION ALL SELECT 'stg_delaware_exclusions', COUNT(*) FROM $Schema.stg_delaware_exclusions
UNION ALL SELECT 'stg_district_of_columbia_exclusions', COUNT(*) FROM $Schema.stg_district_of_columbia_exclusions
UNION ALL SELECT 'stg_florida_exclusions', COUNT(*) FROM $Schema.stg_florida_exclusions
ORDER BY table_name;
"@

$TempCountSql = Join-Path $env:TEMP "staging_row_counts.sql"
Set-Content -Path $TempCountSql -Value $CountSql -Encoding UTF8
& $PsqlPath -h $HostName -p $Port -U $Username -d $Database -f $TempCountSql
Remove-Item $TempCountSql -Force
