
. .\Altar.ps1

Write-Host "Running single test: Preserves content inside raw block without processing"

$template = @"
First line.

{% raw %}
This section will not be processed by Altar.
You can include {{ variables }} or {% for loops %} here,
and they will be displayed as literal text.
{% endraw %}

Last line.
"@
$context = @{}

Write-Host "Invoking template..."
$result = Invoke-AltarTemplate -Template $template -Context $context

$expected = @"
First line.

This section will not be processed by Altar.
You can include {{ variables }} or {% for loops %} here,
and they will be displayed as literal text.

Last line.
"@

Write-Host "`nResult:"
Write-Host "=" * 60
Write-Host $result
Write-Host "=" * 60

Write-Host "`nExpected:"
Write-Host "=" * 60
Write-Host $expected
Write-Host "=" * 60

Write-Host "`nComparison:"
Write-Host "Result length: $($result.Length)"
Write-Host "Expected length: $($expected.Length)"
Write-Host "Are equal: $($result -eq $expected)"

if ($result -ne $expected) {
    Write-Host "`nDifferences:"
    for ($i = 0; $i -lt [Math]::Max($result.Length, $expected.Length); $i++) {
        if ($i -ge $result.Length) {
            Write-Host "  [$i] Result: <END>, Expected: '$($expected[$i])' (char $([int]$expected[$i]))"
        } elseif ($i -ge $expected.Length) {
            Write-Host "  [$i] Result: '$($result[$i])' (char $([int]$result[$i])), Expected: <END>"
        } elseif ($result[$i] -ne $expected[$i]) {
            Write-Host "  [$i] Result: '$($result[$i])' (char $([int]$result[$i])), Expected: '$($expected[$i])' (char $([int]$expected[$i]))"
        }
    }
}
