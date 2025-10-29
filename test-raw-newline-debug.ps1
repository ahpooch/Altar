. .\Altar.ps1

# Test 1: Basic raw block - should preserve newlines
$template1 = @"
Line 1
{% raw %}
Raw content
{% endraw %}
Line 2
"@

Write-Host "=== Test 1: Basic raw block ==="
Write-Host "Template:"
Write-Host $template1
Write-Host ""

$result1 = Invoke-AltarTemplate -Template $template1 -Context @{}
Write-Host "Result:"
Write-Host $result1
Write-Host ""
Write-Host "Result bytes:" ([System.Text.Encoding]::UTF8.GetBytes($result1) | ForEach-Object { $_.ToString("X2") }) -join " "
Write-Host ""

$expected1 = "Line 1`r`n`r`nRaw content`r`n`r`nLine 2"
Write-Host "Expected:"
Write-Host $expected1
Write-Host ""
Write-Host "Expected bytes:" ([System.Text.Encoding]::UTF8.GetBytes($expected1) | ForEach-Object { $_.ToString("X2") }) -join " "
Write-Host ""
Write-Host "Match: $($result1 -eq $expected1)"
Write-Host ""

# Test 2: Raw block with trim-right on opening tag
$template2 = @"
Line 1
{% raw -%}
Raw content
{% endraw %}
Line 2
"@

Write-Host "=== Test 2: Raw block with trim-right (-%}) ==="
Write-Host "Template:"
Write-Host $template2
Write-Host ""

$result2 = Invoke-AltarTemplate -Template $template2 -Context @{}
Write-Host "Result:"
Write-Host $result2
Write-Host ""
Write-Host "Result bytes:" ([System.Text.Encoding]::UTF8.GetBytes($result2) | ForEach-Object { $_.ToString("X2") }) -join " "
Write-Host ""

$expected2 = "Line 1`r`nRaw content`r`n`r`nLine 2"
Write-Host "Expected:"
Write-Host $expected2
Write-Host ""
Write-Host "Expected bytes:" ([System.Text.Encoding]::UTF8.GetBytes($expected2) | ForEach-Object { $_.ToString("X2") }) -join " "
Write-Host ""
Write-Host "Match: $($result2 -eq $expected2)"
