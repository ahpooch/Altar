# Import the Altar template engine
. .\Altar.ps1

$template_relative_path = ".\Examples\Variable\example-variable.alt"
$template_absolute_path = Resolve-Path -Path $template_relative_path
$template = Get-Content -Path $template_absolute_path -Raw

# Create a context
$context = @{
    variable = "value"
}

# Print the tokens for debugging
$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template, $template_absolute_path)

Write-Host "`nTokens:`n"
for ($i = 0; $i -lt $tokens.Count; $i++) {
    Write-Host "Token[$i]: $($tokens[$i])"
}

# Print the compiled PowerShell code for debugging
$parser = [Parser]::new($tokens, $template_absolute_path)
$ast = $parser.ParseTemplate()
$compiler = [PowershellCompiler]::new()
$powershellCode = $compiler.Compile($ast)
Write-Host "`nCompiled PowerShell code:`n"
Write-Host $powershellCode

# Render the template
Write-Host "Rendering template with if elif else endif..."
$result = Invoke-AltarTemplate -Template $template -Context $context

# Display the result
Write-Host "`nResult:`n"
Write-Host $result
