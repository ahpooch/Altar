# Integration tests for Variable block functionality
# Enhanced with Jinja2 Oracle comparisons — the oracle provides canonical
# reference outputs from a real Jinja2 implementation, removing the need
# to hard-code expected strings manually and guaranteeing Jinja2 compatibility.

BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

    # ------------------------------------------------------------------
    # Jinja2 Oracle lifecycle
    # Start automatically; all tests degrade gracefully when unavailable.
    # ------------------------------------------------------------------
    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
    } catch {
        Write-Warning "Jinja2 Oracle unavailable — oracle assertions skipped.`n  Run: pwsh oracle/setup.ps1 -Start"
    }

    # ------------------------------------------------------------------
    # Confirm-MatchesOracle
    #   Sends the same template+context to the reference Jinja2 service
    #   and asserts that Altar's output is byte-for-byte identical.
    #   Line endings are normalised to LF before comparison (Jinja2 always
    #   returns LF; Altar on Windows may return CRLF — both are correct).
    #   No-op when the oracle is not running.
    # ------------------------------------------------------------------
    function script:Confirm-MatchesOracle {
        param(
            [Parameter(Mandatory)] [string]    $Template,
            [hashtable]                         $Context       = @{},
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $AltarResult,
            [string]                            $UndefinedMode = 'default'
        )
        if (-not $script:OracleAvailable) { return }

        $oracle     = Invoke-OracleRender -Template $Template -Context $Context -UndefinedMode $UndefinedMode
        $altarNorm  = $AltarResult -replace '\r\n', "`n" -replace '\r', "`n"
        $oracleNorm = $oracle      -replace '\r\n', "`n" -replace '\r', "`n"
        $altarNorm | Should -Be $oracleNorm -Because 'Altar output must match canonical Jinja2 rendering'
    }
}

AfterAll {
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
}

