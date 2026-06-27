<#
Apply nullable-column constraints to existing PostgreSQL staging tables.

How to use from the repository root:
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\apply_null_constraints.ps1

This runs schema\002_apply_null_constraints.sql against exclusion_lists_db.
#>

param(
    [string]$SqlFile = "",
    [string]$PsqlPath = "C:\Users\dsalv\AppData\Local\Programs\pgAdmin 4\runtime\psql.exe",
    [string]$Database = "exclusion_lists_db",
    [string]$Username = "postgres",
    [string]$HostName = "localhost",
    [string]$Port = "5432",
    [string]$Schema = "exclusion_project"
)

$ErrorActionPreference = "Stop"

$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptFolder

if ([string]::IsNullOrWhiteSpace($SqlFile)) {
    $SqlFile = Join-Path $RepoRoot "schema\002_apply_null_constraints.sql"
}
$SqlFile = (Resolve-Path $SqlFile).Path

if (-not (Test-Path $PsqlPath)) {
    Write-Host "psql.exe was not found at: $PsqlPath" -ForegroundColor Red
    Write-Host "Pass -PsqlPath or update the default path in this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "Applying null constraints..." -ForegroundColor Cyan
Write-Host "Database: $Database" -ForegroundColor Cyan
Write-Host "Schema:   $Schema" -ForegroundColor Cyan
Write-Host "SQL file: $SqlFile" -ForegroundColor Cyan
Write-Host ""

& $PsqlPath -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -f $SqlFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: null constraint migration did not complete." -ForegroundColor Red
    exit $LASTEXITCODE
}

$VerifySql = @"
SELECT is_nullable, COUNT(*) AS columns
FROM information_schema.columns
WHERE table_schema = '$Schema'
  AND table_name LIKE 'stg\_%\_exclusions' ESCAPE '\'
GROUP BY is_nullable
ORDER BY is_nullable;
"@

Write-Host ""
Write-Host "Nullability summary:" -ForegroundColor Cyan
& $PsqlPath -h $HostName -p $Port -U $Username -d $Database -v ON_ERROR_STOP=1 -c $VerifySql

if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: nullability verification query failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Done. You can rerun scripts\import_all_staging_csvs.ps1 now." -ForegroundColor Green
