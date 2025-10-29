. "$PSScriptRoot/Altar.ps1"

Write-Host "=== Debug Nested Line Statements ===" -ForegroundColor Cyan

$template = @"
# for category in categories
    <h2>{{ category.name }}</h2>
    <ul>
    # for item in category.items
        <li>{{ item }}</li>
    # endfor
    </ul>
# endfor
"@

Write-Host "Template:" -ForegroundColor Yellow
Write-Host $template
Write-Host ""

[Lexer]::LINE_STATEMENT_PREFIX = '#'

$context = @{
    categories = @(
        @{ name = 'Fruits'; items = @('Apple', 'Banana') },
        @{ name = 'Vegetables'; items = @('Carrot', 'Potato') }
    )
}

Write-Host "Rendering..." -ForegroundColor Yellow

try {
    $engine = [TemplateEngine]::new()
    $result = $engine.Render($template, $context)
    
    Write-Host "Result:" -ForegroundColor Green
    Write-Host $result
    Write-Host ""
    
    if ($result -match 'Apple') {
        Write-Host "SUCCESS: Found Apple!" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Apple not found!" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

[Lexer]::LINE_STATEMENT_PREFIX = $null
