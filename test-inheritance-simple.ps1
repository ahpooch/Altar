# Simple test for template inheritance
. .\Altar.ps1

Write-Host "=== Testing Basic Template Inheritance ===" -ForegroundColor Cyan

# Test 1: Base template alone
Write-Host "`n--- Test 1: Base Template (no inheritance) ---" -ForegroundColor Yellow
try {
    $result = Invoke-AltarTemplate -Path "Examples/Inheritance Statements/base.alt" -Context @{}
    Write-Host "Result:"
    Write-Host $result
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
