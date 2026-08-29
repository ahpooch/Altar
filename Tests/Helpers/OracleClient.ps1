<#
.SYNOPSIS
    PowerShell client for the Jinja2 Oracle Service.

.DESCRIPTION
    Wraps all oracle HTTP endpoints with idiomatic PowerShell functions.
    Designed to be dot-sourced in Pester test files.

    Functions:
        Start-OracleService    — Start the oracle process in the background
        Stop-OracleService     — Stop the oracle process
        Test-OracleReady       — Wait until /health returns 200
        Invoke-OracleRender    — POST /render
        Invoke-OracleBatch     — POST /batch
        Invoke-OracleParse     — POST /parse
        Invoke-OracleValidate  — POST /validate
        Get-OracleEnvironment  — GET /environment
        Get-OracleCapabilities — GET /capabilities

.EXAMPLE
    # In a Pester describe block:

    BeforeAll {
        . "$PSScriptRoot/../../Altar.ps1"
        . "$PSScriptRoot/OracleClient.ps1"
        $script:Oracle = Start-OracleService
    }

    AfterAll {
        Stop-OracleService -Process $script:Oracle
    }

    It "upper filter matches Jinja2" {
        $expected = Invoke-OracleRender -Template '{{ "hello" | upper }}'
        $actual   = Invoke-AltarTemplate -Template '{{ "hello" | upper }}' -Context @{}
        $actual | Should -Be $expected
    }
#>

Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Module-level defaults
# ---------------------------------------------------------------------------

$script:OracleBaseUrl = 'http://127.0.0.1:5000'

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

