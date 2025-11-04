# Test 1: Assign boolean to environment variable
Write-Host "=== Test 1: Assigning `$true to environment variable ===" -ForegroundColor Cyan
$env:TEST_BOOL = $true
Write-Host "Value: '$env:TEST_BOOL'"
Write-Host "Type: $($env:TEST_BOOL.GetType().Name)"
Write-Host "Is String: $($env:TEST_BOOL -is [string])"
Write-Host ""

# Test 2: Assign string "true" to environment variable
Write-Host "=== Test 2: Assigning string 'true' to environment variable ===" -ForegroundColor Cyan
$env:TEST_STRING = "true"
Write-Host "Value: '$env:TEST_STRING'"
Write-Host "Type: $($env:TEST_STRING.GetType().Name)"
Write-Host "Is String: $($env:TEST_STRING -is [string])"
Write-Host ""

# Test 3: Comparison
Write-Host "=== Test 3: Comparison ===" -ForegroundColor Cyan
Write-Host "`$env:TEST_BOOL -eq `$env:TEST_STRING: $($env:TEST_BOOL -eq $env:TEST_STRING)"
Write-Host "`$env:TEST_BOOL -eq 'True': $($env:TEST_BOOL -eq 'True')"
Write-Host "`$env:TEST_STRING -eq 'true': $($env:TEST_STRING -eq 'true')"
Write-Host ""

# Test 4: What happens in Jinja2/Python?
Write-Host "=== Test 4: Jinja2/Python Environment Variables ===" -ForegroundColor Cyan
Write-Host "In Python, os.environ is a dictionary of strings."
Write-Host "All environment variables are ALWAYS strings, regardless of how they were set."
Write-Host "This is true across all platforms (Windows, Linux, macOS)."
Write-Host ""

# Cleanup
$env:TEST_BOOL = $null
$env:TEST_STRING = $null
