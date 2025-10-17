# Test script for template inheritance functionality
. .\Altar.ps1

Write-Host "=== Testing Template Inheritance ===" -ForegroundColor Cyan

# Test 1: Basic child template (child.alt)
Write-Host "`n--- Test 1: Child Template (overrides both blocks) ---" -ForegroundColor Yellow
$result = Invoke-AltarTemplate -Path "Examples/Inheritance Statements/child.alt" -Context @{}
Write-Host "Result:"
Write-Host $result

# Test 2: Super template (super.alt)
Write-Host "`n--- Test 2: Super Template (uses super() to extend content) ---" -ForegroundColor Yellow
$result = Invoke-AltarTemplate -Path "Examples/Inheritance Statements/super.alt" -Context @{}
Write-Host "Result:"
Write-Host $result

# Test 3: Base template alone (base.alt)
Write-Host "`n--- Test 3: Base Template (no inheritance) ---" -ForegroundColor Yellow
$result = Invoke-AltarTemplate -Path "Examples/Inheritance Statements/base.alt" -Context @{}
Write-Host "Result:"
Write-Host $result

Write-Host "`n=== Tests Complete ===" -ForegroundColor Green
