# Diagnostic script for remaining test failures
. ".\Altar.ps1"

Write-Host "=== Issue 1: Preserves leading whitespace when LstripBlocks is disabled ===" -ForegroundColor Cyan
$template1 = @"
text
    {% if true %}
content
    {% endif %}
"@
$result1 = Invoke-AltarTemplate -Template $template1 -Context @{} -LstripBlocks $false
Write-Host "Result length: $($result1.Length)"
Write-Host "Result (escaped): $($result1 -replace "`r", '\r' -replace "`n", '\n')"
Write-Host "Expected: 'text\r\n    \r\ncontent\r\n    \r\n'"
Write-Host ""

Write-Host "=== Issue 2: Works with for loops (LstripBlocks) ===" -ForegroundColor Cyan
$template2 = @"
start
    {% for i in items %}
    {{ i }}
    {% endfor %}
end
"@
$result2 = Invoke-AltarTemplate -Template $template2 -Context @{items = @(1, 2)} -LstripBlocks $true
Write-Host "Result length: $($result2.Length)"
Write-Host "Result (escaped): $($result2 -replace "`r", '\r' -replace "`n", '\n')"
Write-Host "Expected: 'start\r\n\r\n    1\r\n\r\n    2\r\n\r\nend'"
Write-Host ""

Write-Host "=== Issue 3: Removes only spaces and tabs, not newlines ===" -ForegroundColor Cyan
$template3 = @"
line1

  	{% if true %}
content
  	{% endif %}
"@
$result3 = Invoke-AltarTemplate -Template $template3 -Context @{} -LstripBlocks $true
Write-Host "Result length: $($result3.Length)"
Write-Host "Result (escaped): $($result3 -replace "`r", '\r' -replace "`n", '\n' -replace "`t", '\t')"
Write-Host "Expected: 'line1\r\n\r\n\r\ncontent\r\n'"
Write-Host ""

Write-Host "=== Issue 4: Can be disabled per-tag with {%+ ===" -ForegroundColor Cyan
$template4 = @"
text
    {%+ if true %}
content
    {% endif %}
"@
$result4 = Invoke-AltarTemplate -Template $template4 -Context @{} -LstripBlocks $true
Write-Host "Result length: $($result4.Length)"
Write-Host "Result (escaped): $($result4 -replace "`r", '\r' -replace "`n", '\n')"
Write-Host "Expected: 'text\r\n    \r\ncontent'"
Write-Host ""

Write-Host "=== Issue 5: Manual - at tag end works with TrimBlocks ===" -ForegroundColor Cyan
$template5 = @"
{% if true %}
content
{% endif -%}
next
"@
$result5 = Invoke-AltarTemplate -Template $template5 -Context @{} -TrimBlocks $true
Write-Host "Result length: $($result5.Length)"
Write-Host "Result (escaped): $($result5 -replace "`r", '\r' -replace "`n", '\n')"
Write-Host "Expected: '\r\ncontent\r\nnext'"
Write-Host "Actual shows TrimBlocks removes newline after {% if true %} too"
Write-Host ""

Write-Host "=== Issue 6: Manual - at tag start works with LstripBlocks ===" -ForegroundColor Cyan
$template6 = @"
text
    {%- if true %}
content
    {% endif %}
"@
$result6 = Invoke-AltarTemplate -Template $template6 -Context @{} -LstripBlocks $true
Write-Host "Result length: $($result6.Length)"
Write-Host "Result (escaped): $($result6 -replace "`r", '\r' -replace "`n", '\n')"
Write-Host "Expected: 'text\r\ncontent\r\n'"
Write-Host ""

Write-Host "=== Issue 7: Table generation with nested loops ===" -ForegroundColor Cyan
$template7 = @"
<table>
    {% for row in rows %}
    <tr>
        {% for cell in row %}
        <td>{{ cell }}</td>
        {% endfor %}
    </tr>
    {% endfor %}
</table>
"@
$result7 = Invoke-AltarTemplate -Template $template7 -Context @{rows = @(@("A", "B"), @("C", "D"))} -TrimBlocks $true -LstripBlocks $true
Write-Host "Result length: $($result7.Length)"
Write-Host "Result:"
Write-Host $result7
Write-Host ""
Write-Host "Expected: each row should have multiple cells on same <tr>"
