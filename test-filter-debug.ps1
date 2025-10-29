. .\Altar.ps1

# Test truncate filter
$template = '{{ "This is a very long text" | truncate(10) }}'
Write-Host "Template: $template"

try {
    $result = Invoke-AltarTemplate -Template $template -Context @{}
    Write-Host "Result: $result"
} catch {
    Write-Host "Error: $_"
    Write-Host "Exception: $($_.Exception.Message)"
    Write-Host "Stack: $($_.ScriptStackTrace)"
}

# Test sort filter
$template2 = '{{ items | sort }}'
Write-Host "`nTemplate: $template2"

try {
    $result2 = Invoke-AltarTemplate -Template $template2 -Context @{ items = @(3, 1, 2) }
    Write-Host "Result: $result2"
} catch {
    Write-Host "Error: $_"
    Write-Host "Exception: $($_.Exception.Message)"
}

# Test int filter
$template3 = '{{ val | int }}'
Write-Host "`nTemplate: $template3"

try {
    $result3 = Invoke-AltarTemplate -Template $template3 -Context @{ val = "42" }
    Write-Host "Result: $result3"
} catch {
    Write-Host "Error: $_"
    Write-Host "Exception: $($_.Exception.Message)"
}
