. "$PSScriptRoot/Tests/Helpers/OracleClient.ps1"

$venvPython = "c:\Users\User\Documents\GitHub\Altar\oracle\.venv\Scripts\python.exe"
$appPath    = "c:\Users\User\Documents\GitHub\Altar\oracle\app.py"
$tmpOut     = "$env:TEMP\oracle-out.txt"
$tmpErr     = "$env:TEMP\oracle-err.txt"

Write-Host "=== Test 1: Start-Process -WindowStyle Hidden ==="
$proc = Start-Process -FilePath $venvPython -ArgumentList $appPath, 5000 `
    -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 3
Write-Host "Process HasExited: $($proc.HasExited)"
Write-Host "Process ExitCode: $(if ($proc.HasExited) { $proc.ExitCode } else { 'still running' })"
# check port
$tcpState = netstat -an 2>$null | Select-String ':5000'
Write-Host "Port 5000 netstat: $($tcpState -join '; ')"
$proc | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host ""

Write-Host "=== Test 2: Start-Process with output redirect (no WindowStyle Hidden) ==="
$proc2 = Start-Process -FilePath $venvPython -ArgumentList $appPath, 5001 `
    -PassThru `
    -RedirectStandardOutput $tmpOut `
    -RedirectStandardError  $tmpErr
Start-Sleep -Seconds 3
Write-Host "Process HasExited: $($proc2.HasExited)"
Write-Host "Process ExitCode: $(if ($proc2.HasExited) { $proc2.ExitCode } else { 'still running' })"
$tcpState2 = netstat -an 2>$null | Select-String ':5001'
Write-Host "Port 5001 netstat: $($tcpState2 -join '; ')"
Write-Host "--- stdout ---"
Get-Content $tmpOut -ErrorAction SilentlyContinue | Write-Host
Write-Host "--- stderr ---"
Get-Content $tmpErr -ErrorAction SilentlyContinue | Write-Host
$proc2 | Stop-Process -Force -ErrorAction SilentlyContinue
