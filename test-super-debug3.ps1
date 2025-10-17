# Debug script for super() functionality
. .\Altar.ps1

$engine = [TemplateEngine]::new()
$engine.TemplateDir = "Examples/Inheritance Statements"

# Read and parse base.alt
$baseContent = [System.IO.File]::ReadAllText("Examples/Inheritance Statements/base.alt")
$baseAst = $engine.Parse($baseContent, "base.alt")

# Compile just the parent block using a separate compiler
$parentCompiler = [PowershellCompiler]::new()
$parentCompiler.CurrentBlock = $null

Write-Host "=== Compiling Parent Block 'content' ===" -ForegroundColor Cyan
$contentBlock = $baseAst.Blocks['content']
foreach ($statement in $contentBlock.Body) {
    $parentCompiler.Visit($statement)
}

$parentCode = $parentCompiler.Code.ToString()
Write-Host "Parent block code:"
Write-Host $parentCode

Write-Host "`n=== After String.Replace ===" -ForegroundColor Cyan
$modifiedCode = $parentCode.Replace('$output.Append', "`$__SUPER_BLOCK_content__.Append")
Write-Host $modifiedCode

Write-Host "`n=== Checking if replacement worked ===" -ForegroundColor Cyan
if ($modifiedCode -match '\$output\.Append') {
    Write-Host "ERROR: Still contains `$output.Append!" -ForegroundColor Red
} else {
    Write-Host "SUCCESS: No `$output.Append found!" -ForegroundColor Green
}

if ($modifiedCode -match '\$__SUPER_BLOCK_content__\.Append') {
    Write-Host "SUCCESS: Contains `$__SUPER_BLOCK_content__.Append!" -ForegroundColor Green
} else {
    Write-Host "ERROR: Does not contain `$__SUPER_BLOCK_content__.Append!" -ForegroundColor Red
}
