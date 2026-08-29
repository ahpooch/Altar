# Oracle self-tests — verify that the Jinja2 Oracle service itself returns
# spec-compliant outputs grounded in the official Jinja2 documentation.
#
# These tests have NO dependency on Altar.ps1. They test the oracle only.
# If the oracle is misconfigured (wrong Jinja2 version, broken app.py, wrong
# environment settings) every Confirm-MatchesOracle call in the Integration
# suite would silently use a bad reference. These tests catch that first.
#
# Run:
#   Invoke-Pester -Path .\Tests\Oracle\ -Output Detailed
#   Invoke-Pester -Path .\Tests\ -Tag 'Oracle' -Output Detailed

BeforeAll {
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
        $oraEnv = Get-OracleEnvironment
        Write-Host "  [Oracle] Jinja2 $($oraEnv.version) / Python $($oraEnv.python_version)" -ForegroundColor DarkGray
    } catch {
        Write-Warning "Oracle unavailable — all Oracle self-tests will be skipped.`n  Run: pwsh oracle/setup.ps1 -Start"
    }
}

AfterAll {
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
}

Describe 'Oracle Service Self-Tests' -Tag 'Oracle' {

    # Skip every It block in this Describe when the oracle is not running.
    BeforeEach {
        if (-not $script:OracleAvailable) {
            Set-ItResult -Skipped -Because 'Oracle service is not running — run: pwsh oracle/setup.ps1 -Start'
        }
    }

    # -------------------------------------------------------------------------
    Context 'Infrastructure' {

        It '/health returns status "ok"' {
            $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:5000/health' -Method Get -ErrorAction Stop
            $resp.status | Should -Be 'ok'
        }

        It '/health returns a Jinja2 version string' {
            $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:5000/health' -Method Get -ErrorAction Stop
            # Jinja2 semver — e.g. "3.1.4"
            $resp.version | Should -Match '^\d+\.\d+'
        }

        It 'Test-OracleReady returns $true on port 5000' {
            Test-OracleReady -Port 5000 -TimeoutSeconds 5 | Should -BeTrue
        }
    }

    # -------------------------------------------------------------------------
    Context 'GET /environment' {

        BeforeAll {
            if ($script:OracleAvailable) {
                $script:Env = Get-OracleEnvironment
            }
        }

        It 'version field is present and matches semver' {
            $script:Env.version | Should -Match '^\d+\.\d+'
        }

        It 'autoescape is $false by default — Jinja2 docs §environment' {
            # Jinja2 Environment(autoescape=False) is the default non-HTML mode
            $script:Env.environment.autoescape | Should -BeFalse
        }

        It 'trim_blocks is $false by default — Jinja2 docs §environment' {
            $script:Env.environment.trim_blocks | Should -BeFalse
        }

        It 'lstrip_blocks is $false by default — Jinja2 docs §environment' {
            $script:Env.environment.lstrip_blocks | Should -BeFalse
        }

        It 'filters list contains the core Jinja2 built-in filters' {
            # Per https://jinja.palletsprojects.com/en/stable/templates/#builtin-filters
            $required = @('upper','lower','capitalize','title','trim','replace',
                          'join','length','sort','abs','int','float','round',
                          'escape','reverse','unique','sum','min','max','first',
                          'last','default','tojson','safe','string','list')
            foreach ($f in $required) {
                $script:Env.filters | Should -Contain $f -Because "Jinja2 ships '$f' as a built-in filter"
            }
        }

        It 'tests list contains the core Jinja2 built-in tests' {
            # Per https://jinja.palletsprojects.com/en/stable/templates/#builtin-tests
            $required = @('defined','none','odd','even','string','number',
                          'callable','iterable','mapping','sequence')
            foreach ($t in $required) {
                $script:Env.tests | Should -Contain $t -Because "Jinja2 ships '$t' as a built-in test"
            }
        }
    }

    # -------------------------------------------------------------------------
    Context 'GET /capabilities' {

        BeforeAll {
            if ($script:OracleAvailable) {
                $script:Caps = Get-OracleCapabilities
            }
        }

        It 'render capability is true' {
            $script:Caps.render | Should -BeTrue
        }

        It 'batch capability is true' {
            $script:Caps.batch | Should -BeTrue
        }

        It 'parse capability is true' {
            $script:Caps.parse | Should -BeTrue
        }

        It 'validate capability is true' {
            $script:Caps.validate | Should -BeTrue
        }
    }

    # -------------------------------------------------------------------------
    Context 'POST /render — Variables' {

        It 'empty template returns empty string' {
            # OracleClient validates [Parameter(Mandatory)] and rejects empty strings at the PS level,
            # so we call the HTTP endpoint directly — appropriate for an oracle self-test.
            $body = @{ template = ''; context = @{}; undefined_mode = 'default' } | ConvertTo-Json -Depth 5
            $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:5000/render' `
                                      -Method      Post `
                                      -ContentType 'application/json' `
                                      -Body        $body `
                                      -ErrorAction Stop
            $resp.success | Should -BeTrue
            $resp.output  | Should -Be ''
        }

        It 'plain text passes through unchanged' {
            $out = Invoke-OracleRender -Template 'Hello, World!' -UndefinedMode 'default'
            $out | Should -Be 'Hello, World!'
        }

        It '{{ name }} substitutes a single variable' {
            # Jinja2 docs §variables: {{ variable_name }}
            $out = Invoke-OracleRender -Template '{{ name }}' `
                                       -Context @{ name = 'Jinja2' } `
                                       -UndefinedMode 'strict'
            $out | Should -Be 'Jinja2'
        }

        It 'multiple variables are each substituted independently' {
            $out = Invoke-OracleRender -Template '{{ a }} + {{ b }} = {{ c }}' `
                                       -Context @{ a = 1; b = 2; c = 3 } `
                                       -UndefinedMode 'strict'
            $out | Should -Be '1 + 2 = 3'
        }
    }

    # -------------------------------------------------------------------------
    Context 'POST /render — String Filters' {

        # Expected values taken directly from the Jinja2 documentation:
        # https://jinja.palletsprojects.com/en/stable/templates/#builtin-filters

        It 'upper converts to uppercase' {
            $out = Invoke-OracleRender -Template "{{ 'hello' | upper }}" -UndefinedMode 'default'
            $out | Should -Be 'HELLO'
        }

        It 'lower converts to lowercase' {
            $out = Invoke-OracleRender -Template "{{ 'WORLD' | lower }}" -UndefinedMode 'default'
            $out | Should -Be 'world'
        }

        It 'capitalize uppercases first char and lowercases the rest' {
            # Jinja2 docs: "Capitalize a value. The first character will be uppercase,
            # all others lowercase."
            $out = Invoke-OracleRender -Template "{{ 'hello world' | capitalize }}" -UndefinedMode 'default'
            $out | Should -Be 'Hello world'
        }

        It 'title applies Title Case to every word' {
            $out = Invoke-OracleRender -Template "{{ 'hello world' | title }}" -UndefinedMode 'default'
            $out | Should -Be 'Hello World'
        }

        It 'trim strips leading and trailing whitespace' {
            $out = Invoke-OracleRender -Template "{{ '  hello  ' | trim }}" -UndefinedMode 'default'
            $out | Should -Be 'hello'
        }

        It 'replace substitutes all occurrences by default' {
            # Jinja2 docs: replace(value, old, new, count=None) — no count means replace all
            $out = Invoke-OracleRender -Template "{{ 'hello' | replace('l', 'r') }}" -UndefinedMode 'default'
            $out | Should -Be 'herro'
        }

        It 'length returns the number of characters in a string' {
            $out = Invoke-OracleRender -Template "{{ 'hello' | length }}" -UndefinedMode 'default'
            $out | Should -Be '5'
        }

        It 'reverse reverses a string' {
            $out = Invoke-OracleRender -Template "{{ 'abc' | reverse }}" -UndefinedMode 'default'
            $out | Should -Be 'cba'
        }

        It 'escape HTML-encodes special characters' {
            # Jinja2 docs: escape converts &, <, >, ", ' to their HTML entity equivalents
            $out = Invoke-OracleRender -Template "{{ 'hello & <world>' | escape }}" -UndefinedMode 'default'
            $out | Should -Be 'hello &amp; &lt;world&gt;'
        }
    }

    # -------------------------------------------------------------------------
    Context 'POST /render — Numeric Filters' {

        It 'abs returns the absolute value of a negative number' {
            # Jinja2 docs: "Return the absolute value of the argument."
            $out = Invoke-OracleRender -Template '{{ -7 | abs }}' -UndefinedMode 'default'
            $out | Should -Be '7'
        }

        It 'int casts a numeric string to an integer' {
            # Jinja2 docs: "Convert the value into an integer."
            $out = Invoke-OracleRender -Template "{{ '42' | int }}" -UndefinedMode 'default'
            $out | Should -Be '42'
        }

        It 'round rounds 4.6 up to 5.0' {
            # Jinja2 round() always returns a float
            $out = Invoke-OracleRender -Template '{{ 4.6 | round }}' -UndefinedMode 'default'
            $out | Should -Be '5.0'
        }

        It 'round rounds 4.4 down to 4.0' {
            $out = Invoke-OracleRender -Template '{{ 4.4 | round }}' -UndefinedMode 'default'
            $out | Should -Be '4.0'
        }
    }

    # -------------------------------------------------------------------------
    Context 'POST /render — List Filters' {

        It 'join concatenates list items with a delimiter' {
            # Jinja2 docs: "Return a string which is the concatenation of the strings in the sequence."
            $out = Invoke-OracleRender -Template "{{ [1, 2, 3] | join(', ') }}" -UndefinedMode 'default'
            $out | Should -Be '1, 2, 3'
        }

        It 'length returns the number of items in a list' {
            $out = Invoke-OracleRender -Template '{{ [1, 2, 3] | length }}' -UndefinedMode 'default'
            $out | Should -Be '3'
        }

        It 'sort returns items in ascending order' {
            $out = Invoke-OracleRender -Template "{{ [3, 1, 2] | sort | join(',') }}" -UndefinedMode 'default'
            $out | Should -Be '1,2,3'
        }

        It 'first returns the first element of a list' {
            $out = Invoke-OracleRender -Template '{{ [1, 2, 3] | first }}' -UndefinedMode 'default'
            $out | Should -Be '1'
        }

        It 'last returns the last element of a list' {
            $out = Invoke-OracleRender -Template '{{ [1, 2, 3] | last }}' -UndefinedMode 'default'
            $out | Should -Be '3'
        }

        It 'sum returns the arithmetic sum of all elements' {
            # Jinja2 docs: "Returns the sum of a sequence of numbers plus the value of the start parameter."
            $out = Invoke-OracleRender -Template '{{ [1, 2, 3] | sum }}' -UndefinedMode 'default'
            $out | Should -Be '6'
        }

        It 'min returns the smallest element' {
            $out = Invoke-OracleRender -Template '{{ [3, 1, 2] | min }}' -UndefinedMode 'default'
            $out | Should -Be '1'
        }

        It 'max returns the largest element' {
            $out = Invoke-OracleRender -Template '{{ [3, 1, 2] | max }}' -UndefinedMode 'default'
            $out | Should -Be '3'
        }

        It 'unique removes duplicate values preserving first-occurrence order' {
            # Jinja2 docs: "Returns a list of unique items from the given iterable."
            $out = Invoke-OracleRender -Template "{{ [1, 2, 2, 3] | unique | join(',') }}" -UndefinedMode 'default'
            $out | Should -Be '1,2,3'
        }

        It 'reverse reverses a list' {
            $out = Invoke-OracleRender -Template "{{ [1, 2, 3] | reverse | join(',') }}" -UndefinedMode 'default'
            $out | Should -Be '3,2,1'
        }
    }

    # -------------------------------------------------------------------------
    Context 'POST /render — Control Flow' {

        It '{% if True %} renders the true branch' {
            $out = Invoke-OracleRender -Template '{% if True %}yes{% endif %}' -UndefinedMode 'default'
            $out | Should -Be 'yes'
        }

        It '{% if False %}…{% else %} renders the else branch' {
            $out = Invoke-OracleRender -Template '{% if False %}yes{% else %}no{% endif %}' -UndefinedMode 'default'
            $out | Should -Be 'no'
        }

        It '{% if %} evaluates a numeric comparison expression' {
            $out = Invoke-OracleRender -Template '{% if 5 > 3 %}big{% else %}small{% endif %}' -UndefinedMode 'default'
            $out | Should -Be 'big'
        }

        It '{% for %} iterates over a list and outputs each element' {
            # Jinja2 docs §for: "Loop over each item in a sequence."
            $out = Invoke-OracleRender -Template '{% for i in [1, 2, 3] %}{{ i }}{% endfor %}' -UndefinedMode 'default'
            $out | Should -Be '123'
        }

        It '{% for %}…{% else %} renders the else branch for an empty list' {
            # Jinja2 docs: "If the sequence is empty or the filtering removed all items,
            # you can render a default block by using else."
            $out = Invoke-OracleRender -Template '{% for i in [] %}x{% else %}empty{% endfor %}' -UndefinedMode 'default'
            $out | Should -Be 'empty'
        }

        It '{% set %} assigns a variable usable in the same scope' {
            # Jinja2 docs §assignments: "{% set name = value %}"
            $out = Invoke-OracleRender -Template '{% set x = 42 %}{{ x }}' -UndefinedMode 'default'
            $out | Should -Be '42'
        }

        It '{# comment #} is not present in the rendered output' {
            # Jinja2 docs: "To comment-out part of a line in a template, use {# ... #}."
            $out = Invoke-OracleRender -Template '{# this is a comment #}hello' -UndefinedMode 'default'
            $out | Should -Be 'hello'
        }
    }

    # -------------------------------------------------------------------------
    Context 'POST /render — Undefined Modes' {

        It 'strict mode — response object carries success=false and exception=UndefinedError' {
            # -AllowError prevents the client from throwing so we can inspect the raw response
            $resp = Invoke-OracleRender -Template '{{ missing }}' `
                                        -UndefinedMode 'strict' `
                                        -AllowError
            $resp.success   | Should -BeFalse  -Because 'accessing an undefined variable in strict mode is an error'
            $resp.exception | Should -Be 'UndefinedError' -Because 'Jinja2 raises UndefinedError for StrictUndefined'
        }

        It 'strict mode — Invoke-OracleRender (without -AllowError) throws a PowerShell exception' {
            # The OracleClient wrapper surfaces oracle errors as PowerShell exceptions
            { Invoke-OracleRender -Template '{{ missing }}' -UndefinedMode 'strict' } | Should -Throw
        }

        It 'default mode — missing variable renders as an empty string' {
            # Jinja2 Undefined (non-strict) silently produces an empty string on output
            $out = Invoke-OracleRender -Template '{{ missing }}' -UndefinedMode 'default'
            $out | Should -Be ''
        }
    }

    # -------------------------------------------------------------------------
    Context 'POST /validate' {

        It 'valid if-block reports success=true' {
            $result = Invoke-OracleValidate -Template '{% if x %}ok{% endif %}' -PassThru
            $result.success | Should -BeTrue
        }

        It 'valid for-loop reports success=true' {
            $result = Invoke-OracleValidate -Template '{% for i in items %}{{ i }}{% endfor %}' -PassThru
            $result.success | Should -BeTrue
        }

        It 'unclosed if-block reports success=false with TemplateSyntaxError' {
            $result = Invoke-OracleValidate -Template '{% if x %}no closing tag' -PassThru
            $result.success   | Should -BeFalse
            $result.exception | Should -Be 'TemplateSyntaxError'
        }

        It 'Invoke-OracleValidate returns $true for a syntactically valid template' {
            Invoke-OracleValidate -Template '{{ x | upper }}' | Should -BeTrue
        }

        It 'Invoke-OracleValidate returns $false for a syntactically invalid template' {
            Invoke-OracleValidate -Template '{% bad_tag_that_does_not_exist %}' | Should -BeFalse
        }
    }

    # -------------------------------------------------------------------------
    Context 'POST /parse' {

        It 'a valid template parses successfully with success=true' {
            $resp = Invoke-OracleParse -Template '{{ greeting }}, World!'
            $resp.success | Should -BeTrue
        }

        It 'the AST root node_type is "Template" — the Jinja2 AST always roots at jinja2.nodes.Template' {
            $resp = Invoke-OracleParse -Template '{{ greeting }}, World!'
            $resp.ast.node_type | Should -Be 'Template'
        }

        It 'an invalid template returns success=false' {
            $resp = Invoke-OracleParse -Template '{% if x %}no end tag'
            $resp.success | Should -BeFalse
        }
    }

    # -------------------------------------------------------------------------
    Context 'POST /batch' {

        It 'returns one result per request in submission order' {
            $requests = @(
                @{ request_id = 'b1'; template = '{{ x }}'; context = @{ x = 'first'  }; undefined_mode = 'strict' },
                @{ request_id = 'b2'; template = '{{ x }}'; context = @{ x = 'second' }; undefined_mode = 'strict' }
            )
            $results = Invoke-OracleBatch -Requests $requests
            $results.Count  | Should -Be 2
            $results[0].output | Should -Be 'first'
            $results[1].output | Should -Be 'second'
        }

        It 'each result echoes back the request_id of its originating request' {
            $requests = @(
                @{ request_id = 'echo-1'; template = 'a'; context = @{}; undefined_mode = 'default' },
                @{ request_id = 'echo-2'; template = 'b'; context = @{}; undefined_mode = 'default' }
            )
            $results = Invoke-OracleBatch -Requests $requests
            $results[0].request_id | Should -Be 'echo-1'
            $results[1].request_id | Should -Be 'echo-2'
        }

        It 'a valid and an invalid request in the same batch are handled independently' {
            $requests = @(
                @{ request_id = 'ok';  template = '{{ x }}';    context = @{ x = 'hello' }; undefined_mode = 'strict' },
                @{ request_id = 'err'; template = '{{ nope }}'; context = @{};              undefined_mode = 'strict' }
            )
            $results = Invoke-OracleBatch -Requests $requests
            $results[0].success | Should -BeTrue  -Because 'first request has all variables provided'
            $results[1].success | Should -BeFalse -Because 'second request references an undefined variable in strict mode'
        }
    }

    # -------------------------------------------------------------------------
    Context 'Request ID echo' {

        It '/render echoes the request_id field unchanged in the response' {
            $resp = Invoke-OracleRender -Template 'hi' `
                                        -UndefinedMode 'default' `
                                        -RequestId 'test-rid-render' `
                                        -AllowError
            $resp.request_id | Should -Be 'test-rid-render'
        }

        It '/validate echoes the request_id field unchanged in the response' {
            $resp = Invoke-OracleValidate -Template '{{ x }}' `
                                          -RequestId 'test-rid-validate' `
                                          -PassThru
            $resp.request_id | Should -Be 'test-rid-validate'
        }
    }
}
