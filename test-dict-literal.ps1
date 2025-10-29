# Test dictionary literal support in Altar
. .\Altar.ps1

Write-Host "=== Test 1: Simple dictionary literal ===" -ForegroundColor Cyan
$template1 = @"
{% set mydict = {'key': 'value'} %}
{{ mydict }}
"@

$context1 = @{}
$result1 = Invoke-AltarTemplate -Template $template1 -Context $context1
Write-Host "Result: $result1"
Write-Host ""

Write-Host "=== Test 2: Dictionary with multiple pairs ===" -ForegroundColor Cyan
$template2 = @"
{% set config = {'host': 'localhost', 'port': 8080, 'debug': true} %}
{{ config }}
"@

$context2 = @{}
$result2 = Invoke-AltarTemplate -Template $template2 -Context $context2
Write-Host "Result: $result2"
Write-Host ""

Write-Host "=== Test 3: Dictionary with property access ===" -ForegroundColor Cyan
$template3 = @"
{% set user = {'name': 'Alice', 'age': 30} %}
Name: {{ user.name }}
Age: {{ user.age }}
"@

$context3 = @{}
$result3 = Invoke-AltarTemplate -Template $template3 -Context $context3
Write-Host "Result:"
Write-Host $result3
Write-Host ""

Write-Host "=== Test 4: Nested dictionaries ===" -ForegroundColor Cyan
$template4 = @"
{% set data = {'user': {'name': 'Bob', 'email': 'bob@example.com'}} %}
{{ data.user.name }} - {{ data.user.email }}
"@

$context4 = @{}
$result4 = Invoke-AltarTemplate -Template $template4 -Context $context4
Write-Host "Result: $result4"
Write-Host ""

Write-Host "=== Test 5: Dictionary with array values ===" -ForegroundColor Cyan
$template5 = @"
{% set data = {'items': [1, 2, 3], 'name': 'Test'} %}
{{ data.name }}: {{ data.items }}
"@

$context5 = @{}
$result5 = Invoke-AltarTemplate -Template $template5 -Context $context5
Write-Host "Result: $result5"
Write-Host ""

Write-Host "=== Test 6: Dictionary in for loop ===" -ForegroundColor Cyan
$template6 = @"
{% set users = [{'name': 'Alice'}, {'name': 'Bob'}, {'name': 'Charlie'}] %}
{% for user in users -%}
User: {{ user.name }}
{% endfor -%}
"@

$context6 = @{}
$result6 = Invoke-AltarTemplate -Template $template6 -Context $context6
Write-Host "Result:"
Write-Host $result6
Write-Host ""

Write-Host "=== Test 7: Empty dictionary ===" -ForegroundColor Cyan
$template7 = @"
{% set empty = {} %}
{{ empty }}
"@

$context7 = @{}
$result7 = Invoke-AltarTemplate -Template $template7 -Context $context7
Write-Host "Result: $result7"
Write-Host ""

Write-Host "=== Test 8: Dictionary with numeric keys ===" -ForegroundColor Cyan
$template8 = @"
{% set nums = {1: 'one', 2: 'two', 3: 'three'} %}
{{ nums }}
"@

$context8 = @{}
$result8 = Invoke-AltarTemplate -Template $template8 -Context $context8
Write-Host "Result: $result8"
Write-Host ""

Write-Host "=== All tests completed ===" -ForegroundColor Green
