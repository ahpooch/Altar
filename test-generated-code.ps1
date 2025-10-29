. .\Altar.ps1

# Clear cache to force recompilation
[TemplateEngine]::Cache.Clear()

$template = '{{ val | int }}'
Write-Host "Template: $template"
Write-Host ""

$engine = [TemplateEngine]::new()
$compiled = $engine.Compile($template, "test")

Write-Host "Generated PowerShell code:"
Write-Host "=" * 80
Write-Host $compiled.ToString()
Write-Host "=" * 80
