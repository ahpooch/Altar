# Debug script for super() functionality
. .\Altar.ps1

$engine = [TemplateEngine]::new()
$engine.TemplateDir = "Examples/Inheritance Statements"

# Read and parse base.alt
$baseContent = [System.IO.File]::ReadAllText("Examples/Inheritance Statements/base.alt")
$baseAst = $engine.Parse($baseContent, "base.alt")

Write-Host "=== Base Template Blocks ===" -ForegroundColor Cyan
foreach ($blockName in $baseAst.Blocks.Keys) {
    Write-Host "Block: $blockName"
    $block = $baseAst.Blocks[$blockName]
    Write-Host "  Body count: $($block.Body.Count)"
    foreach ($stmt in $block.Body) {
        Write-Host "  - $($stmt.GetType().Name)"
    }
}

# Compile just the parent block
$compiler = [PowershellCompiler]::new()
$compiler.CurrentBlock = $null

Write-Host "`n=== Compiling Parent Block 'content' ===" -ForegroundColor Cyan
$contentBlock = $baseAst.Blocks['content']
foreach ($statement in $contentBlock.Body) {
    $compiler.Visit($statement)
}

$parentCode = $compiler.Code.ToString()
Write-Host "Parent block code:"
Write-Host $parentCode

Write-Host "`n=== After Regex Replace ===" -ForegroundColor Cyan
$pattern = [regex]::Escape('$output.Append')
$replacement = '$__SUPER_BLOCK_content__.Append'
$modifiedCode = [regex]::Replace($parentCode, $pattern, $replacement)
Write-Host $modifiedCode
