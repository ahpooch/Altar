. .\Altar.ps1

$template = @"
{% raw %}
Test content
{% endraw %}
"@

$context = @{}

Write-Host "Starting test..."
try {
    $result = Invoke-AltarTemplate -Template $template -Context $context -Verbose
    Write-Host "Result: $result"
} catch {
    Write-Host "Error: $_"
    Write-Host $_.ScriptStackTrace
}
Write-Host "Test completed"
