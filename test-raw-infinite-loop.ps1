. .\Altar.ps1

$template = @"
{% raw %}
Special chars: @#$%^&*()[]{}|<>?/\~`!-+=_;:'"
{% endraw %}
"@

$context = @{}

Write-Host "Testing raw block with special characters..."
try {
    $result = Invoke-AltarTemplate -Template $template -Context $context
    Write-Host "Result:"
    Write-Host $result
} catch {
    Write-Host "Error: $_"
}
