<#
Import all staging CSV files into PostgreSQL using psql from PowerShell.

How to use:
1. Put processed CSV files in data/processed, or pass -CsvFolder with another folder.
2. Update $PsqlPath, $Database, $Username, $Host, $Port if needed.
3. Run PowerShell as normal user.
4. Execute from the repository root:
   powershell -ExecutionPolicy Bypass -File .\scripts\import_all_staging_csvs.ps1

Assumptions:
- Database: exclusion_lists_db
- Schema: exclusion_project
- Tables already exist with schema.
- CSV files have headers matching the table columns.
- If the CSV contains an id column, the script imports it and then resets the sequence.
#>

param(
    [string]$CsvFolder = ""
)

$ErrorActionPreference = "Stop"

# ---------- EDIT THESE SETTINGS ----------
$PsqlPath = $env:PSQL_PATH
if ([string]::IsNullOrWhiteSpace($PsqlPath)) {
    $PsqlCommand = Get-Command psql.exe -ErrorAction SilentlyContinue
    if ($PsqlCommand) {
        $PsqlPath = $PsqlCommand.Source
    }
}
if ([string]::IsNullOrWhiteSpace($PsqlPath)) {
    $CandidatePaths = @(
        (Join-Path $env:LOCALAPPDATA "Programs\pgAdmin 4\runtime\psql.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\pgAdmin 4\bin\psql.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\PostgreSQL\bin\psql.exe"),
        (Join-Path $env:ProgramFiles "PostgreSQL\bin\psql.exe"),
        (Join-Path $env:ProgramFiles "pgAdmin 4\bin\psql.exe"),
        (Join-Path $env:ProgramFiles "pgAdmin 4\runtime\psql.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "PostgreSQL\bin\psql.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "pgAdmin 4\bin\psql.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "pgAdmin 4\runtime\psql.exe")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $CandidatePaths) {
        if (Test-Path $candidate) {
            $PsqlPath = $candidate
            break
        }
    }
}
$Database = "exclusion_lists_db"
$Username = "postgres"
$HostName = "localhost"
$Port = "5432"
$Schema = "exclusion_project"

$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($CsvFolder)) {
    $RepoRoot = Split-Path -Parent $ScriptFolder
    $CsvFolder = Join-Path $RepoRoot "data\processed"
    if (-not (Test-Path $CsvFolder)) {
        $CsvFolder = $ScriptFolder
    }
}
$CsvFolder = (Resolve-Path $CsvFolder).Path
# ----------------------------------------

if (-not (Test-Path $PsqlPath)) {
    Write-Host "psql.exe was not found at: $PsqlPath" -ForegroundColor Red
    Write-Host "Update `$PsqlPath in this script to your PostgreSQL bin folder." -ForegroundColor Yellow
    exit 1
}

$Imports = @(
    @{ Table = "stg_alabama_exclusions"; Files = @("stg_alabama_exclusions.csv", "stg_alabama_exclusions_processed_schema.csv", "stg_alabama_exclusions_from_pdf_schema.csv", "stg_alabama_exclusions_processed.csv") },
    @{ Table = "stg_alaska_exclusions"; Files = @("stg_alaska_exclusions.csv", "stg_alaska_exclusions_processed_schema.csv", "stg_alaska_exclusions_from_pdf_schema.csv", "stg_alaska_exclusions_processed.csv") },
    @{ Table = "stg_arizona_exclusions"; Files = @("stg_arizona_exclusions.csv", "stg_arizona_exclusions_processed_schema.csv", "stg_arizona_exclusions_from_pdf_schema.csv", "stg_arizona_exclusions_processed.csv") },
    @{ Table = "stg_arkansas_exclusions"; Files = @("stg_arkansas_exclusions.csv", "stg_arkansas_exclusions_processed_schema.csv", "stg_arkansas_exclusions_from_pdf_schema.csv", "stg_arkansas_exclusions_processed.csv") },
    @{ Table = "stg_california_exclusions"; Files = @("stg_california_exclusions.csv", "stg_california_exclusions_processed_schema.csv", "stg_california_exclusions_manual_escape_fixed_schema.csv", "stg_california_exclusions_processed.csv", "stg_california_exclusions_manual_escape_fixed.csv") },
    @{ Table = "stg_colorado_exclusions"; Files = @("stg_colorado_exclusions.csv", "stg_colorado_exclusions_processed_schema.csv", "stg_colorado_exclusions_from_pdf_schema.csv", "stg_colorado_exclusions_processed.csv") },
    @{ Table = "stg_connecticut_exclusions"; Files = @("stg_connecticut_exclusions.csv", "stg_connecticut_exclusions_processed_schema.csv", "stg_connecticut_exclusions_from_pdf_schema.csv", "stg_connecticut_exclusions_processed.csv") },
    @{ Table = "stg_delaware_exclusions"; Files = @("stg_delaware_exclusions.csv", "stg_delaware_exclusions_processed_schema.csv", "stg_delaware_exclusions_from_pdf_schema.csv", "stg_delaware_exclusions_processed.csv") },
    @{ Table = "stg_district_of_columbia_exclusions"; Files = @("stg_district_of_columbia_exclusions.csv", "stg_district_of_columbia_exclusions_processed_schema.csv", "stg_district_of_columbia_exclusions_from_pdf_schema.csv", "stg_district_of_columbia_exclusions_processed.csv") },
    @{ Table = "stg_florida_exclusions"; Files = @("stg_florida_exclusions.csv", "stg_florida_exclusions_processed_schema.csv", "stg_florida_exclusions_from_pdf_schema.csv", "stg_florida_exclusions_processed.csv") }
)

