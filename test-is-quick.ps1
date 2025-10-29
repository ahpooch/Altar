# Quick test for new 'is' tests
. .\Altar.ps1

Write-Host "Quick test of new 'is' operators..." -ForegroundColor Cyan

# Test divisibleby
$template = "{% if 15 is divisibleby(3) %}PASS{% endif %}"
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host "divisibleby: $result"

# Test number
$template = "{% if 42 is number %}PASS{% endif %}"
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host "number: $result"

# Test string
$template = "{% if 'hello' is string %}PASS{% endif %}"
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host "string: $result"

# Test sequence
$template = "{% if [1,2,3] is sequence %}PASS{% endif %}"
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host "sequence: $result"

# Test lower
$template = "{% if 'hello' is lower %}PASS{% endif %}"
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host "lower: $result"

# Test upper
$template = "{% if 'HELLO' is upper %}PASS{% endif %}"
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host "upper: $result"

Write-Host "`nAll quick tests completed!" -ForegroundColor Green
