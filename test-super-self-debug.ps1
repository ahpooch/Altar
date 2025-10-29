# Test script to debug super() with self.blockname() issue

. .\Altar.ps1

# Create test directory
$testDir = Join-Path $env:TEMP "SuperSelfTest"
if (Test-Path $testDir) {
    Remove-Item $testDir -Recurse -Force
}
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

# Create base template
$baseTemplate = @'
{% block content %}
Base content
{% endblock %}

{% block title %}Base Title{% endblock %}
'@

# Create child template
$childTemplate = @'
{% extends "base_super.alt" %}

{% block content %}
{{ super() }}
Child content
Title: {{ self.title() }}
{% endblock %}

{% block title %}Child Title{% endblock %}
'@

$basePath = Join-Path $testDir "base_super.alt"
$childPath = Join-Path $testDir "child_super.alt"

Set-Content -Path $basePath -Value $baseTemplate
Set-Content -Path $childPath -Value $childTemplate

Write-Host "=== Testing super() with self.blockname() ===" -ForegroundColor Cyan
Write-Host ""

try {
    $context = @{}
    $result = Invoke-AltarTemplate -Path $childPath -Context $context
    
    Write-Host "Result:" -ForegroundColor Green
    Write-Host $result
    Write-Host ""
    
    # Check expectations
    Write-Host "Checking expectations:" -ForegroundColor Yellow
    
    if ($result -match "Base content") {
        Write-Host "✓ Contains 'Base content' from super()" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing 'Base content' from super()" -ForegroundColor Red
    }
    
    if ($result -match "Child content") {
        Write-Host "✓ Contains 'Child content'" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing 'Child content'" -ForegroundColor Red
    }
    
    if ($result -match "Title: Child Title") {
        Write-Host "✓ Contains 'Title: Child Title' from self.title()" -ForegroundColor Green
    } else {
        Write-Host "✗ Missing 'Title: Child Title' from self.title()" -ForegroundColor Red
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

# Cleanup
Remove-Item $testDir -Recurse -Force
