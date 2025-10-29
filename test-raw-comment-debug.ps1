. .\Altar.ps1

Write-Host "Testing raw block with comments"

$template = @"
{# Comment before -#}
{% raw %}
{# This comment is preserved #}
{% endraw %}
{# Comment after -#}
"@

$context = @{}

Write-Host "Template:"
Write-Host $template
Write-Host ""

try {
    Write-Host "Invoking template..."
    $result = Invoke-AltarTemplate -Template $template -Context $context -Verbose
    
    Write-Host "`nResult:"
    Write-Host "=" * 60
    Write-Host $result
    Write-Host "=" * 60
    
    $expected = @"

{# This comment is preserved #}

"@
    
    Write-Host "`nExpected:"
    Write-Host "=" * 60
    Write-Host $expected
    Write-Host "=" * 60
    
    Write-Host "`nMatch: $($result -eq $expected)"
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
