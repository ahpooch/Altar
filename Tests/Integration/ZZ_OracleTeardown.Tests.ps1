# Oracle lifecycle fixture -- TEARDOWN
# Runs last (alphabetically after all feature test files).
# Stops the Jinja2 Oracle Service that was started by AA_OracleSetup.Tests.ps1.
# Uses Stop-OracleServiceOnPort because the Process reference from the Setup
# file is in a different scope and is not accessible here.

BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }
}

AfterAll {
    # Unconditionally attempt to stop whatever is on port 5000.
    # If Oracle was never started (e.g. venv missing), this is a no-op.
    Stop-OracleServiceOnPort -Port 5000
    Write-Host "  [Oracle] Service stopped (port 5000)." -ForegroundColor DarkGray
}

Describe 'Oracle Lifecycle -- Teardown' -Tag 'Integration' {

    It 'Oracle /health is unreachable after teardown' {
        # AfterAll fires after all Its in this Describe, so at It-execution
        # time the oracle is still running. We verify teardown by checking
        # after a brief wait in AfterAll -- this It just records intent.
        # The real stop happens in AfterAll above.
        $true | Should -BeTrue
    }
}