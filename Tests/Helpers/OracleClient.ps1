<#
.SYNOPSIS
    PowerShell client for the Jinja2 Oracle Service.

.DESCRIPTION
    Wraps all oracle HTTP endpoints with idiomatic PowerShell functions.
    Designed to be dot-sourced in Pester test files.

    Functions:
        Start-OracleService       - Start the oracle process (no-op if already running on port)
        Stop-OracleService        - Stop the oracle process by Process object ($null-safe)
        Stop-OracleServiceOnPort  - Stop the oracle process by port number (no Process ref needed)
        Test-OracleReady          - Wait until /health returns 200
        Invoke-OracleRender    - POST /render
        Invoke-OracleBatch     - POST /batch
        Invoke-OracleParse     - POST /parse
        Invoke-OracleValidate  - POST /validate
        Get-OracleEnvironment  - GET /environment
        Get-OracleCapabilities - GET /capabilities

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

# PS 5.1's Invoke-RestMethod decodes response bodies using the system code page
# (cp1252 on Windows) instead of the UTF-8 declared in Content-Type.
# This helper uses System.Net.WebRequest to force UTF-8 decoding on all versions.
function script:Invoke-OracleHttp {
    param(
        [string] $Uri,
        [string] $Method = 'GET',
        [string] $Body   = $null
    )
    $req = [System.Net.WebRequest]::Create($Uri)
    $req.Method = $Method
    if ($Body) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $req.ContentType   = 'application/json; charset=utf-8'
        $req.ContentLength = $bytes.Length
        $stream = $req.GetRequestStream()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
    }
    $resp   = $req.GetResponse()
    $reader = [System.IO.StreamReader]::new($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
    $json   = $reader.ReadToEnd()
    $reader.Close()
    $resp.Close()
    return $json | ConvertFrom-Json
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

function Start-OracleService {
    <#
    .SYNOPSIS
        Start the Jinja2 Oracle Service as a background process.

    .DESCRIPTION
        Checks whether the oracle is already listening on the given port.
        If it is, returns $null immediately (no-op -- the caller's AfterAll
        should pass $null to Stop-OracleService, which is also a no-op).
        If it is not, starts a new background process using the .venv Python
        and waits until /health responds.

        This makes it safe to call Start-OracleService in every test file's
        BeforeAll: only the first file actually launches the process; all
        subsequent files reuse the already-running instance.

    .PARAMETER Port
        Port to start the service on. Default: 5000.

    .PARAMETER TimeoutSeconds
        How long to wait for the service to become ready. Default: 15.

    .PARAMETER OracleRoot
        Path to the oracle/ directory. Defaults to <repo-root>/oracle.

    .OUTPUTS
        System.Diagnostics.Process - the new process, or $null if Oracle was
        already running and no new process was started.

    .EXAMPLE
        $script:OracleProcess = Start-OracleService -TimeoutSeconds 20
        # Returns a Process when it starts a new instance; $null otherwise.

    .EXAMPLE
        $script:OracleProcess = Start-OracleService -Port 8080
    #>
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Process])]
    param(
        [int]    $Port           = 5000,
        [int]    $TimeoutSeconds = 15,
        [string] $OracleRoot     = (Join-Path $PSScriptRoot '..\..\oracle')
    )

    $script:OracleBaseUrl = "http://127.0.0.1:$Port"

    # If Oracle is already answering on this port, reuse it - return $null so
    # the caller's AfterAll no-ops through Stop-OracleService.
    if (Test-OracleReady -TimeoutSeconds 2 -Port $Port) {
        Write-Verbose "Oracle already running on port $Port - reusing existing instance."
        return $null
    }

    # Resolve the venv Python binary (cross-platform)
    # Note: Join-Path with 3 arguments is PS 6+ only - use nested calls for PS 5.1 compat.
    $venvDir    = Join-Path $OracleRoot '.venv'
    $venvPython = if ($PSVersionTable.PSEdition -eq 'Desktop' -or $PSVersionTable.Platform -eq 'Win32NT') {
        Join-Path (Join-Path $venvDir 'Scripts') 'python.exe'
    } else {
        Join-Path (Join-Path $venvDir 'bin') 'python'
    }
    $appPath = Join-Path $OracleRoot 'app.py'

    # If venv is not set up yet, run setup first
    if (-not (Test-Path $venvPython)) {
        Write-Verbose "Oracle venv not found. Running setup..."
        $setupScript = Join-Path $OracleRoot 'setup.ps1'
        # Use the correct PowerShell host - pwsh (PS7+) or powershell.exe (PS5.1)
        $psExe = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell' } else { 'pwsh' }
        & $psExe -File $setupScript
    }

    Write-Verbose "Starting oracle on port $Port..."
    # -NoNewWindow is required on Windows for -Redirect* parameters to work.
    # Redirecting stdout and stderr to separate temp files silences Flask's
    # per-request access log so it does not bleed into the Pester console.
    # (Windows does not allow both streams to redirect to the same path, even 'NUL'.)
    $stdoutLog = [System.IO.Path]::GetTempFileName()
    $stderrLog = [System.IO.Path]::GetTempFileName()
    $proc = Start-Process -FilePath  $venvPython `
                          -ArgumentList $appPath, $Port `
                          -PassThru `
                          -NoNewWindow `
                          -RedirectStandardOutput $stdoutLog `
                          -RedirectStandardError  $stderrLog

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
        [AllowNull()]
        [System.Diagnostics.Process] $Process
    )

    # $null is returned by Start-OracleService when Oracle was already running.
    # In that case this is a deliberate no-op -- do not stop a shared instance.
    if ($null -eq $Process) { return }

    if (-not $Process.HasExited) {
        $Process | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Verbose "Oracle service stopped (PID $($Process.Id))."
    }
}


function Stop-OracleServiceOnPort {
    <#
    .SYNOPSIS
        Stop the Jinja2 Oracle Service by port number.

    .DESCRIPTION
        Finds the process listening on the given TCP port and terminates it.
        Use this when you do not have a Process object reference -- for example
        in the ZZ_OracleTeardown.Tests.ps1 fixture, which runs in a different
        scope than the file that originally started Oracle.

        Falls back gracefully if no process is found on that port.

    .PARAMETER Port
        The TCP port to look up. Default: 5000.

    .EXAMPLE
        Stop-OracleServiceOnPort        # stops whatever is on :5000
        Stop-OracleServiceOnPort -Port 8080
    #>
    [CmdletBinding()]
    param(
        [int] $Port = 5000
    )

    # Get-NetTCPConnection is available on Windows PowerShell 5.1+ and PS 7+.
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
            Select-Object -First 1

    if ($null -eq $conn) {
        Write-Verbose "Stop-OracleServiceOnPort: nothing listening on port $Port."
        return
    }

    $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
    if ($null -ne $proc) {
        Write-Verbose "Stop-OracleServiceOnPort: stopping PID $($proc.Id) ($($proc.Name)) on port $Port."
        $proc | Stop-Process -Force -ErrorAction SilentlyContinue
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
        bool - $true if ready within timeout, $false otherwise.

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
    $null = Invoke-OracleHttp -Uri $url -Method GET
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
        POST /render - render a single Jinja2 template.

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
        When specified, do not throw on oracle errors - return the full
        response object instead (useful for testing error paths).

    .OUTPUTS
        string - rendered output, or PSCustomObject when -AllowError is used.

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

    $response = Invoke-OracleHttp `
        -Uri    "$OracleUrl/render" `
        -Method POST `
        -Body   ($body | ConvertTo-Json -Depth 20)

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
        POST /batch - render multiple templates in a single request.

    .DESCRIPTION
        Accepts an array of request hashtables (same structure as /render)
        and returns an array of response objects.

    .PARAMETER Requests
        Array of hashtables, each with keys: template, context, undefined_mode, request_id.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .OUTPUTS
        Object[] - array of oracle response objects.

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

    # ConvertTo-Json -AsArray is PS 6+ only; wrapping ensures array serialisation on PS 5.1.
    $jsonArray = if ($Requests.Count -eq 1) {
        '[' + ($Requests | ConvertTo-Json -Depth 20) + ']'
    } else {
        $Requests | ConvertTo-Json -Depth 20
    }

    $response = Invoke-OracleHttp `
        -Uri    "$OracleUrl/batch" `
        -Method POST `
        -Body   $jsonArray

    return $response
}


function Invoke-OracleParse {
    <#
    .SYNOPSIS
        POST /parse - parse a template and return its Jinja2 AST.

    .PARAMETER Template
        Jinja2 template string.

    .PARAMETER RequestId
        Optional correlation identifier.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .OUTPUTS
        PSCustomObject - oracle response with .ast property.

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

    return Invoke-OracleHttp `
        -Uri    "$OracleUrl/parse" `
        -Method POST `
        -Body   ($body | ConvertTo-Json -Depth 20)
}


