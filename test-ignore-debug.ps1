# Import the Altar template engine
. .\Altar.ps1

# Clear cache
[TemplateEngine]::Cache.Clear()

# Simple test template
$template = @"
Line 1
{% include 'nonexistent.alt' ignore missing -%}
Line 2
"@

# Tokenize to see what tokens are generated
$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template, "test")

"Tokens:" | Out-File -FilePath "debug-output.txt"
foreach ($token in $tokens) {
    "  Type: $($token.Type), Value: '$($token.Value)'" | Out-File -FilePath "debug-output.txt" -Append
}

# Try to parse
$parser = [Parser]::new($tokens, "test")

try {
    $ast = $parser.ParseTemplate()
    "Parsing successful!" | Out-File -FilePath "debug-output.txt" -Append
    "AST Body count: $($ast.Body.Count)" | Out-File -FilePath "debug-output.txt" -Append
    
    foreach ($node in $ast.Body) {
        "Node type: $($node.GetType().Name)" | Out-File -FilePath "debug-output.txt" -Append
        if ($node -is [IncludeNode]) {
            "  Template: $($node.Template.Value)" | Out-File -FilePath "debug-output.txt" -Append
            "  IgnoreMissing: $($node.IgnoreMissing)" | Out-File -FilePath "debug-output.txt" -Append
        }
    }
} catch {
    "Parsing failed: $_" | Out-File -FilePath "debug-output.txt" -Append
}

Write-Host "Debug output saved to debug-output.txt"
