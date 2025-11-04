. .\Altar.ps1

$template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@

$context = @{ items = @("one", "two") }

Write-Host "=== Test 1: TrimBlocks=false, LstripBlocks=false (default) ==="
[Lexer]::TRIM_BLOCKS = $false
[Lexer]::LSTRIP_BLOCKS = $false
$result1 = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $false -LstripBlocks $false
Write-Host "Result:"
Write-Host $result1
Write-Host "`nEscaped:"
Write-Host ($result1 -replace "`r", '\r' -replace "`n", '\n' -replace " ", '·')

Write-Host "`n=== Test 2: TrimBlocks=true, LstripBlocks=false ==="
[Lexer]::TRIM_BLOCKS = $true
[Lexer]::LSTRIP_BLOCKS = $false
$result2 = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $false
Write-Host "Result:"
Write-Host $result2
Write-Host "`nEscaped:"
Write-Host ($result2 -replace "`r", '\r' -replace "`n", '\n' -replace " ", '·')

Write-Host "`n=== Test 3: TrimBlocks=false, LstripBlocks=true ==="
[Lexer]::TRIM_BLOCKS = $false
[Lexer]::LSTRIP_BLOCKS = $true
$result3 = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $false -LstripBlocks $true
Write-Host "Result:"
Write-Host $result3
Write-Host "`nEscaped:"
Write-Host ($result3 -replace "`r", '\r' -replace "`n", '\n' -replace " ", '·')

Write-Host "`n=== Test 4: TrimBlocks=true, LstripBlocks=true ==="
[Lexer]::TRIM_BLOCKS = $true
[Lexer]::LSTRIP_BLOCKS = $true
$result4 = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
Write-Host "Result:"
Write-Host $result4
Write-Host "`nEscaped:"
Write-Host ($result4 -replace "`r", '\r' -replace "`n", '\n' -replace " ", '·')