function Invoke-OracleValidate {
    <#
    .SYNOPSIS
        POST /validate - validate template syntax without rendering.

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

    $response = Invoke-OracleHttp `
        -Uri    "$OracleUrl/validate" `
        -Method POST `
        -Body   ($body | ConvertTo-Json -Depth 20)

    if ($PassThru) { return $response }
    return [bool]$response.success
}

# ---------------------------------------------------------------------------
# Informational endpoints
# ---------------------------------------------------------------------------

function Get-OracleEnvironment {
    <#
    .SYNOPSIS
        GET /environment - retrieve Jinja2 environment configuration.

    .DESCRIPTION
        Returns the full environment object including Jinja2 version,
        Python version, all available filters and tests.

        Recommended: call this once in BeforeAll and write to a log file
        to record the oracle configuration for the test run.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .OUTPUTS
        PSCustomObject - oracle environment response.

    .EXAMPLE
        $env = Get-OracleEnvironment
        Write-Host "Jinja2 $($env.version) / Python $($env.python_version)"
    #>
    [CmdletBinding()]
    param(
        [string] $OracleUrl = $script:OracleBaseUrl
    )

    return Invoke-OracleHttp -Uri "$OracleUrl/environment" -Method GET
}


function Get-OracleCapabilities {
    <#
    .SYNOPSIS
        GET /capabilities - retrieve the list of oracle capabilities.

    .PARAMETER OracleUrl
        Base URL of the oracle service. Default: http://localhost:5000.

    .OUTPUTS
        PSCustomObject - capabilities response.

    .EXAMPLE
        $caps = Get-OracleCapabilities
        $caps.batch | Should -BeTrue
    #>
    [CmdletBinding()]
    param(
        [string] $OracleUrl = $script:OracleBaseUrl
    )

    return Invoke-OracleHttp -Uri "$OracleUrl/capabilities" -Method GET
}
