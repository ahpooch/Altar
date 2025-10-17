# Debug script for super() functionality
. .\Altar.ps1

$engine = [TemplateEngine]::new()
$engine.TemplateDir = "Examples/Inheritance Statements"

# Read and parse super.alt
$superContent = [System.IO.File]::ReadAllText("Examples/Inheritance Statements/super.alt")
$superAst = $engine.Parse($superContent, "super.alt")

# Read and parse base.alt
$baseContent = [System.IO.File]::ReadAllText("Examples/Inheritance Statements/base.alt")
$baseAst = $engine.Parse($baseContent, "base.alt")

# Merge templates
$mergedAst = $engine.MergeTemplates($baseAst, $superAst)

# Compile with parent blocks
$compiler = [PowershellCompiler]::new()
foreach ($blockName in $baseAst.Blocks.Keys) {
    $compiler.ParentBlocks[$blockName] = $baseAst.Blocks[$blockName]
}

$powershellCode = $compiler.Compile($mergedAst)

Write-Host "=== Generated PowerShell Code ===" -ForegroundColor Cyan
Write-Host $powershellCode
Write-Host "=== End of Code ===" -ForegroundColor Cyan
