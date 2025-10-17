. .\Altar.ps1

$template = @"
{% for item in items -%}
{{ item }}
{% endfor -%}
"@

$context = @{ items = @('A', 'B') }
$result = Invoke-AltarTemplate -Template $template -Context $context

Write-Host "Result bytes:"
[System.Text.Encoding]::UTF8.GetBytes($result) | ForEach-Object { Write-Host "$_ " -NoNewline }
Write-Host ""
Write-Host "Result: [$result]"
Write-Host "Expected: [A`r`nB]"
