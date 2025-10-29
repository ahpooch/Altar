# Test current block scope behavior in Altar
. .\Altar.ps1

# Test 1: Block inside loop without scoped (should not have access to loop variable)
$template1 = @"
{% for item in items %}
<li>{% block loop_item %}{{ item }}{% endblock %}</li>
{% endfor %}
"@

$context1 = @{
    items = @('apple', 'banana', 'cherry')
}

Write-Host "Test 1: Block inside loop (current behavior)"
Write-Host "Template:"
Write-Host $template1
Write-Host "`nResult:"
try {
    $result1 = Invoke-AltarTemplate -Template $template1 -Context $context1
    Write-Host $result1
} catch {
    Write-Host "Error: $_"
}

Write-Host "`n" + ("=" * 60) + "`n"

# Test 2: What we want with scoped modifier
$template2 = @"
{% for item in items %}
<li>{% block loop_item scoped %}{{ item }}{% endblock %}</li>
{% endfor %}
"@

$context2 = @{
    items = @('apple', 'banana', 'cherry')
}

Write-Host "Test 2: Block inside loop with 'scoped' modifier (desired behavior)"
Write-Host "Template:"
Write-Host $template2
Write-Host "`nResult:"
try {
    $result2 = Invoke-AltarTemplate -Template $template2 -Context $context2
    Write-Host $result2
} catch {
    Write-Host "Error: $_"
}
