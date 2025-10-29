# Test script for new 'is' tests
. .\Altar.ps1

Write-Host "Testing new 'is' tests..." -ForegroundColor Cyan
Write-Host ""

# Test divisibleby
Write-Host "Test: divisibleby" -ForegroundColor Yellow
$template = @"
{% set num = 15 %}
{% if num is divisibleby(3) %}PASS: 15 is divisible by 3{% endif %}
{% if num is divisibleby(5) %}PASS: 15 is divisible by 5{% endif %}
{% if num is not divisibleby(7) %}PASS: 15 is NOT divisible by 7{% endif %}
"@
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host $result
Write-Host ""

# Test iterable
Write-Host "Test: iterable" -ForegroundColor Yellow
$template = @"
{% set items = [1, 2, 3] %}
{% set text = "hello" %}
{% set number = 42 %}
{% if items is iterable %}PASS: array is iterable{% endif %}
{% if text is not iterable %}PASS: string is NOT iterable{% endif %}
{% if number is not iterable %}PASS: number is NOT iterable{% endif %}
"@
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host $result
Write-Host ""

# Test number
Write-Host "Test: number" -ForegroundColor Yellow
$template = @"
{% set value1 = 42 %}
{% set value2 = "hello" %}
{% if value1 is number %}PASS: 42 is a number{% endif %}
{% if value2 is not number %}PASS: 'hello' is NOT a number{% endif %}
"@
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host $result
Write-Host ""

# Test string
Write-Host "Test: string" -ForegroundColor Yellow
$template = @"
{% set value1 = "hello" %}
{% set value2 = 42 %}
{% if value1 is string %}PASS: 'hello' is a string{% endif %}
{% if value2 is not string %}PASS: 42 is NOT a string{% endif %}
"@
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host $result
Write-Host ""

# Test mapping
Write-Host "Test: mapping" -ForegroundColor Yellow
$template = @"
{% set dict = {'key': 'value'} %}
{% set arr = [1, 2, 3] %}
{% if dict is mapping %}PASS: dict is a mapping{% endif %}
{% if arr is not mapping %}PASS: array is NOT a mapping{% endif %}
"@
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host $result
Write-Host ""

# Test sequence
Write-Host "Test: sequence" -ForegroundColor Yellow
$template = @"
{% set arr = [1, 2, 3] %}
{% set text = "hello" %}
{% set num = 42 %}
{% if arr is sequence %}PASS: array is a sequence{% endif %}
{% if text is sequence %}PASS: string is a sequence{% endif %}
{% if num is not sequence %}PASS: number is NOT a sequence{% endif %}
"@
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host $result
Write-Host ""

# Test lower
Write-Host "Test: lower" -ForegroundColor Yellow
$template = @"
{% set text1 = "hello" %}
{% set text2 = "HELLO" %}
{% set text3 = "Hello" %}
{% if text1 is lower %}PASS: 'hello' is lowercase{% endif %}
{% if text2 is not lower %}PASS: 'HELLO' is NOT lowercase{% endif %}
{% if text3 is not lower %}PASS: 'Hello' is NOT lowercase{% endif %}
"@
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host $result
Write-Host ""

# Test upper
Write-Host "Test: upper" -ForegroundColor Yellow
$template = @"
{% set text1 = "HELLO" %}
{% set text2 = "hello" %}
{% set text3 = "Hello" %}
{% if text1 is upper %}PASS: 'HELLO' is uppercase{% endif %}
{% if text2 is not upper %}PASS: 'hello' is NOT uppercase{% endif %}
{% if text3 is not upper %}PASS: 'Hello' is NOT uppercase{% endif %}
"@
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host $result
Write-Host ""

# Test sameas
Write-Host "Test: sameas" -ForegroundColor Yellow
$template = @"
{% set obj1 = [1, 2, 3] %}
{% set obj2 = obj1 %}
{% set obj3 = [1, 2, 3] %}
{% if obj1 is sameas(obj2) %}PASS: obj1 and obj2 are the same object{% endif %}
{% if obj1 is not sameas(obj3) %}PASS: obj1 and obj3 are NOT the same object{% endif %}
"@
$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host $result
Write-Host ""

Write-Host "All tests completed!" -ForegroundColor Green
