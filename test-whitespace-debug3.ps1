. .\Altar.ps1

Write-Host "=== Test 1: Trims whitespace on the left with {%- ==="
$template1 = @"
Line 1
    {%- for item in items -%}
{{ item }}
{% endfor -%}
Line 2
"@
$context1 = @{ items = @('A', 'B') }
$result1 = Invoke-AltarTemplate -Template $template1 -Context $context1
Write-Host "Result: [$result1]"
Write-Host "Expected: [Line 1`r`nA`r`nB`r`nLine 2]"
Write-Host ""

Write-Host "=== Test 2: Trims whitespace on the right with -%} ==="
$template2 = @"
Start
{% for item in items -%}
{{ item }}
{% endfor -%}
    End
"@
$context2 = @{ items = @('X', 'Y') }
$result2 = Invoke-AltarTemplate -Template $template2 -Context $context2
Write-Host "Result: [$result2]"
Write-Host "Expected: [Start`r`nX`r`nY    End]"
Write-Host ""

Write-Host "=== Test 3: Trims whitespace on both sides ==="
$template3 = @"
Before
    {%- for item in items -%}
{{ item }}
{%- endfor -%}
After
"@
$context3 = @{ items = @('1', '2') }
$result3 = Invoke-AltarTemplate -Template $template3 -Context $context3
Write-Host "Result: [$result3]"
Write-Host "Expected: [Before1`r`n2After]"
