# Test script to verify that foo.bar and foo['bar'] work identically (Jinja2 compatibility)

. .\Altar.ps1

Write-Host "Testing bracket notation vs dot notation (Jinja2 compatibility)" -ForegroundColor Cyan
Write-Host "=" * 70

# Test 1: Simple property access with PSCustomObject
Write-Host "`nTest 1: PSCustomObject property access" -ForegroundColor Yellow
$template1 = @"
Dot notation: {{ user.name }}
Bracket notation: {{ user['name'] }}
"@

$context1 = @{
    user = [PSCustomObject]@{
        name = "John Doe"
        age = 30
    }
}

$result1 = Invoke-AltarTemplate -Template $template1 -Context $context1
Write-Host $result1

# Test 2: Hashtable property access
Write-Host "`nTest 2: Hashtable property access" -ForegroundColor Yellow
$template2 = @"
Dot notation: {{ config.setting }}
Bracket notation: {{ config['setting'] }}
"@

$context2 = @{
    config = @{
        setting = "enabled"
        value = 42
    }
}

$result2 = Invoke-AltarTemplate -Template $template2 -Context $context2
Write-Host $result2

# Test 3: Nested property access
Write-Host "`nTest 3: Nested property access" -ForegroundColor Yellow
$template3 = @"
Dot notation: {{ data.user.name }}
Bracket notation: {{ data['user']['name'] }}
Mixed notation 1: {{ data.user['name'] }}
Mixed notation 2: {{ data['user'].name }}
"@

$context3 = @{
    data = @{
        user = @{
            name = "Jane Smith"
            email = "jane@example.com"
        }
    }
}

$result3 = Invoke-AltarTemplate -Template $template3 -Context $context3
Write-Host $result3

# Test 4: Property access with filters
Write-Host "`nTest 4: Property access with filters" -ForegroundColor Yellow
$template4 = @"
Dot notation with filter: {{ user.name | upper }}
Bracket notation with filter: {{ user['name'] | upper }}
"@

$context4 = @{
    user = @{
        name = "alice"
    }
}

$result4 = Invoke-AltarTemplate -Template $template4 -Context $context4
Write-Host $result4

# Test 5: Numeric indexing still works
Write-Host "`nTest 5: Numeric array indexing (should still work)" -ForegroundColor Yellow
$template5 = @"
First item: {{ items[0] }}
Second item: {{ items[1] }}
"@

$context5 = @{
    items = @("apple", "banana", "cherry")
}

$result5 = Invoke-AltarTemplate -Template $template5 -Context $context5
Write-Host $result5

# Test 6: Expression-based indexing
Write-Host "`nTest 6: Expression-based indexing" -ForegroundColor Yellow
$template6 = @"
{% set key = 'name' %}
Using variable as key: {{ user[key] }}
"@

$context6 = @{
    user = @{
        name = "Bob"
        age = 25
    }
}

$result6 = Invoke-AltarTemplate -Template $template6 -Context $context6
Write-Host $result6

# Test 7: Undefined behavior with bracket notation
Write-Host "`nTest 7: Undefined property with bracket notation (Default mode)" -ForegroundColor Yellow
$template7 = @"
Dot notation undefined: {{ user.missing }}
Bracket notation undefined: {{ user['missing'] }}
"@

$context7 = @{
    user = @{
        name = "Charlie"
    }
}

$result7 = Invoke-AltarTemplate -Template $template7 -Context $context7
Write-Host "Result: '$result7' (should be empty)"

Write-Host "`n" + ("=" * 70)
Write-Host "All tests completed!" -ForegroundColor Green
