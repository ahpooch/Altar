# Test Call Block functionality in Altar
. .\Altar.ps1

Write-Host "=== Test 1: Basic Call Block ===" -ForegroundColor Cyan

$template1 = @'
{% macro render_dialog(title, class='dialog') -%}
    <div class="{{ class }}">
        <h2>{{ title }}</h2>
        <div class="contents">
            {{ caller() }}
        </div>
    </div>
{%- endmacro %}

{% call render_dialog('Hello World') %}
    This is a simple dialog rendered by using a macro and
    a call block.
{% endcall %}
'@

$context1 = @{}

try {
    $engine = [TemplateEngine]::new()
    $result1 = $engine.Render($template1, $context1)
    Write-Host "Result:" -ForegroundColor Green
    Write-Host $result1
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}

Write-Host "`n=== Test 2: Call Block with Arguments ===" -ForegroundColor Cyan

$template2 = @'
{% macro dump_users(users) -%}
    <ul>
    {%- for user in users %}
        <li><p>{{ user.username }}</p>{{ caller(user) }}</li>
    {%- endfor %}
    </ul>
{%- endmacro %}

{% call(user) dump_users(list_of_users) %}
    <dl>
        <dt>Realname</dt>
        <dd>{{ user.realname }}</dd>
        <dt>Description</dt>
        <dd>{{ user.description }}</dd>
    </dl>
{% endcall %}
'@

$context2 = @{
    list_of_users = @(
        @{ username = 'john'; realname = 'John Doe'; description = 'Developer' }
        @{ username = 'jane'; realname = 'Jane Smith'; description = 'Designer' }
    )
}

try {
    $engine = [TemplateEngine]::new()
    $result2 = $engine.Render($template2, $context2)
    Write-Host "Result:" -ForegroundColor Green
    Write-Host $result2
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}

Write-Host "`n=== Test 3: Call Block with Custom Class ===" -ForegroundColor Cyan

$template3 = @'
{% macro render_box(title, type='info') -%}
    <div class="box box-{{ type }}">
        <h3>{{ title }}</h3>
        <div class="box-content">
            {{ caller() }}
        </div>
    </div>
{%- endmacro %}

{% call render_box('Important Notice', type='warning') %}
    <p>This is an important message!</p>
    <p>Please read carefully.</p>
{% endcall %}
'@

$context3 = @{}

try {
    $engine = [TemplateEngine]::new()
    $result3 = $engine.Render($template3, $context3)
    Write-Host "Result:" -ForegroundColor Green
    Write-Host $result3
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}
