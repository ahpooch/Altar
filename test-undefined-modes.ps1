. .\Altar.ps1

Write-Host "=== Test Default Mode ==="
$result1 = Invoke-AltarTemplate -Template '{{ undefined_var }}' -Context @{} -UndefinedBehavior Default
Write-Host "Result: [$result1]"
Write-Host "Length: $($result1.Length)"
Write-Host ""

Write-Host "=== Test Debug Mode ==="
$result2 = Invoke-AltarTemplate -Template '{{ undefined_var }}' -Context @{} -UndefinedBehavior Debug
Write-Host "Result: [$result2]"
Write-Host "Length: $($result2.Length)"
Write-Host ""

Write-Host "=== Test Strict Mode ==="
try {
    $result3 = Invoke-AltarTemplate -Template '{{ undefined_var }}' -Context @{} -UndefinedBehavior Strict -ErrorAction Stop
    Write-Host "Result: [$result3]"
} catch {
    Write-Host "Exception caught: $($_.Exception.Message)"
}
