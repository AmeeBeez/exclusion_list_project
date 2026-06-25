<#
Launch the local Django exclusion-list report.

The script loads optional environment variables from .env, prompts for the
PostgreSQL password when needed, opens the report URL, and starts Django.
#>

param(
    [string]$Address = "127.0.0.1:8000",
    [string]$EnvFile = ".env",
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

function Set-EnvFromFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return
    }

    Get-Content $Path | ForEach-Object {
        $Line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith("#")) {
            return
        }

        if ($Line -match "^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$") {
            $Name = $Matches[1]
            $Value = $Matches[2].Trim()

            if (
                ($Value.StartsWith('"') -and $Value.EndsWith('"')) -or
                ($Value.StartsWith("'") -and $Value.EndsWith("'"))
            ) {
                $Value = $Value.Substring(1, $Value.Length - 2)
            }

            [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
        }
    }
}

function ConvertTo-PlainText {
    param([securestring]$SecureValue)

    $Bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)
    }
}

Set-EnvFromFile -Path (Join-Path $RepoRoot $EnvFile)

if (-not $env:POSTGRES_DB) { $env:POSTGRES_DB = "exclusion_lists_db" }
if (-not $env:POSTGRES_USER) { $env:POSTGRES_USER = "postgres" }
if (-not $env:POSTGRES_HOST) { $env:POSTGRES_HOST = "localhost" }
if (-not $env:POSTGRES_PORT) { $env:POSTGRES_PORT = "5432" }
if (-not $env:EXCLUSION_SCHEMA) { $env:EXCLUSION_SCHEMA = "exclusion_project" }

if (-not (Test-Path Env:POSTGRES_PASSWORD)) {
    $SecurePassword = Read-Host "PostgreSQL password for $($env:POSTGRES_USER) (press Enter for blank)" -AsSecureString
    $env:POSTGRES_PASSWORD = ConvertTo-PlainText -SecureValue $SecurePassword
}

$VenvPython = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (Test-Path $VenvPython) {
    $Python = $VenvPython
}
else {
    $Python = "python"
}

$Url = "http://$Address/"

Write-Host "Starting exclusion-list report..." -ForegroundColor Cyan
Write-Host "Database: $($env:POSTGRES_DB) on $($env:POSTGRES_HOST):$($env:POSTGRES_PORT)" -ForegroundColor Cyan
Write-Host "Schema:   $($env:EXCLUSION_SCHEMA)" -ForegroundColor Cyan
Write-Host "URL:      $Url" -ForegroundColor Cyan
Write-Host ""

if (-not $NoBrowser) {
    Start-Job -ScriptBlock {
        param([string]$ReportUrl)
        Start-Sleep -Seconds 2
        Start-Process $ReportUrl
    } -ArgumentList $Url | Out-Null
}

& $Python manage.py runserver $Address
