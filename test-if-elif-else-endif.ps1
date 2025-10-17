# Import the Altar template engine
. .\Altar.ps1

$template = @"
First line.

{% if fact -%}
  fact is True
{% elif fact2 -%}
  fact2 is True
{% elif fact3 -%}
  fact3 is True
{% else -%}
  all facts are False
{% endif -%}

Last line.
"@

# Create a context with if elif else endif
$context = @{
    fact = $false
    fact2 = $false
    fact3 = $false
}

# Print the compiled PowerShell code for debugging
$lexer = [Lexer]::new()
$tokens = $lexer.Tokenize($template, "template")
$parser = [Parser]::new($tokens, "template")
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
