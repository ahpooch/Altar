. "$PSScriptRoot/Altar.ps1"

Write-Host "=== Debug Line Statements ===" -ForegroundColor Cyan

$template = @"
<ul>
# for item in items
    <li>{{ item }}</li>
# endfor
</ul>
"@

Write-Host "Template:" -ForegroundColor Yellow
Write-Host $template
Write-Host ""

Write-Host "Setting prefix..." -ForegroundColor Yellow
[Lexer]::LINE_STATEMENT_PREFIX = '#'

Write-Host "Tokenizing..." -ForegroundColor Yellow
$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template, "test")

Write-Host "Tokens:" -ForegroundColor Green
foreach ($token in $tokens) {
    Write-Host "  $($token.ToString())"
}

Write-Host ""
Write-Host "Rendering..." -ForegroundColor Yellow
$context = @{ items = @('Apple', 'Banana') }

try {
    $engine = [TemplateEngine]::new()
    $result = $engine.Render($template, $context)
    
    Write-Host "Result:" -ForegroundColor Green
    Write-Host $result
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

[Lexer]::LINE_STATEMENT_PREFIX = $null
