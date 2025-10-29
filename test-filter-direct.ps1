. .\Altar.ps1

# Test direct filter calls
Write-Host "Testing direct filter calls:"

# Test Int with 1 parameter
Write-Host "`nInt filter with 1 param:"
try {
    $result = [AltarFilters]::Int("42")
    Write-Host "Success: $result"
} catch {
    Write-Host "Error: $_"
}

# Test Truncate with 2 parameters
Write-Host "`nTruncate filter with 2 params:"
try {
    $result = [AltarFilters]::Truncate("This is a very long text", 10)
    Write-Host "Success: $result"
} catch {
    Write-Host "Error: $_"
}

# Test Sort with 1 parameter
Write-Host "`nSort filter with 1 param:"
try {
    $result = [AltarFilters]::Sort(@(3, 1, 2))
    Write-Host "Success: $($result -join ',')"
} catch {
    Write-Host "Error: $_"
}

# Test Default with 2 parameters
Write-Host "`nDefault filter with 2 params:"
try {
    $result = [AltarFilters]::Default($null, "N/A")
    Write-Host "Success: $result"
} catch {
    Write-Host "Error: $_"
}
