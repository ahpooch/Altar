. .\Altar.ps1

Write-Host "=== Test: How Jinja2-like raw blocks should work ==="
Write-Host ""

# Test 1: Basic raw block
$template1 = @"
Line 1
{% raw %}
Raw content
{% endraw %}
Line 2
"@

Write-Host "Template 1 (basic):"
Write-Host $template1
Write-Host ""

$result1 = Invoke-AltarTemplate -Template $template1 -Context @{}
Write-Host "Result 1:"
Write-Host $result1
Write-Host ""
Write-Host "---"
Write-Host ""

# Test 2: Raw block with trim
$template2 = @"
Line 1
{% raw -%}
Raw content
{% endraw %}
Line 2
"@

Write-Host "Template 2 (with -%}):"
Write-Host $template2
Write-Host ""

$result2 = Invoke-AltarTemplate -Template $template2 -Context @{}
Write-Host "Result 2:"
Write-Host $result2
Write-Host ""
Write-Host "---"
Write-Host ""

# Test 3: Inline raw block
$template3 = "Before {% raw %}{{ var }}{% endraw %} After"

Write-Host "Template 3 (inline):"
Write-Host $template3
Write-Host ""

$result3 = Invoke-AltarTemplate -Template $template3 -Context @{}
Write-Host "Result 3:"
Write-Host $result3
Write-Host ""
Write-Host "---"
Write-Host ""

# Test 4: Raw block at start
$template4 = @"
{% raw %}
Raw at start
{% endraw %}
Normal content
"@

Write-Host "Template 4 (at start):"
Write-Host $template4
Write-Host ""

$result4 = Invoke-AltarTemplate -Template $template4 -Context @{}
Write-Host "Result 4:"
Write-Host $result4
