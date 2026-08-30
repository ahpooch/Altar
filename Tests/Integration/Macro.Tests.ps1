# Macro Tests for Macro functionality — enhanced with Jinja2 Oracle validation
BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
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
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
}

Describe "Macro Tests" -Tag 'Integration' {
    
    Context "Basic Macro Definition and Call" {
        It "Should define and call a simple macro" {
            $template = @"
{%- macro greeting(name) -%}
Hello, {{ name }}!
{%- endmacro -%}

{{ greeting('World') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Hello, World!"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should call macro multiple times" {
            $template = @"
{% macro item(text) %}<li>{{ text }}</li>{% endmacro %}
<ul>
{{ item('First') }}
{{ item('Second') }}
{{ item('Third') }}
</ul>
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Match '<li>First</li>'
            $result | Should -Match '<li>Second</li>'
            $result | Should -Match '<li>Third</li>'
        }
    }
    
    Context "Macro with Multiple Parameters" {
        It "Should handle multiple positional parameters" {
            $template = @"
{%- macro user_info(name, age, city) -%}
Name: {{ name }}, Age: {{ age }}, City: {{ city }}
{%- endmacro -%}

{{ user_info('Alice', 30, 'New York') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Name: Alice, Age: 30, City: New York"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
    
    Context "Macro with Default Parameters" {
        It "Should use default parameter values" {
            $template = @"
{%- macro greeting(name, salutation='Hello') -%}
{{ salutation }}, {{ name }}!
{%- endmacro -%}

{{ greeting('World') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Hello, World!"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should override default parameter values" {
            $template = @"
{%- macro greeting(name, salutation='Hello') -%}
{{ salutation }}, {{ name }}!
{%- endmacro -%}

{{ greeting('World', 'Hi') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Hi, World!"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
    
    Context "Macro with Named Arguments" {
        It "Should handle named arguments" {
            $template = @"
{%- macro user_info(name, age, city) -%}
Name: {{ name }}, Age: {{ age }}, City: {{ city }}
{%- endmacro -%}

{{ user_info(city='Tokyo', name='Bob', age=25) }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Name: Bob, Age: 25, City: Tokyo"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should mix positional and named arguments" {
            $template = @"
{%- macro user_info(name, age, city) -%}
Name: {{ name }}, Age: {{ age }}, City: {{ city }}
{%- endmacro -%}

{{ user_info('Charlie', city='London', age=35) }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Name: Charlie, Age: 35, City: London"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
    
    Context "Macro with Template Logic" {
        It "Should support if statements in macro" {
            $template = @"
{% macro status(active) %}
{% if active %}
Active
{% else %}
Inactive
{% endif %}
{% endmacro %}

Status: {{ status(true) }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Match 'Status:\s+Active'
        }
        
        It "Should support for loops in macro" {
            $template = @"
{% macro list_items(items) %}
<ul>
{% for item in items %}
<li>{{ item }}</li>
{% endfor %}
</ul>
{% endmacro %}

{{ list_items(['Apple', 'Banana', 'Cherry']) }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Match '<li>Apple</li>'
            $result | Should -Match '<li>Banana</li>'
            $result | Should -Match '<li>Cherry</li>'
        }
    }
    
    Context "Macro with Filters" {
        It "Should apply filters to macro output" {
            $template = @"
{%- macro shout(text) -%}
{{ text }}
{%- endmacro -%}

{{ shout('hello world') | upper }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "HELLO WORLD"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should use filters inside macro" {
            $template = @"
{%- macro format_name(name) -%}
{{ name | upper }}
{%- endmacro -%}

{{ format_name('alice') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "ALICE"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
    
    Context "Nested Macros" {
        It "Should call macro from within another macro" {
            $template = @"
{%- macro inner(text) -%}
[{{ text }}]
{%- endmacro -%}

{%- macro outer(text) -%}
Outer: {{ inner(text) }}
{%- endmacro -%}

{{ outer('test') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Outer: [test]"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
    
    Context "Macro with Context Variables" {
        It "Should access context variables from macro" {
            $template = @"
{%- macro show_user() -%}
User: {{ username }}
{%- endmacro -%}

{{ show_user() }}
"@
            $context = @{
                username = 'JohnDoe'
            }
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "User: JohnDoe"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
}