function Start-OracleService {
    <#
    .SYNOPSIS
        Start the Jinja2 Oracle Service as a background process.

    .DESCRIPTION
        Runs oracle/setup.ps1 -Start (which uses the .venv Python) and waits
        until the /health endpoint responds. Returns the Process object so
        the caller can pass it to Stop-OracleService.

    .PARAMETER Port
        Port to start the service on. Default: 5000.

    .PARAMETER TimeoutSeconds
        How long to wait for the service to become ready. Default: 15.

    .PARAMETER OracleRoot
        Path to the oracle/ directory. Defaults to <repo-root>/oracle.

    .OUTPUTS
        System.Diagnostics.Process

    .EXAMPLE
        $script:Oracle = Start-OracleService
        $script:Oracle = Start-OracleService -Port 8080
    #>
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Process])]
    param(
        [int]    $Port           = 5000,
        [int]    $TimeoutSeconds = 15,
        [string] $OracleRoot     = (Join-Path $PSScriptRoot '..\..\oracle')
    )

    $script:OracleBaseUrl = "http://127.0.0.1:$Port"

    # Resolve the venv Python binary (cross-platform)
    $venvDir    = Join-Path $OracleRoot '.venv'
    $venvPython = if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') {
        Join-Path $venvDir 'Scripts' 'python.exe'
    } else {
        Join-Path $venvDir 'bin' 'python'
    }
    $appPath = Join-Path $OracleRoot 'app.py'

    # If venv is not set up yet, run setup first
    if (-not (Test-Path $venvPython)) {
        Write-Verbose "Oracle venv not found. Running setup..."
        $setupScript = Join-Path $OracleRoot 'setup.ps1'
        & pwsh -File $setupScript
    }

    Write-Verbose "Starting oracle on port $Port..."
    $proc = Start-Process -FilePath $venvPython `
                          -ArgumentList $appPath, $Port `
                          -PassThru `
                          -WindowStyle Hidden

    # Wait until /health is reachable
    if (-not (Test-OracleReady -TimeoutSeconds $TimeoutSeconds -Port $Port)) {
        $proc | Stop-Process -Force -ErrorAction SilentlyContinue
        throw "Oracle service did not become ready within $TimeoutSeconds seconds."
    }

    Write-Verbose "Oracle service is ready (PID $($proc.Id)) on port $Port."
    return $proc
}


function Stop-OracleService {
    <#
    .SYNOPSIS
        Stop the Jinja2 Oracle Service.

    .PARAMETER Process
        The Process object returned by Start-OracleService.

    .EXAMPLE
        Stop-OracleService -Process $script:Oracle
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process] $Process
    )

    if (-not $Process.HasExited) {
        $Process | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Verbose "Oracle service stopped (PID $($Process.Id))."
    }
}


function Test-OracleReady {
    <#
    .SYNOPSIS
        Wait until the oracle /health endpoint responds successfully.

    .PARAMETER TimeoutSeconds
        Maximum wait time. Default: 15.

    .PARAMETER Port
        Port to check. Default: 5000.

    .OUTPUTS
        bool — $true if ready within timeout, $false otherwise.

    .EXAMPLE
        if (-not (Test-OracleReady -TimeoutSeconds 20)) { throw "Oracle not ready" }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [int] $TimeoutSeconds = 15,
        [int] $Port           = 5000
    )

    $url      = "http://127.0.0.1:$Port/health"
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)

    while ([datetime]::UtcNow -lt $deadline) {
        try {
            $null = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 1 -ErrorAction Stop
            return $true
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Render endpoints
# ---------------------------------------------------------------------------

function Invoke-OracleRender {
    <#
    .SYNOPSIS
        POST /render — render a single Jinja2 template.

    .DESCRIPTION
        Sends the template and context to the oracle and returns the rendered
        output string. Throws if the oracle returns success=false.

    .PARAMETER Template
        Jinja2 template string.

    .PARAMETER Context
        Hashtable of template variables.

    .PARAMETER UndefinedMode
        "strict" (default) or "default".

    .PARAMETER RequestId
        Optional correlation identifier echoed back by the oracle.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .PARAMETER AllowError
        When specified, do not throw on oracle errors — return the full
        response object instead (useful for testing error paths).

    .OUTPUTS
        string — rendered output, or PSCustomObject when -AllowError is used.

    .EXAMPLE
        $expected = Invoke-OracleRender -Template '{{ name | upper }}' -Context @{ name = 'world' }

    .EXAMPLE
        $resp = Invoke-OracleRender -Template '{{ missing }}' -AllowError
        $resp.success   | Should -BeFalse
        $resp.exception | Should -Be 'UndefinedError'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]    $Template,

        [hashtable] $Context       = @{},
        [string]    $UndefinedMode = 'strict',
        [string]    $RequestId,

        [string]    $OracleUrl     = $script:OracleBaseUrl,
        [switch]    $AllowError
    )

    $body = [ordered]@{
        template       = $Template
        context        = $Context
        undefined_mode = $UndefinedMode
    }
    if ($RequestId) { $body['request_id'] = $RequestId }

    $response = Invoke-RestMethod `
        -Uri         "$OracleUrl/render" `
        -Method      Post `
        -ContentType 'application/json' `
        -Body        ($body | ConvertTo-Json -Depth 20) `
        -ErrorAction Stop

    if ($AllowError) {
        return $response
    }

    if (-not $response.success) {
        throw "Oracle error [$($response.exception)]: $($response.message)"
    }

    return $response.output
}


