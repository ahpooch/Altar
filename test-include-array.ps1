# Test script for array-based include with fallback functionality

# Load the Altar Template Engine
. .\Altar.ps1

Write-Host "=== Test 1: Array include with fallback (first file exists) ===" -ForegroundColor Cyan
$template1 = @"
Start of template
{% include ['include_files/first_include.alt', 'include_files/second_include.alt'] %}
End of template
"@

$context1 = @{
    username = "TestUser"
    var = "test value"
    content = "Test Content"
}

$engine1 = [TemplateEngine]::new()
$engine1.TemplateDir = "Examples/Include Statement"
$result1 = $engine1.Render($template1, $context1)
Write-Host "Result:" -ForegroundColor Green
Write-Host $result1
Write-Host ""

Write-Host "=== Test 2: Array include with fallback (first file missing, second exists) ===" -ForegroundColor Cyan
$template2 = @"
Start of template
{% include ['nonexistent.alt', 'include_files/second_include.alt'] %}
End of template
"@

$context2 = @{
    username = "TestUser"
    content = "Test Content"
}

$engine2 = [TemplateEngine]::new()
$engine2.TemplateDir = "Examples/Include Statement"
$result2 = $engine2.Render($template2, $context2)
Write-Host "Result:" -ForegroundColor Green
Write-Host $result2
Write-Host ""

Write-Host "=== Test 3: Array include with 'ignore missing' (all files missing) ===" -ForegroundColor Cyan
$template3 = @"
Start of template
{% include ['nonexistent1.alt', 'nonexistent2.alt'] ignore missing %}
End of template
"@

$context3 = @{
    username = "TestUser"
    content = "Test Content"
}

$engine3 = [TemplateEngine]::new()
$engine3.TemplateDir = "Examples/Include Statement"
$result3 = $engine3.Render($template3, $context3)
Write-Host "Result:" -ForegroundColor Green
Write-Host $result3
Write-Host ""

Write-Host "=== Test 4: Array include without 'ignore missing' (should throw error) ===" -ForegroundColor Cyan
try {
    $template4 = @"
Start of template
{% include ['nonexistent1.alt', 'nonexistent2.alt'] %}
End of template
"@

    $context4 = @{
        username = "TestUser"
        content = "Test Content"
    }

    $engine4 = [TemplateEngine]::new()
    $engine4.TemplateDir = "Examples/Include Statement"
    $result4 = $engine4.Render($template4, $context4)
    Write-Host "Result:" -ForegroundColor Green
    Write-Host $result4
} catch {
    Write-Host "Expected error caught:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}
Write-Host ""

Write-Host "=== All tests completed ===" -ForegroundColor Cyan
