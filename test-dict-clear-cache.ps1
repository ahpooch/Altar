# Test with cache clearing
. .\Altar.ps1

# Clear template cache
[TemplateEngine]::Cache.Clear()

$template = "{% set mydict = {'key': 'value'} %}{{ mydict }}"
$context = @{}

try {
    $result = Invoke-AltarTemplate -Template $template -Context $context
    Write-Host "Success: $result" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}