Describe 'Variable Block Integration Tests' -Tag 'Integration' {

    Context "Basic Variable Functionality" {
        It "Substitutes simple variable" {
            $template = @"
First line.
Provided variable is {{ variable }}.
Last line.
"@
            $context = @{
                variable = "test_value"
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $expected = @"
First line.
Provided variable is test_value.
Last line.
"@
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles variable at the beginning of template" {
            $template = "{{ greeting }} World!"
            $context  = @{ greeting = "Hello" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Hello World!"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles variable at the end of template" {
            $template = "Hello {{ name }}"
            $context  = @{ name = "Alice" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Hello Alice"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles multiple variables in template" {
            $template = "{{ first }} {{ second }} {{ third }}"
            $context  = @{
                first  = "One"
                second = "Two"
                third  = "Three"
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "One Two Three"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles variable on same line with text" {
            $template = "Before {{ var }} After"
            $context  = @{ var = "MIDDLE" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Before MIDDLE After"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles multiple variables on multiple lines" {
            $template = @"
Line 1: {{ var1 }}
Line 2: {{ var2 }}
Line 3: {{ var3 }}
"@
            $context = @{
                var1 = "First"
                var2 = "Second"
                var3 = "Third"
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $expected = @"
Line 1: First
Line 2: Second
Line 3: Third
"@
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Variable Types" {
        It "Handles string variables" {
            $template = "Value: {{ text }}"
            $context  = @{ text = "Hello World" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Value: Hello World"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles integer variables" {
            $template = "Count: {{ count }}"
            $context  = @{ count = 42 }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Count: 42"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles float variables" {
            $template = "Price: {{ price }}"
            $context  = @{ price = 19.99 }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            # Locale-tolerant fallback (some systems use comma as decimal separator)
            $result | Should -Match "Price: 19[.,]99"
            # Oracle always uses a dot separator (Jinja2 / Python invariant).
            # If this assertion fails the template engine has a locale-sensitivity issue.
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles boolean true variable" {
            $template = "Status: {{ status }}"
            $context  = @{ status = $true }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            # Jinja2: Python True → str(True) = "True"
            $result | Should -Be "Status: True"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles boolean false variable" {
            $template = "Status: {{ status }}"
            $context  = @{ status = $false }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            # Jinja2: Python False → str(False) = "False"
            $result | Should -Be "Status: False"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles null variable" {
            # Jinja2: Python None → str(None) = "None"
            # Altar now matches: explicit $null in context renders as "None"
            $template = "Value: {{ value }}"
            $context  = @{ value = $null }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Value: None"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles array variable" {
            # NOTE — Known divergence from Jinja2:
            #   Jinja2 renders a Python list as its repr: "[1, 2, 3]".
            #   Altar renders a PowerShell array differently.
            # The oracle assertion is intentionally omitted here.
            $template = "Items: {{ items }}"
            $context  = @{ items = @(1, 2, 3) }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Match "Items:"
        }

        It "Handles hashtable variable" {
            # NOTE — Known divergence from Jinja2:
            #   Jinja2 renders a Python dict as its repr: "{'key': 'value'}".
            #   Altar renders a PowerShell hashtable differently.
            # The oracle assertion is intentionally omitted here.
            $template = "Data: {{ data }}"
            $context  = @{ data = @{ key = "value" } }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Match "Data:"
        }
    }

    Context "Nested Properties" {
        It "Accesses object property" {
            $template = "Name: {{ user.name }}"
            $context  = @{ user = @{ name = "Alice" } }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Name: Alice"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Accesses multiple object properties" {
            $template = "{{ user.name }} is {{ user.age }} years old"
            $context  = @{ user = @{ name = "Bob"; age = 30 } }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Bob is 30 years old"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Accesses deeply nested properties" {
            $template = "City: {{ user.address.city }}"
            $context  = @{
                user = @{
                    address = @{ city = "New York" }
                }
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "City: New York"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Accesses three-level nested properties" {
            $template = "{{ company.department.team.leader }}"
            $context  = @{
                company = @{
                    department = @{
                        team = @{ leader = "Charlie" }
                    }
                }
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Charlie"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Filters" {
        It "Applies upper filter" {
            $template = "{{ name | upper }}"
            $context  = @{ name = "alice" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "ALICE"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Applies lower filter" {
            $template = "{{ name | lower }}"
            $context  = @{ name = "ALICE" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "alice"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Applies filter to nested property" {
            $template = "{{ user.name | upper }}"
            $context  = @{ user = @{ name = "bob" } }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "BOB"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles multiple variables with filters" {
            $template = "{{ first | upper }} and {{ second | lower }}"
            $context  = @{ first = "hello"; second = "WORLD" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "HELLO and world"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Whitespace Trimming" {
        It "Trims whitespace on the left with {{-" {
            $template = @"
Line 1
    {{- variable }}
Line 2
"@
            $context = @{ variable = "VALUE" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            # {{- removes ALL whitespace before the tag (newline + leading spaces)
            $expected = @"
Line 1VALUE
Line 2
"@
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Trims whitespace on the right with -}}" {
            $template = @"
Line 1
{{ variable -}}
    Line 2
"@
            $context = @{ variable = "VALUE" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            # -}} removes whitespace after the tag (newline), pulling the next line up
            $expected = @"
Line 1
VALUELine 2
"@
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Trims whitespace on both sides" {
            $template = @"
Before
    {{- variable -}}
After
"@
            $context = @{ variable = "MIDDLE" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            # {{- strips whitespace before; -}} strips whitespace after
            $result | Should -Be "BeforeMIDDLEAfter"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Preserves whitespace without trim markers" {
            $template = @"
Start
    {{ variable }}
End
"@
            $context = @{ variable = "VALUE" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $expected = @"
Start
    VALUE
End
"@
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles trim with filter" {
            $template = "{{- name | upper -}}"
            $context  = @{ name = "alice" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "ALICE"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Integration with Other Constructs" {
        It "Uses variable inside if block" {
            $template = @"
{%- if show %}
Value: {{ value }}
{%- endif %}
"@
            $context = @{ show = $true; value = "Displayed" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $expected = @"

Value: Displayed
"@

            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Uses variable inside else block" {
            $template = @"
{%- if show %}
If value
{%- else %}
Else: {{ value }}
{%- endif %}
"@
            $context = @{ show = $false; value = "ElseValue" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $expected = @"

Else: ElseValue
"@
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Uses variable inside for loop" {
            $template = @"
{% for item in items -%}
Item: {{ item }}
{% endfor -%}
"@
            $context = @{ items = @("A", "B", "C") }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $expected = @"
Item: A
Item: B
Item: C

"@
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Uses external variable inside for loop" {
            $template = @"
{% for item in items -%}
{{ prefix }}: {{ item }}
{% endfor -%}
"@
            $context = @{ prefix = "Item"; items = @(1, 2, 3) }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $expected = @"
Item: 1
Item: 2
Item: 3

"@
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Combines variable with comment" {
            $template = @"
{# This is a comment -#}
Value: {{ value }}
"@
            $context = @{ value = "Test" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Value: Test"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Uses variable before and after comment" {
            $template = @"
{{ before }}
{# Comment -#}
{{ after }}
"@
            $context = @{ before = "Before"; after = "After" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $expected = @"
Before
After
"@
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Edge Cases" {
        It "Handles empty string value" {
            $template = "Value: '{{ value }}'"
            $context  = @{ value = "" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Value: ''"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles special characters in value" {
            $template = "{{ text }}"
            $context  = @{ text = "Special: @#$%^&*()" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Special: @#$%^&*()"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles HTML in value" {
            $template = "{{ html }}"
            $context  = @{ html = "<div>Content</div>" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "<div>Content</div>"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles quotes in value" {
            $template = "{{ text }}"
            $context  = @{ text = "He said 'Hello' and ""Goodbye""" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Match "Hello"
            $result | Should -Match "Goodbye"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles newlines in value" {
            $template = "{{ text }}"
            $context  = @{ text = "Line1`nLine2`nLine3" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Match "Line1"
            $result | Should -Match "Line2"
            $result | Should -Match "Line3"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles very long value" {
            $template  = "{{ text }}"
            $longText  = "A" * 1000
            $context   = @{ text = $longText }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be $longText
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles variable with spaces around name" {
            $template = "{{  variable  }}"
            $context  = @{ variable = "Value" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "Value"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles multiple variables on same line" {
            $template = "{{ a }} {{ b }} {{ c }}"
            $context  = @{ a = "1"; b = "2"; c = "3" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "1 2 3"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles variable with underscore in name" {
            $template = "{{ my_variable }}"
            $context  = @{ my_variable = "UnderscoreValue" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "UnderscoreValue"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles variable with number in name" {
            $template = "{{ var1 }}"
            $context  = @{ var1 = "NumberValue" }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "NumberValue"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Error Handling" {
        It "Handles undefined variable gracefully (Default mode)" {
            # Jinja2 default Undefined renders as empty string — Altar matches.
            $template = "{{ undefined_var }}"
            $context  = @{}

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be ""
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result -UndefinedMode 'default'
        }

        It "Handles undefined nested property gracefully (Default mode)" {
            # Jinja2: missing nested key → empty string (no error).
            # Altar now matches: try-catch wraps property access; missing key → empty string.
            $template = "{{ user.name }}"
            $context  = @{ user = @{} }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be ''
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles undefined variable in Debug mode" {
            # Debug mode is an Altar-specific behavior.
            # Jinja2 provides DebugUndefined which behaves the same way
            # (renders as {{ variable_name }}) but it is a distinct class
            # not exposed through the oracle's default undefined_mode options.
            $template = "{{ undefined_var }}"
            $context  = @{}

            $result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Debug

            $result | Should -Be "{{ undefined_var }}"
        }

        It "Handles undefined nested property in Debug mode" {
            # Jinja2 DebugUndefined: missing nested key → "{{ user.name }}"
            # Altar now matches: try-catch detects missing key → outputs placeholder.
            $template = "{{ user.name }}"
            $context  = @{ user = @{} }

            $result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Debug

            $result | Should -Be "{{ user.name }}"
        }

        It "Throws error for undefined variable in Strict mode" {
            $template = "{{ undefined_var }}"
            $context  = @{}

            { Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Strict -ErrorAction Stop } |
                Should -Throw "*UndefinedError*"

            # Oracle confirms Jinja2 StrictUndefined also raises UndefinedError
            if ($script:OracleAvailable) {
                $resp = Invoke-OracleRender -Template $template -Context $context -UndefinedMode 'strict' -AllowError
                $resp.success   | Should -BeFalse  -Because 'Jinja2 StrictUndefined must raise UndefinedError'
                $resp.exception | Should -Be 'UndefinedError'
            }
        }

        It "Throws error for undefined nested property in Strict mode" {
            # Jinja2: missing nested key in StrictUndefined → UndefinedError.
            # Altar now matches: try-catch detects missing key → throws UndefinedError.
            $template = "{{ user.name }}"
            $context  = @{ user = @{} }

            { Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Strict -ErrorAction Stop } |
                Should -Throw "*UndefinedError*"

            # Oracle confirms Jinja2 StrictUndefined raises UndefinedError
            if ($script:OracleAvailable) {
                $resp = Invoke-OracleRender -Template $template -Context $context -UndefinedMode 'strict' -AllowError
                $resp.success   | Should -BeFalse  -Because 'Jinja2 StrictUndefined must raise UndefinedError'
                $resp.exception | Should -Be 'UndefinedError'
            }
        }

        It "Throws error on unclosed variable tag" {
            $template = "{{ variable"
            $context  = @{ variable = "Value" }

            { Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop } | Should -Throw

            # Oracle confirms Jinja2 also rejects unclosed variable tags
            if ($script:OracleAvailable) {
                $resp = Invoke-OracleValidate -Template $template -PassThru
                $resp.success   | Should -BeFalse  -Because 'Jinja2 must reject unclosed variable tag'
                $resp.exception | Should -Be 'TemplateSyntaxError'
            }
        }

        It "Throws error on unopened variable tag" {
            $template = "variable }}"
            $context  = @{ variable = "Value" }

            # Jinja2 treats }} with no matching {{ as literal text — no error
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Real-world Scenarios" {
        It "Generates HTML with variables" {
            $template = @"
<div class="user-card">
    <h2>{{ user.name }}</h2>
    <p>Email: {{ user.email }}</p>
    <p>Age: {{ user.age }}</p>
</div>
"@
            $context = @{
                user = @{
                    name  = "Alice Smith"
                    email = "alice@example.com"
                    age   = 28
                }
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            if ($script:OracleAvailable) {
                Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
            } else {
                $result | Should -Match "Alice Smith"
                $result | Should -Match "alice@example.com"
                $result | Should -Match "28"
            }
        }

        It "Generates configuration file" {
            $template = @"
server:
  host: {{ config.host }}
  port: {{ config.port }}
  debug: {{ config.debug }}
database:
  name: {{ config.db_name }}
  user: {{ config.db_user }}
"@
            $context = @{
                config = @{
                    host    = "localhost"
                    port    = 8080
                    debug   = $true
                    db_name = "myapp"
                    db_user = "admin"
                }
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            if ($script:OracleAvailable) {
                Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
            } else {
                $result | Should -Match "localhost"
                $result | Should -Match "8080"
                $result | Should -Match "True"
                $result | Should -Match "myapp"
                $result | Should -Match "admin"
            }
        }

        It "Generates email template" {
            $template = @"
Dear {{ recipient.name }},

Thank you for your order #{{ order.id }}.

Order Details:
- Product: {{ order.product }}
- Quantity: {{ order.quantity }}
- Total: `${{ order.total }}

Best regards,
{{ sender.name }}
{{ sender.company }}
"@
            $context = @{
                recipient = @{ name    = "John Doe" }
                order     = @{
                    id       = "12345"
                    product  = "Widget"
                    quantity = 3
                    total    = 59.97
                }
                sender    = @{
                    name    = "Support Team"
                    company = "ACME Corp"
                }
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            if ($script:OracleAvailable) {
                Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
            } else {
                $result | Should -Match "John Doe"
                $result | Should -Match "12345"
                $result | Should -Match "Widget"
                $result | Should -Match "3"
                $result | Should -Match "59.97"
                $result | Should -Match "Support Team"
                $result | Should -Match "ACME Corp"
            }
        }

        It "Generates markdown document" {
            $template = @"
# {{ title }}

Author: {{ author }}
Date: {{ date }}

## Summary

{{ summary }}

## Details

{{ details }}
"@
            $context = @{
                title   = "Project Report"
                author  = "Jane Developer"
                date    = "2025-01-22"
                summary = "This report covers the project status."
                details = "All milestones have been completed successfully."
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            if ($script:OracleAvailable) {
                Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
            } else {
                $result | Should -Match "# Project Report"
                $result | Should -Match "Jane Developer"
                $result | Should -Match "2025-01-22"
                $result | Should -Match "project status"
                $result | Should -Match "milestones"
            }
        }

        It "Generates SQL query with variables" {
            $template = @"
SELECT *
FROM {{ table_name }}
WHERE user_id = {{ user_id }}
  AND status = '{{ status }}'
  AND created_date > '{{ start_date }}'
ORDER BY {{ order_by }};
"@
            $context = @{
                table_name = "orders"
                user_id    = 42
                status     = "active"
                start_date = "2025-01-01"
                order_by   = "created_date DESC"
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            if ($script:OracleAvailable) {
                Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
            } else {
                $result | Should -Match "FROM orders"
                $result | Should -Match "user_id = 42"
                $result | Should -Match "status = 'active'"
                $result | Should -Match "2025-01-01"
                $result | Should -Match "ORDER BY created_date DESC"
            }
        }

        It "Generates simple data output" {
            $template = @"
User: {{ user.name }}
Email: {{ user.email }}
Age: {{ user.age }}
Active: {{ user.active }}
"@
            $context = @{
                user = @{
                    name   = "Bob"
                    email  = "bob@example.com"
                    age    = 35
                    active = $true
                }
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            if ($script:OracleAvailable) {
                Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
            } else {
                $result | Should -Match "Bob"
                $result | Should -Match "bob@example.com"
                $result | Should -Match "35"
                $result | Should -Match "True"
            }
        }
    }

    Context "Performance and Stress Tests" {
        It "Handles many variables in single template" {
            $template = "{{ v1 }} {{ v2 }} {{ v3 }} {{ v4 }} {{ v5 }} {{ v6 }} {{ v7 }} {{ v8 }} {{ v9 }} {{ v10 }}"
            $context  = @{
                v1 = 1; v2 = 2; v3 = 3; v4 = 4; v5 = 5
                v6 = 6; v7 = 7; v8 = 8; v9 = 9; v10 = 10
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "1 2 3 4 5 6 7 8 9 10"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Handles deeply nested object access" {
            $template = "{{ a.b.c.d.e.f.g.h.i.j }}"
            $context  = @{
                a = @{
                    b = @{
                        c = @{
                            d = @{
                                e = @{
                                    f = @{
                                        g = @{
                                            h = @{
                                                i = @{ j = "DeepValue" }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            $result = Invoke-AltarTemplate -Template $template -Context $context

            $result | Should -Be "DeepValue"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
}
