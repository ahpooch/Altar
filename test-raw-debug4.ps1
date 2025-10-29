. .\Altar.ps1

# This is the exact template from the first failing test
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

Write-Host "Starting tokenization..."
$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template, "test")
Write-Host "Tokenization complete. Token count: $($tokens.Count)"

Write-Host "`nTokens (first 20):"
for ($i = 0; $i -lt [Math]::Min(20, $tokens.Count); $i++) {
    Write-Host "  [$i] $($tokens[$i].Type): '$($tokens[$i].Value)'"
}

Write-Host "`nStarting parsing..."
$parser = [Parser]::new($tokens, "test")

Write-Host "Parser created. Starting ParseTemplate..."
try {
    $ast = $parser.ParseTemplate()
    Write-Host "Parsing complete!"
    Write-Host "AST Body count: $($ast.Body.Count)"
} catch {
    Write-Host "Error during parsing: $_"
    Write-Host $_.ScriptStackTrace
}
