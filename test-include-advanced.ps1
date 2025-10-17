# Import the Altar template engine
. .\Altar.ps1

# Create a context
$context = @{
    var = "test"
    username = "Guest"
    content = "This is a demonstration of the include functionality with multiple includes."
}

# Render the template using -Path (this properly sets the template directory)
Write-Host "Rendering advanced template with multiple includes..."
$result = Invoke-AltarTemplate -Path '.\Examples\Include Statement\page.alt' -Context $context

# Display the result
Write-Host "`nResult:`n"
Write-Host $result
