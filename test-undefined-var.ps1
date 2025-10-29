. .\Altar.ps1

# Test 1: Undefined variable
$result1 = Invoke-AltarTemplate -Template '{{ undefined_var }}' -Context @{}
Write-Host "Test 1 - Undefined variable:"
Write-Host "  Result: [$result1]"
Write-Host "  IsNull: $($result1 -eq $null)"
Write-Host "  IsEmpty: $($result1 -eq '')"
Write-Host "  Length: $($result1.Length)"
Write-Host ""

# Test 2: Undefined nested property
$result2 = Invoke-AltarTemplate -Template '{{ user.name }}' -Context @{ user = @{} }
Write-Host "Test 2 - Undefined nested property:"
Write-Host "  Result: [$result2]"
Write-Host "  IsNull: $($result2 -eq $null)"
Write-Host "  IsEmpty: $($result2 -eq '')"
Write-Host "  Length: $($result2.Length)"
