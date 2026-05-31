. .\Altar.ps1

# Set environment variables
$env:Altar_TrimBlocks = "true"
$env:Altar_LstripBlocks = "false"

# Check that the lexer received the values
Write-Host "Before Invoke-AltarTemplate:"
Write-Host "Lexer TRIM_BLOCKS: $([Lexer]::TRIM_BLOCKS)"
Write-Host "Lexer LSTRIP_BLOCKS: $([Lexer]::LSTRIP_BLOCKS)"

# Create a simple template
$template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@

$context = @{
    items = @('one', 'two')
}

# Call Invoke-AltarTemplate WITHOUT explicit parameters
$result = Invoke-AltarTemplate -Template $template -Context $context

Write-Host "`nAfter Invoke-AltarTemplate:"
Write-Host "Lexer TRIM_BLOCKS: $([Lexer]::TRIM_BLOCKS)"
Write-Host "Lexer LSTRIP_BLOCKS: $([Lexer]::LSTRIP_BLOCKS)"

Write-Host "`nResult:"
Write-Host $result

Write-Host "`nResult (escaped for debugging):"
Write-Host ($result -replace "`r", '\r' -replace "`n", '\n')

# Clear environment variables
$env:Altar_TrimBlocks = $null
$env:Altar_LstripBlocks = $null
