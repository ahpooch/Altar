. .\Altar.ps1

$template = @"
{% for item in items -%}
{{ loop.index }}. {{ item }} (index0: {{ loop.index0 }}, first: {{ loop.first }}, last: {{ loop.last }}, length: {{ loop.length }})
{% endfor -%}
"@

$context = @{
    items = @('apple', 'banana', 'cherry')
}

Write-Host "Testing loop variable functionality..." -ForegroundColor Cyan
Write-Host ""

$result = Invoke-AltarTemplate -Template $template -Context $context

Write-Host "Result:" -ForegroundColor Green
Write-Host $result
Write-Host ""

Write-Host "Expected output:" -ForegroundColor Yellow
Write-Host "1. apple (index0: 0, first: True, last: False, length: 3)"
Write-Host "2. banana (index0: 1, first: False, last: False, length: 3)"
Write-Host "3. cherry (index0: 2, first: False, last: True, length: 3)"
