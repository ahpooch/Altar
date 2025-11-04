. .\Altar.ps1

Write-Host "=== Test 1: TrimBlocks functionality ===" -ForegroundColor Cyan

$template1 = @"
{% if true %}
content
{% endif %}
next line
"@

Write-Host "`nWithout TrimBlocks:" -ForegroundColor Yellow
$result1 = Invoke-AltarTemplate -Template $template1 -Context @{} -TrimBlocks $false
Write-Host "Result length: $($result1.Length)"
Write-Host "Result bytes: $([System.Text.Encoding]::UTF8.GetBytes($result1) | ForEach-Object { $_.ToString('X2') } | Join-String -Separator ' ')"
Write-Host "Result (escaped): $($result1 -replace "`r", '\r' -replace "`n", '\n')"

Write-Host "`nWith TrimBlocks:" -ForegroundColor Yellow
$result2 = Invoke-AltarTemplate -Template $template1 -Context @{} -TrimBlocks $true
Write-Host "Result length: $($result2.Length)"
Write-Host "Result bytes: $([System.Text.Encoding]::UTF8.GetBytes($result2) | ForEach-Object { $_.ToString('X2') } | Join-String -Separator ' ')"
Write-Host "Result (escaped): $($result2 -replace "`r", '\r' -replace "`n", '\n')"

Write-Host "`n`n=== Test 2: LstripBlocks functionality ===" -ForegroundColor Cyan

$template2 = @"
text
    {% if true %}
content
    {% endif %}
"@

Write-Host "`nWithout LstripBlocks:" -ForegroundColor Yellow
$result3 = Invoke-AltarTemplate -Template $template2 -Context @{} -LstripBlocks $false
Write-Host "Result length: $($result3.Length)"
Write-Host "Result bytes: $([System.Text.Encoding]::UTF8.GetBytes($result3) | ForEach-Object { $_.ToString('X2') } | Join-String -Separator ' ')"
Write-Host "Result (escaped): $($result3 -replace "`r", '\r' -replace "`n", '\n')"

Write-Host "`nWith LstripBlocks:" -ForegroundColor Yellow
$result4 = Invoke-AltarTemplate -Template $template2 -Context @{} -LstripBlocks $true
Write-Host "Result length: $($result4.Length)"
Write-Host "Result bytes: $([System.Text.Encoding]::UTF8.GetBytes($result4) | ForEach-Object { $_.ToString('X2') } | Join-String -Separator ' ')"
Write-Host "Result (escaped): $($result4 -replace "`r", '\r' -replace "`n", '\n')"

Write-Host "`n`n=== Test 3: Combined ===" -ForegroundColor Cyan

$template3 = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@

Write-Host "`nWith both TrimBlocks and LstripBlocks:" -ForegroundColor Yellow
$result5 = Invoke-AltarTemplate -Template $template3 -Context @{ items = @("one", "two") } -TrimBlocks $true -LstripBlocks $true
Write-Host "Result length: $($result5.Length)"
Write-Host "Result (escaped): $($result5 -replace "`r", '\r' -replace "`n", '\n')"
Write-Host "`nActual output:"
Write-Host $result5

Write-Host "`n`n=== Test 4: Plus modifier ===" -ForegroundColor Cyan

$template4 = @"
{% if true +%}
content
{% endif %}
next
"@

Write-Host "`nWith +%} (should preserve newline after tag):" -ForegroundColor Yellow
$result6 = Invoke-AltarTemplate -Template $template4 -Context @{} -TrimBlocks $true
Write-Host "Result length: $($result6.Length)"
Write-Host "Result (escaped): $($result6 -replace "`r", '\r' -replace "`n", '\n')"

Write-Host "`n`n=== Test 5: Default behavior ===" -ForegroundColor Cyan

$template5 = @"
    {% if true %}
content
    {% endif %}
"@

Write-Host "`nNo parameters specified:" -ForegroundColor Yellow
$result7 = Invoke-AltarTemplate -Template $template5 -Context @{}
Write-Host "Result length: $($result7.Length)"
Write-Host "Result (escaped): $($result7 -replace "`r", '\r' -replace "`n", '\n')"
Write-Host "`nActual output:"
Write-Host "'$result7'"
