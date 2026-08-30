#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets up the Python virtual environment for the Jinja2 Oracle Service.

.DESCRIPTION
    Creates a Python virtual environment in oracle/.venv, installs all
    dependencies from requirements.txt, and optionally starts the service.

    Works on Windows, Linux and macOS (requires PowerShell 7+ / pwsh).

.PARAMETER Start
    Start the oracle service immediately after setup.

.PARAMETER Port
    Port number for the oracle service. Default: 5000.

.PARAMETER Force
    Recreate the virtual environment even if it already exists.

.EXAMPLE
    pwsh oracle/setup.ps1
    pwsh oracle/setup.ps1 -Start
    pwsh oracle/setup.ps1 -Start -Port 8080
    pwsh oracle/setup.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch] $Start,
    [int]    $Port  = 5000,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve paths — script works regardless of the caller's working directory
# ---------------------------------------------------------------------------
$OracleDir = $PSScriptRoot
$VenvDir   = Join-Path $OracleDir '.venv'
$AppPath   = Join-Path $OracleDir 'app.py'
$ReqPath   = Join-Path $OracleDir 'requirements.txt'

# Python executable varies by OS
$PythonCmd = if ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.Platform -eq 'Win32NT') {
    'python'
} else {
    'python3'
}

# venv activation script path varies by OS
# Note: Join-Path with 3 arguments is PS 6+ only — use nested calls for PS 5.1 compat.
$ActivateScript = if ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.Platform -eq 'Win32NT') {
    Join-Path (Join-Path $VenvDir 'Scripts') 'Activate.ps1'
} else {
    Join-Path (Join-Path $VenvDir 'bin') 'Activate.ps1'
}

# Python binary inside venv varies by OS
$VenvPython = if ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.Platform -eq 'Win32NT') {
    Join-Path (Join-Path $VenvDir 'Scripts') 'python.exe'
} else {
    Join-Path (Join-Path $VenvDir 'bin') 'python'
}

# ---------------------------------------------------------------------------
# Verify Python is available
# ---------------------------------------------------------------------------
Write-Host "Checking Python availability..." -ForegroundColor Cyan
try {
    $pythonVersion = & $PythonCmd --version 2>&1
    Write-Host "  Found: $pythonVersion" -ForegroundColor Green
}
catch {
    Write-Error "Python not found. Install Python 3.11+ and ensure it is on PATH."
}

# ---------------------------------------------------------------------------
# Create virtual environment
# ---------------------------------------------------------------------------
if (Test-Path $VenvDir) {
    if ($Force) {
        Write-Host "Removing existing virtual environment..." -ForegroundColor Yellow
        Remove-Item $VenvDir -Recurse -Force
    } else {
        Write-Host "Virtual environment already exists at: $VenvDir" -ForegroundColor Green
    }
}

if (-not (Test-Path $VenvDir)) {
    Write-Host "Creating virtual environment at: $VenvDir" -ForegroundColor Cyan
    & $PythonCmd -m venv $VenvDir
    Write-Host "  Virtual environment created." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------
Write-Host "Installing dependencies from requirements.txt..." -ForegroundColor Cyan
& $VenvPython -m pip install --quiet --upgrade pip
& $VenvPython -m pip install --quiet -r $ReqPath

$jinja2Version = & $VenvPython -c "import importlib.metadata; print(importlib.metadata.version('jinja2'))"
$flaskVersion  = & $VenvPython -c "import importlib.metadata; print(importlib.metadata.version('flask'))"
Write-Host "  flask   $flaskVersion" -ForegroundColor Green
Write-Host "  jinja2  $jinja2Version" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Optionally start the service
# ---------------------------------------------------------------------------
if ($Start) {
    Write-Host ""
    Write-Host "Starting Jinja2 Oracle Service on port $Port..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray
    Write-Host ""
    & $VenvPython $AppPath $Port
}
else {
    Write-Host ""
    Write-Host "Setup complete. To start the oracle service run:" -ForegroundColor Green
    Write-Host "  pwsh oracle/setup.ps1 -Start" -ForegroundColor White
    Write-Host "  pwsh oracle/setup.ps1 -Start -Port 8080" -ForegroundColor White
    Write-Host ""
    Write-Host "Or activate the venv manually and run app.py:" -ForegroundColor DarkGray
    Write-Host "  . $ActivateScript" -ForegroundColor DarkGray
    Write-Host "  python oracle/app.py" -ForegroundColor DarkGray
}
