. .\Altar.ps1

# Установим переменные окружения
$env:Altar_TrimBlocks = "true"
$env:Altar_LstripBlocks = "false"

# Проверим что lexer получил значения
Write-Host "Before Invoke-AltarTemplate:"
Write-Host "Lexer TRIM_BLOCKS: $([Lexer]::TRIM_BLOCKS)"
Write-Host "Lexer LSTRIP_BLOCKS: $([Lexer]::LSTRIP_BLOCKS)"

# Создадим простой шаблон
$template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@

$context = @{
    items = @('one', 'two')
}

# Вызовем Invoke-AltarTemplate БЕЗ явных параметров
$result = Invoke-AltarTemplate -Template $template -Context $context

Write-Host "`nAfter Invoke-AltarTemplate:"
Write-Host "Lexer TRIM_BLOCKS: $([Lexer]::TRIM_BLOCKS)"
Write-Host "Lexer LSTRIP_BLOCKS: $([Lexer]::LSTRIP_BLOCKS)"

Write-Host "`nResult:"
Write-Host $result

Write-Host "`nResult (escaped for debugging):"
Write-Host ($result -replace "`r", '\r' -replace "`n", '\n')

# Очистим переменные окружения
$env:Altar_TrimBlocks = $null
$env:Altar_LstripBlocks = $null
