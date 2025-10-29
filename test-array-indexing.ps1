# Test array indexing functionality
. .\Altar.ps1

Write-Host "Testing array indexing with items filter..." -ForegroundColor Cyan

# Test 1: Basic array indexing
Write-Host "`n=== Test 1: Basic array indexing ===" -ForegroundColor Yellow
$template1 = @"
{{ myarray[0] }}
{{ myarray[1] }}
{{ myarray[2] }}
"@

$context1 = @{
    myarray = @('first', 'second', 'third')
}

$result1 = Invoke-AltarTemplate -Template $template1 -Context $context1
Write-Host "Result:"
Write-Host $result1

# Test 2: Dictionary items filter with indexing
Write-Host "`n=== Test 2: Dictionary items filter with indexing ===" -ForegroundColor Yellow
$template2 = @"
{% for pair in mydict | items %}
Key: {{ pair[0] }}, Value: {{ pair[1] }}
{% endfor %}
"@

$context2 = @{
    mydict = @{
        name = 'John'
        age = 30
        city = 'New York'
    }
}

$result2 = Invoke-AltarTemplate -Template $template2 -Context $context2
Write-Host "Result:"
Write-Host $result2

# Test 3: Nested array indexing
Write-Host "`n=== Test 3: Nested array indexing ===" -ForegroundColor Yellow
$template3 = @"
{{ matrix[0][0] }}
{{ matrix[0][1] }}
{{ matrix[1][0] }}
{{ matrix[1][1] }}
"@

$context3 = @{
    matrix = @(
        @(1, 2),
        @(3, 4)
    )
}

$result3 = Invoke-AltarTemplate -Template $template3 -Context $context3
Write-Host "Result:"
Write-Host $result3

# Test 4: Variable index
Write-Host "`n=== Test 4: Variable index ===" -ForegroundColor Yellow
$template4 = @"
{{ myarray[index] }}
"@

$context4 = @{
    myarray = @('zero', 'one', 'two', 'three')
    index = 2
}

$result4 = Invoke-AltarTemplate -Template $template4 -Context $context4
Write-Host "Result:"
Write-Host $result4

# Test 5: Loop variable with indexing
Write-Host "`n=== Test 5: Loop variable with indexing ===" -ForegroundColor Yellow
$template5 = @"
{% for item in items %}
Item {{ loop.index }}: {{ item[0] }} = {{ item[1] }}
{% endfor %}
"@

$context5 = @{
    items = @(
        @('apple', 5),
        @('banana', 3),
        @('orange', 7)
    )
}

$result5 = Invoke-AltarTemplate -Template $template5 -Context $context5
Write-Host "Result:"
Write-Host $result5

Write-Host "`n=== All tests completed ===" -ForegroundColor Green
