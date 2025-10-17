. .\Altar.ps1

$template = @"
Line 1
    {%- for item in items %}
{{ item }}
{% endfor -%}
Line 2
"@

$context = @{ items = @('A', 'B') }
$result = Invoke-AltarTemplate -Template $template -Context $context

Write-Host "Result bytes:"
[System.Text.Encoding]::UTF8.GetBytes($result) | ForEach-Object { Write-Host "$_ " -NoNewline }
Write-Host ""
Write-Host "Result: [$result]"
Write-Host "Expected: [Line 1`r`nA`r`nB`r`nLine 2]"

# Show character by character
Write-Host "`nCharacter by character:"
for ($i = 0; $i -lt $result.Length; $i++) {
    $char = $result[$i]
    $byte = [byte][char]$char
    if ($char -eq "`r") {
        Write-Host "[$i] = \r (byte $byte)"
    } elseif ($char -eq "`n") {
        Write-Host "[$i] = \n (byte $byte)"
    } else {
        Write-Host "[$i] = $char (byte $byte)"
    }
}