function Invoke-OracleBatch {
    <#
    .SYNOPSIS
        POST /batch — render multiple templates in a single request.

    .DESCRIPTION
        Accepts an array of request hashtables (same structure as /render)
        and returns an array of response objects.

    .PARAMETER Requests
        Array of hashtables, each with keys: template, context, undefined_mode, request_id.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .OUTPUTS
        Object[] — array of oracle response objects.

    .EXAMPLE
        $requests = @(
            @{ request_id = 'r1'; template = '{{ x }}'; context = @{ x = 1 } },
            @{ request_id = 'r2'; template = '{{ y }}'; context = @{ y = 2 } }
        )
        $results = Invoke-OracleBatch -Requests $requests
        $results[0].output | Should -Be '1'
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object[]] $Requests,

        [string]   $OracleUrl = $script:OracleBaseUrl
    )

    $json = $Requests | ConvertTo-Json -Depth 20 -AsArray

    $response = Invoke-RestMethod `
        -Uri         "$OracleUrl/batch" `
        -Method      Post `
        -ContentType 'application/json' `
        -Body        $json `
        -ErrorAction Stop

    return $response
}


function Invoke-OracleParse {
    <#
    .SYNOPSIS
        POST /parse — parse a template and return its Jinja2 AST.

    .PARAMETER Template
        Jinja2 template string.

    .PARAMETER RequestId
        Optional correlation identifier.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .OUTPUTS
        PSCustomObject — oracle response with .ast property.

    .EXAMPLE
        $resp = Invoke-OracleParse -Template '{% if x %}ok{% endif %}'
        $resp.success | Should -BeTrue
        $resp.ast.node_type | Should -Be 'Template'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Template,

        [string] $RequestId,
        [string] $OracleUrl = $script:OracleBaseUrl
    )

    $body = [ordered]@{ template = $Template }
    if ($RequestId) { $body['request_id'] = $RequestId }

    return Invoke-RestMethod `
        -Uri         "$OracleUrl/parse" `
        -Method      Post `
        -ContentType 'application/json' `
        -Body        ($body | ConvertTo-Json -Depth 20) `
        -ErrorAction Stop
}


function Invoke-OracleValidate {
    <#
    .SYNOPSIS
        POST /validate — validate template syntax without rendering.

    .DESCRIPTION
        Returns $true if the template is syntactically valid.
        Returns $false (or throws) if there is a TemplateSyntaxError.

    .PARAMETER Template
        Jinja2 template string.

    .PARAMETER RequestId
        Optional correlation identifier.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .PARAMETER PassThru
        Return the full response object instead of a boolean.

    .OUTPUTS
        bool, or PSCustomObject when -PassThru is used.

    .EXAMPLE
        Invoke-OracleValidate -Template '{% if x %}ok{% endif %}' | Should -BeTrue

    .EXAMPLE
        $resp = Invoke-OracleValidate -Template '{% bad %}' -PassThru
        $resp.exception | Should -Be 'TemplateSyntaxError'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Template,

        [string] $RequestId,
        [string] $OracleUrl = $script:OracleBaseUrl,
        [switch] $PassThru
    )

    $body = [ordered]@{ template = $Template }
    if ($RequestId) { $body['request_id'] = $RequestId }

    $response = Invoke-RestMethod `
        -Uri         "$OracleUrl/validate" `
        -Method      Post `
        -ContentType 'application/json' `
        -Body        ($body | ConvertTo-Json -Depth 20) `
        -ErrorAction Stop

    if ($PassThru) { return $response }
    return [bool]$response.success
}

# ---------------------------------------------------------------------------
# Informational endpoints
# ---------------------------------------------------------------------------

function Get-OracleEnvironment {
    <#
    .SYNOPSIS
        GET /environment — retrieve Jinja2 environment configuration.

    .DESCRIPTION
        Returns the full environment object including Jinja2 version,
        Python version, all available filters and tests.

        Recommended: call this once in BeforeAll and write to a log file
        to record the oracle configuration for the test run.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .OUTPUTS
        PSCustomObject — oracle environment response.

    .EXAMPLE
        $env = Get-OracleEnvironment
        Write-Host "Jinja2 $($env.version) / Python $($env.python_version)"
    #>
    [CmdletBinding()]
    param(
        [string] $OracleUrl = $script:OracleBaseUrl
    )

    return Invoke-RestMethod -Uri "$OracleUrl/environment" -Method Get -ErrorAction Stop
}


function Get-OracleCapabilities {
    <#
    .SYNOPSIS
        GET /capabilities — retrieve the list of oracle capabilities.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .OUTPUTS
        PSCustomObject — capabilities response.

    .EXAMPLE
        $caps = Get-OracleCapabilities
        $caps.batch | Should -BeTrue
    #>
    [CmdletBinding()]
    param(
        [string] $OracleUrl = $script:OracleBaseUrl
    )

    return Invoke-RestMethod -Uri "$OracleUrl/capabilities" -Method Get -ErrorAction Stop
}
