. .\Altar.ps1

$template = @"
{% for item in items -%}
<li>{% block loop_item scoped %}{{ item }}{% endblock %}</li>
{% endfor -%}
"@

$context = @{ items = @('apple', 'banana', 'cherry') }

# Compile and show generated code
$engine = [TemplateEngine]::new()
$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template, "test")
$parser = [Parser]::new($tokens, "test")
$ast = $parser.ParseTemplate()
$compiler = [PowershellCompiler]::new()
$code = $compiler.Compile($ast)

Write-Host "=== Generated PowerShell Code ===" -ForegroundColor Cyan
Write-Host $code
Write-Host "=== End of Generated Code ===" -ForegroundColor Cyan
Write-Host ""

# Try to execute
try {
    $result = Invoke-AltarTemplate -Template $template -Context $context
    Write-Host "Result:" -ForegroundColor Green
    Write-Host $result
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
}
