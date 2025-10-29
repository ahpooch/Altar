# Simple test for dictionary literal
Remove-Module * -ErrorAction SilentlyContinue
. .\Altar.ps1

$template = "{% set mydict = {'key': 'value'} %}{{ mydict }}"
$context = @{}

try {
    $result = Invoke-AltarTemplate -Template $template -Context $context
    Write-Host "Success: $result" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
}