$OptionalColumns = @(
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
    "notes"
)

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Value, $Utf8NoBom)
}

if ([string]::IsNullOrEmpty($env:PGPASSWORD)) {
    $SecurePassword = Read-Host "PostgreSQL password for $Username" -AsSecureString
    $PasswordPointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    try {
        $env:PGPASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($PasswordPointer)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordPointer)
    }
}

Write-Host "Starting CSV import..." -ForegroundColor Cyan
Write-Host "Database: $Database" -ForegroundColor Cyan
Write-Host "Schema:   $Schema" -ForegroundColor Cyan
Write-Host "Folder:   $CsvFolder" -ForegroundColor Cyan
Write-Host ""

$TableNamesSql = ($Imports | ForEach-Object { "'$($_.Table)'" }) -join ", "
$OptionalColumnsSql = ($OptionalColumns | ForEach-Object { "'$_'" }) -join ", "
$SchemaCheckSql = @"
SELECT COUNT(*)
FROM information_schema.columns
WHERE table_schema = '$Schema'
  AND table_name IN ($TableNamesSql)
  AND column_name IN ($OptionalColumnsSql)
  AND is_nullable = 'NO';
"@

$SchemaCheck = & $PsqlPath -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -t -A -c $SchemaCheckSql
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: could not check staging table nullability." -ForegroundColor Red
    exit $LASTEXITCODE
}

$NotNullableOptionalColumns = (($SchemaCheck | Where-Object { $_.Trim() -match "^\d+$" } | Select-Object -Last 1).Trim())
if ([int]$NotNullableOptionalColumns -gt 0) {
    Write-Host "FAILED: staging tables still have old NOT NULL constraints on nullable source columns." -ForegroundColor Red
    Write-Host "Run schema\002_apply_null_constraints.sql in pgAdmin first, then rerun this import." -ForegroundColor Yellow
    Write-Host "Without that migration, blank CSV cells import as NULL and COPY fails after TRUNCATE." -ForegroundColor Yellow
    exit 1
}

$ImportedTables = 0

foreach ($item in $Imports) {
    $TableName = $item.Table
    $FullTable = "$Schema.$TableName"
    $CsvPath = $null
    $CsvFile = $null

    foreach ($candidate in $item.Files) {
        $CandidatePath = Join-Path $CsvFolder $candidate
        if (Test-Path $CandidatePath) {
            $CsvPath = $CandidatePath
            $CsvFile = $candidate
            break
        }
    }

    if (-not $CsvPath) {
        Write-Host "SKIPPED: no CSV found for $TableName. Checked: $($item.Files -join ', ')." -ForegroundColor Yellow
        continue
    }

    # Convert backslashes to forward slashes for psql \copy compatibility.
    $PsqlCsvPath = $CsvPath.Replace("\", "/")

    Write-Host "Importing $CsvFile -> $FullTable" -ForegroundColor Green
    $ExpectedRows = (Import-Csv -LiteralPath $CsvPath).Count
    if ($ExpectedRows -le 0) {
        Write-Host "FAILED: $CsvFile has no data rows." -ForegroundColor Red
        exit 1
    }
    Write-Host "Expected rows: $ExpectedRows" -ForegroundColor Cyan

    $Sql = @"
BEGIN;
TRUNCATE TABLE $FullTable RESTART IDENTITY;
\copy $FullTable FROM '$PsqlCsvPath' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', NULL '', ENCODING 'UTF8');
SELECT '$TableName' AS table_name, COUNT(*) AS imported_rows FROM $FullTable;
WITH actual AS (
    SELECT COUNT(*)::integer AS rows FROM $FullTable
)
SELECT rows AS verified_rows
FROM actual;
DO `$verify`$
DECLARE
    actual_rows integer;
BEGIN
    SELECT COUNT(*)::integer INTO actual_rows FROM $FullTable;
    IF actual_rows <> $ExpectedRows THEN
        RAISE EXCEPTION 'Row count mismatch for ${TableName}: expected %, got %', $ExpectedRows, actual_rows;
    END IF;
END
`$verify`$;
SELECT setval(pg_get_serial_sequence('$FullTable', 'id'), COALESCE((SELECT MAX(id) FROM $FullTable), 1), true);
COMMIT;
"@

    $TempSql = Join-Path $env:TEMP "import_$TableName.sql"
    Write-Utf8NoBom -Path $TempSql -Value $Sql

    & $PsqlPath -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -f $TempSql

    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $CsvFile" -ForegroundColor Red
        Write-Host "The table import was wrapped in a transaction, so a failed COPY should not leave a partially imported table." -ForegroundColor Yellow
        exit $LASTEXITCODE
    }

    Remove-Item $TempSql -Force
    $ImportedTables += 1
    Write-Host "Done: $TableName" -ForegroundColor Green
    Write-Host ""
}

if ($ImportedTables -eq 0) {
    Write-Host "FAILED: no matching staging CSV files were imported from $CsvFolder." -ForegroundColor Red
    exit 1
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
Write-Utf8NoBom -Path $TempCountSql -Value $CountSql
& $PsqlPath -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -f $TempCountSql
Remove-Item $TempCountSql -Force
