$venvPython = 'c:\Users\User\Documents\GitHub\Altar\oracle\.venv\Scripts\python.exe'
$appPath    = 'c:\Users\User\Documents\GitHub\Altar\oracle\app.py'

$proc = Start-Process -FilePath $venvPython -ArgumentList $appPath, 5000 -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 3
Write-Host "Process running: $(-not $proc.HasExited)"

Write-Host "--- Testing http://localhost:5000/health ---"
try {
    $r = Invoke-RestMethod -Uri 'http://localhost:5000/health' -TimeoutSec 2 -ErrorAction Stop
    Write-Host "localhost OK: $($r.status)"
} catch {
    Write-Host "localhost FAIL: $($_.Exception.Message)"
}

Write-Host "--- Testing http://127.0.0.1:5000/health ---"
try {
    $r = Invoke-RestMethod -Uri 'http://127.0.0.1:5000/health' -TimeoutSec 2 -ErrorAction Stop
    Write-Host "127.0.0.1 OK: $($r.status)"
} catch {
    Write-Host "127.0.0.1 FAIL: $($_.Exception.Message)"
}

$proc | Stop-Process -Force -ErrorAction SilentlyContinue
