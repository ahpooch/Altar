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
Write-Host "Tokenization complete."

Write-Host "Starting parsing..."
$parser = [Parser]::new($tokens, "test")
$ast = $parser.ParseTemplate()
Write-Host "Parsing complete."

Write-Host "`nStarting compilation..."
$compiler = [PowershellCompiler]::new()
$code = $compiler.Compile($ast)
Write-Host "Compilation complete."

Write-Host "`nGenerated PowerShell code:"
Write-Host "=" * 60
Write-Host $code
Write-Host "=" * 60

Write-Host "`nCreating scriptblock..."
$scriptBlock = [scriptblock]::Create($code)
Write-Host "Scriptblock created."

Write-Host "`nExecuting scriptblock..."
try {
    $result = & $scriptBlock $context ""
    Write-Host "Execution complete."
    Write-Host "`nResult:"
    Write-Host "=" * 60
    Write-Host $result
    Write-Host "=" * 60
} catch {
    Write-Host "Error during execution: $_"
    Write-Host $_.ScriptStackTrace
}
