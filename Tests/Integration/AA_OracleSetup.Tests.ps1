# Oracle lifecycle fixture -- SETUP
# Runs first (alphabetically before all feature test files).
# Starts the Jinja2 Oracle Service once for the entire integration test run.
# All feature test files call Start-OracleService in their own BeforeAll but
# receive $null because the port is already taken -- so no duplicate starts.

BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

    $script:OracleProcess = $null
    try {
        # This is the one real Start -- all subsequent files get $null.
        $script:OracleProcess = Start-OracleService -TimeoutSeconds 30
        $oraEnv = Get-OracleEnvironment
        Write-Host "  [Oracle] Jinja2 $($oraEnv.version) / Python $($oraEnv.python_version) -- service started for this run." -ForegroundColor DarkGreen
    } catch {
        Write-Warning "Jinja2 Oracle could not be started: $_`n  Run: pwsh oracle/setup.ps1 -Start"
    }
}

Describe 'Oracle Lifecycle -- Setup' -Tag 'Integration' {

    It 'Oracle /health responds with status ok' {
        # If Oracle did not start, skip with a clear message rather than a
        # misleading connection-refused error.
        if (-not (Test-OracleReady -TimeoutSeconds 2)) {
            Set-ItResult -Skipped -Because 'Oracle service is not available'
            return
        }

        $health = Invoke-OracleHttp -Uri 'http://127.0.0.1:5000/health' -Method GET
        $health.status | Should -Be 'ok'
    }
}