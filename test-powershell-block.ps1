# Test script for PowerShell block functionality
. .\Altar.ps1

# Test 1: Basic PowerShell execution with output
Write-Host "`n=== Test 1: Basic PowerShell execution ===" -ForegroundColor Cyan
$template1 = @"
Current date: {% powershell %}Get-Date -Format "yyyy-MM-dd"{% endpowershell %}
"@

$result1 = Invoke-AltarTemplate -Template $template1 -Context @{}
Write-Host "Result: $result1"

# Test 2: PowerShell with else block (when result is null/empty)
Write-Host "`n=== Test 2: PowerShell with else block ===" -ForegroundColor Cyan
$template2 = @"
Value: {% powershell %}$null{% else %}Default value{% endpowershell %}
"@

$result2 = Invoke-AltarTemplate -Template $template2 -Context @{}
Write-Host "Result: $result2"

# Test 3: PowerShell with catch block (when error occurs)
Write-Host "`n=== Test 3: PowerShell with catch block ===" -ForegroundColor Cyan
$template3 = @"
Result: {% powershell %}throw "Error occurred"{% catch %}Error was caught!{% endpowershell %}
"@

$result3 = Invoke-AltarTemplate -Template $template3 -Context @{}
Write-Host "Result: $result3"

# Test 4: PowerShell with both else and catch
Write-Host "`n=== Test 4: PowerShell with else and catch ===" -ForegroundColor Cyan
$template4 = @"
Test: {% powershell %}""{% else %}Empty result{% catch %}Error occurred{% endpowershell %}
"@

$result4 = Invoke-AltarTemplate -Template $template4 -Context @{}
Write-Host "Result: $result4"

Write-Host "`n=== All tests completed ===" -ForegroundColor Green
