# Integration tests for Call block 'in' operator — enhanced with Jinja2 Oracle validation

BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
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
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
}

Describe "Call Block Tests" -Tag 'Integration' {

    Context "Basic Call Block" {
        It "Should render call block with caller()" {
            $template = @"
{%- macro render_dialog(title, class='dialog') -%}
    <div class="{{ class }}">
        <h2>{{ title }}</h2>
        <div class="contents">{{ caller() }}</div>
    </div>
{%- endmacro -%}

{% call render_dialog('Hello World') %}
    This is a simple dialog.
{% endcall %}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expect = @"
<div class="dialog">
        <h2>Hello World</h2>
        <div class="contents">
    This is a simple dialog.
</div>
    </div>
"@
            
            $result | Should -Be $expect
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It "Should render call block with custom class parameter" {
            $template = @'
{% macro render_box(title, type='info') -%}
    <div class="box box-{{ type }}">
        <h3>{{ title }}</h3>
        {{ caller() }}
    </div>
{%- endmacro %}

{% call render_box('Notice', type='warning') %}
    <p>Important message!</p>
{% endcall %}
'@
            $context = @{}
            $engine = [TemplateEngine]::new()
            $result = $engine.Render($template, $context)

            $result | Should -Match '<div class="box box-warning">'
            $result | Should -Match '<h3>Notice</h3>'
            $result | Should -Match '<p>Important message!</p>'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Call Block with Parameters" {
        It "Should pass parameters to caller()" {
            $template = @'
{% macro dump_users(users) -%}
    <ul>
    {%- for user in users %}
        <li>{{ caller(user) }}</li>
    {%- endfor %}
    </ul>
{%- endmacro %}

{% call(user) dump_users(list_of_users) %}
    <p>{{ user.username }}: {{ user.realname }}</p>
{% endcall %}
'@
            $context = @{
                list_of_users = @(
                    @{ username = 'john'; realname = 'John Doe' }
                    @{ username = 'jane'; realname = 'Jane Smith' }
                )
            }
            $engine = [TemplateEngine]::new()
            $result = $engine.Render($template, $context)

            $result | Should -Match '<ul>'
            $result | Should -Match 'john: John Doe'
            $result | Should -Match 'jane: Jane Smith'
            $result | Should -Match '</ul>'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Call Block with Filters" {
        It "Should apply filters in caller block" {
            $template = @'
{% macro render_list(items) -%}
    <ul>
    {% for item in items %}
        <li>{{ caller(item) }}</li>
    {% endfor %}
    </ul>
{% endmacro %}

{% call(item) render_list(names) %}
    {{ item | upper }}
{% endcall %}
'@
            $context = @{ names = @('alice', 'bob', 'charlie') }
            $engine = [TemplateEngine]::new()
            $result = $engine.Render($template, $context)

            $result | Should -Match '(?s)<li>.*ALICE.*</li>'
            $result | Should -Match '(?s)<li>.*BOB.*</li>'
            $result | Should -Match '(?s)<li>.*CHARLIE.*</li>'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Call Block with Conditionals" {
        It "Should handle conditionals in caller block" {
            $template = @'
{% macro render_items(items) -%}
    <div>
    {%- for item in items %}
        {{ caller(item) }}
    {%- endfor %}
    </div>
{%- endmacro %}

{% call(item) render_items(products) %}
    {% if item.available %}
        <p>{{ item.name }}: In Stock</p>
    {% else %}
        <p>{{ item.name }}: Out of Stock</p>
    {% endif %}
{% endcall %}
'@
            $context = @{
                products = @(
                    @{ name = 'Product A'; available = $true }
                    @{ name = 'Product B'; available = $false }
                )
            }
            $engine = [TemplateEngine]::new()
            $result = $engine.Render($template, $context)

            $result | Should -Match 'Product A: In Stock'
            $result | Should -Match 'Product B: Out of Stock'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Nested Call Blocks" {
        It "Should handle nested call blocks" {
            $template = @'
{% macro outer(items) -%}
    <div class="outer">
        {%- for item in items %}
            {{ caller(item) }}
        {%- endfor %}
    </div>
{%- endmacro %}

{% macro inner(text) -%}
    <span>{{ caller() }}: {{ text }}</span>
{%- endmacro %}

{% call(item) outer(list) %}
    {% call inner(item) %}
        Item
    {% endcall %}
{% endcall %}
'@
            $context = @{ list = @('A', 'B', 'C') }
            $engine = [TemplateEngine]::new()
            $result = $engine.Render($template, $context)

            $result | Should -Match '<div class="outer">'
            $result | Should -Match '(?s)<span>.*Item.*: A</span>'
            $result | Should -Match '(?s)<span>.*Item.*: B</span>'
            $result | Should -Match '(?s)<span>.*Item.*: C</span>'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
}
