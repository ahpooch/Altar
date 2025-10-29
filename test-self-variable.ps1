# Quick test script for Self Variable feature
# Tests basic self.blockname() functionality

. .\Altar.ps1

Write-Host "Testing Self Variable Feature..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Basic self call
Write-Host "Test 1: Basic self.blockname() call" -ForegroundColor Yellow
$template1 = @'
{% block title %}Welcome{% endblock %}
<h1>{{ self.title() }}</h1>
<p>{{ self.title() }}</p>
'@

$result1 = Invoke-AltarTemplate -Template $template1 -Context @{}
Write-Host $result1
Write-Host ""

# Test 2: Self with variables
Write-Host "Test 2: Self with variables" -ForegroundColor Yellow
$template2 = @'
{% block greeting %}Hello, {{ name }}!{% endblock %}
{{ self.greeting() }}
{{ self.greeting() }}
'@

$result2 = Invoke-AltarTemplate -Template $template2 -Context @{ name = "World" }
Write-Host $result2
Write-Host ""

# Test 3: Self with filters
Write-Host "Test 3: Self with filters" -ForegroundColor Yellow
$template3 = @'
{% block name %}john doe{% endblock %}
Lowercase: {{ self.name() }}
Uppercase: {{ self.name() | upper }}
Title: {{ self.name() | title }}
'@

$result3 = Invoke-AltarTemplate -Template $template3 -Context @{}
Write-Host $result3
Write-Host ""

# Test 4: Reusable components
Write-Host "Test 4: Reusable components" -ForegroundColor Yellow
$template4 = @'
{% block button %}<button>{{ label }}</button>{% endblock %}
{% set label = "Save" %}{{ self.button() }}
{% set label = "Cancel" %}{{ self.button() }}
'@

$result4 = Invoke-AltarTemplate -Template $template4 -Context @{}
Write-Host $result4
Write-Host ""

Write-Host "All tests completed!" -ForegroundColor Green
