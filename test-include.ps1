# Import the Altar template engine
. .\Altar.ps1

# Create a context
$context = @{
    var = "test value from context"
}

# Render the template using -Path (this properly sets the template directory)
Write-Host "Rendering template with include..."
$result = Invoke-AltarTemplate -Path '.\Examples\Include Statement\main.alt' -Context $context

# Display the result
Write-Host "`nResult:`n"
Write-Host $result
