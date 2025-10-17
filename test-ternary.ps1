# Test script for ternary operator functionality
. .\Altar.ps1

Write-Host "=== Testing Ternary Operator ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Simple ternary operator
Write-Host "Test 1: Simple ternary operator" -ForegroundColor Yellow
$template1 = @"
Result: {{ 'yes' if true else 'no' }}
Another: {{ 'no' if false else 'yes' }}
"@

$context1 = @{}
$result1 = Invoke-AltarTemplate -Template $template1 -Context $context1
Write-Host $result1
Write-Host ""

# Test 2: Ternary with variables
Write-Host "Test 2: Ternary with variables" -ForegroundColor Yellow
$template2 = @"
Status: {{ 'Active' if is_active else 'Inactive' }}
Age group: {{ 'Adult' if age >= 18 else 'Minor' }}
"@

$context2 = @{
    is_active = $true
    age = 25
}
$result2 = Invoke-AltarTemplate -Template $template2 -Context $context2
Write-Host $result2
Write-Host ""

# Test 3: Nested ternary operators
Write-Host "Test 3: Nested ternary operators" -ForegroundColor Yellow
$template3 = @"
Grade: {{ 'A' if score >= 90 else 'B' if score >= 80 else 'C' if score >= 70 else 'F' }}
"@

$context3 = @{
    score = 85
}
$result3 = Invoke-AltarTemplate -Template $template3 -Context $context3
Write-Host $result3
Write-Host ""

# Test 4: Ternary with filters
Write-Host "Test 4: Ternary with filters" -ForegroundColor Yellow
$template4 = @"
Name: {{ name | upper if show_uppercase else name | lower }}
"@

$context4 = @{
    name = "John Doe"
    show_uppercase = $true
}
$result4 = Invoke-AltarTemplate -Template $template4 -Context $context4
Write-Host $result4
Write-Host ""

# Test 5: Ternary with complex conditions
Write-Host "Test 5: Ternary with complex conditions" -ForegroundColor Yellow
$template5 = @"
Access: {{ 'Granted' if user.role == 'admin' and user.active else 'Denied' }}
"@

$context5 = @{
    user = @{
        role = "admin"
        active = $true
    }
}
$result5 = Invoke-AltarTemplate -Template $template5 -Context $context5
Write-Host $result5
Write-Host ""

# Test 6: Ternary with property access
Write-Host "Test 6: Ternary with property access" -ForegroundColor Yellow
$template6 = @"
Value: {{ obj.success_value if obj.is_success else obj.error_value }}
"@

$context6 = @{
    obj = @{
        is_success = $true
        success_value = "Operation completed successfully"
        error_value = "Operation failed"
    }
}
$result6 = Invoke-AltarTemplate -Template $template6 -Context $context6
Write-Host $result6
Write-Host ""

Write-Host "=== All Tests Completed ===" -ForegroundColor Green
