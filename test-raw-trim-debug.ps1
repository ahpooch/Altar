. .\Altar.ps1

# Test to understand trim marker detection
$template1 = @"
Line 1
{% raw %}
Raw content
{% endraw %}
Line 2
"@

Write-Host "=== Test 1: {% raw %} (no trim) ==="
$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template1, "test")

Write-Host "Tokens:"
for ($i = 0; $i -lt $tokens.Count; $i++) {
    $token = $tokens[$i]
    Write-Host "  [$i] $($token.Type): '$($token.Value)'"
}
Write-Host ""

# Find the BLOCK_END token before RAW_CONTENT
for ($i = 0; $i -lt $tokens.Count; $i++) {
    if ($tokens[$i].Type -eq [TokenType]::RAW_CONTENT) {
        Write-Host "RAW_CONTENT token at index $i"
        if ($i -gt 0) {
            Write-Host "Previous token: $($tokens[$i-1].Type): '$($tokens[$i-1].Value)'"
        }
        break
    }
}
Write-Host ""

# Test 2
$template2 = @"
Line 1
{% raw -%}
Raw content
{% endraw %}
Line 2
"@

Write-Host "=== Test 2: {% raw -%} (with trim) ==="
$lexer2 = [Lexer]::new()
$tokens2 = $lexer2.Tokenize($template2, "test")

Write-Host "Tokens:"
for ($i = 0; $i -lt $tokens2.Count; $i++) {
    $token = $tokens2[$i]
    Write-Host "  [$i] $($token.Type): '$($token.Value)'"
}
Write-Host ""

# Find the BLOCK_END token before RAW_CONTENT
for ($i = 0; $i -lt $tokens2.Count; $i++) {
    if ($tokens2[$i].Type -eq [TokenType]::RAW_CONTENT) {
        Write-Host "RAW_CONTENT token at index $i"
        if ($i -gt 0) {
            Write-Host "Previous token: $($tokens2[$i-1].Type): '$($tokens2[$i-1].Value)'"
        }
        break
    }
}
