. .\Altar.ps1

$template = @"
{% raw %}
Test content
{% endraw %}
"@

$context = @{}

Write-Host "Starting tokenization..."
$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template, "test")
Write-Host "Tokenization complete. Token count: $($tokens.Count)"

Write-Host "`nTokens:"
foreach ($token in $tokens) {
    Write-Host "  $($token.Type): '$($token.Value)'"
}

Write-Host "`nStarting parsing..."
$parser = [Parser]::new($tokens, "test")

Write-Host "Parser created. Starting ParseTemplate..."
try {
    $ast = $parser.ParseTemplate()
    Write-Host "Parsing complete!"
} catch {
    Write-Host "Error during parsing: $_"
    Write-Host $_.ScriptStackTrace
}
