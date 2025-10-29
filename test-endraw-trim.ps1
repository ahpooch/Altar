. .\Altar.ps1

$template = @"
Start
{% raw %}
Raw content
{% endraw -%}
    End
"@

Write-Host "Template:"
Write-Host $template
Write-Host ""

$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template, "test")

Write-Host "Tokens:"
for ($i = 0; $i -lt $tokens.Count; $i++) {
    $token = $tokens[$i]
    $valueDisplay = $token.Value -replace "`r", '\r' -replace "`n", '\n'
    Write-Host "  [$i] $($token.Type): '$valueDisplay'"
}
Write-Host ""

$result = Invoke-AltarTemplate -Template $template -Context @{}
Write-Host "Result:"
Write-Host $result
Write-Host ""

$resultBytes = [System.Text.Encoding]::UTF8.GetBytes($result) | ForEach-Object { $_.ToString("X2") }
Write-Host "Result bytes: $($resultBytes -join ' ')"
