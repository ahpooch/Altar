. "$PSScriptRoot/Altar.ps1"

Write-Host "=== Debug Inline Comments ===" -ForegroundColor Cyan

$template = @"
<ul>
# for item in items
    <li>{{ item }}</li>  ## this is a comment
# endfor
</ul>
"@

Write-Host "Template:" -ForegroundColor Yellow
Write-Host $template
Write-Host ""

[Lexer]::LINE_STATEMENT_PREFIX = '#'
[Lexer]::LINE_COMMENT_PREFIX = '##'

Write-Host "Tokenizing..." -ForegroundColor Yellow
$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template, "test")

Write-Host "Tokens:" -ForegroundColor Green
foreach ($token in $tokens) {
    Write-Host "  $($token.ToString())"
}

Write-Host ""
Write-Host "Rendering..." -ForegroundColor Yellow
$context = @{ items = @('Test') }

try {
    $engine = [TemplateEngine]::new()
    $result = $engine.Render($template, $context)
    
    Write-Host "Result:" -ForegroundColor Green
    Write-Host $result
    Write-Host ""
    
    if ($result -match 'this is a comment') {
        Write-Host "ERROR: Comment was not removed!" -ForegroundColor Red
    } else {
        Write-Host "SUCCESS: Comment was removed!" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}

[Lexer]::LINE_STATEMENT_PREFIX = $null
[Lexer]::LINE_COMMENT_PREFIX = $null
