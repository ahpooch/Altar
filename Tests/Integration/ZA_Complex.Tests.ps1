# Integration tests — Full composite template combining multiple Altar/Jinja2 features:
#   variables · dot-access · filters · macro (default arg) · for (loop.index) ·
#   if/elif/else · ternary · 'in' operator · 'is' tests (divisibleby, number) ·
#   raw block · self.block() — all verified against the Jinja2 Oracle.

BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        # Oracle is already running (started by AA_OracleSetup.Tests.ps1).
        # Start-OracleService performs a liveness check and returns $null when
        # the port is already occupied — so this call is intentionally a no-op.
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
        $oraEnv = Get-OracleEnvironment
        Write-Host "  [Oracle] Jinja2 $($oraEnv.version) / Python $($oraEnv.python_version)" -ForegroundColor DarkGray
    } catch {
        Write-Warning "Jinja2 Oracle unavailable — oracle assertions skipped.`n  Run: pwsh oracle/setup.ps1 -Start"
    }

    function script:Confirm-MatchesOracle {
        param(
            [Parameter(Mandatory)] [string]    $Template,
            [hashtable]                        $Context       = @{},
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $AltarResult,
            [string]                           $UndefinedMode = 'default'
        )
        if (-not $script:OracleAvailable) { return }

        $oracle     = Invoke-OracleRender -Template $Template -Context $Context -UndefinedMode $UndefinedMode
        $altarNorm  = $AltarResult -replace '\r\n', "`n" -replace '\r', "`n"
        $oracleNorm = $oracle      -replace '\r\n', "`n" -replace '\r', "`n"
        $altarNorm | Should -Be $oracleNorm -Because 'Altar output must match canonical Jinja2 rendering'
    }
}

AfterAll {
    # $script:OracleProcess is $null (Oracle was already running from AA_OracleSetup).
    # Stop-OracleService -Process $null is a documented no-op — correct pattern here.
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
}

Describe 'Complex Multi-Feature Composite Integration Tests' -Tag 'Integration' {

    Context 'Full-Page Composite — variables · filters · macro · for · if · is · in · ternary · raw · self' {

        It 'renders composite template correctly and matches Jinja2 Oracle' {
            # Template exercises every targeted feature in a single render pass.
            # Whitespace is controlled exclusively via explicit {%- -%} strip markers
            # so the output is deterministic without TrimBlocks/LstripBlocks params
            # and is therefore fully verifiable by the Jinja2 Oracle.
            $template = @'
{%- macro badge(username, style='default') -%}
[{{ username | upper }}:{{ style }}]
{%- endmacro -%}
{%- block title -%}
ref={{ title }}
{%- endblock %} total={{ users | length }}
{%- for user in users %}
{{ loop.index }}. {{ user.name | capitalize }} ({{ 'active' if user.active else 'inactive' }}){%- if user.name in vip %} {{ badge(user.name, 'vip') }}{%- else %} {{ badge(user.name) }}{%- endif %}{%- if user.score is divisibleby(10) %} score: perfect{%- elif user.score is number %} score: {{ user.score }}{%- endif %}
{%- endfor %}
---
{{ self.title() }} | {% raw %}{{ raw_literal }}{% endraw %}
'@
            $context = @{
                title = 'REPORT'
                users = @(
                    @{ name = 'alice'; active = $true;  score = 100 }
                    @{ name = 'bob';   active = $false; score = 7   }
                    @{ name = 'diana'; active = $true;  score = 20  }
                )
                vip = @('alice', 'diana')
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            # --- per-feature sanity assertions (localise failures) ---

            # Feature: for loop.index + dot-access + capitalize filter + ternary (active branch)
            $result | Should -Match '1\. Alice \(active\)'

            # Feature: 'in' operator + macro call with named arg + upper filter (vip branch)
            $result | Should -Match '\[ALICE:vip\]'

            # Feature: 'is divisibleby' test (100 % 10 == 0 → perfect)
            $result | Should -Match 'score: perfect'

            # Feature: for loop.index + ternary (inactive branch)
            $result | Should -Match '2\. Bob \(inactive\)'

            # Feature: 'in' operator false + macro default arg (style='default')
            $result | Should -Match '\[BOB:default\]'

            # Feature: 'is number' test fallthrough (7 not divisible by 10, but is number)
            $result | Should -Match 'score: 7'

            # Feature: length filter on users array
            $result | Should -Match 'total=3'

            # Feature: block definition + self.title() re-render
            $result | Should -Match 'ref=REPORT'

            # Feature: raw block passes Jinja2 syntax through verbatim
            $result | Should -Match '\{\{ raw_literal \}\}'

            # --- Oracle exact-match: Altar output must equal canonical Jinja2 ---
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
}
