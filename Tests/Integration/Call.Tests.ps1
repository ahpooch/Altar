# Integration tests for Call block functionality
BeforeAll {
    # Load the Altar template engine
    . "$PSScriptRoot\..\..\Altar.ps1"
}

Describe "Call Block Tests" {
    
    Context "Basic Call Block" {
        It "Should render call block with caller()" {
            $template = @'
{% macro render_dialog(title, class='dialog') -%}
    <div class="{{ class }}">
        <h2>{{ title }}</h2>
        <div class="contents">
            {{ caller() }}
        </div>
    </div>
{%- endmacro %}

{% call render_dialog('Hello World') %}
    This is a simple dialog.
{% endcall %}
'@
            
            $context = @{}
            $engine = [TemplateEngine]::new()
            $result = $engine.Render($template, $context)
            
            $result | Should -Match '<div class="dialog">'
            $result | Should -Match '<h2>Hello World</h2>'
            $result | Should -Match 'This is a simple dialog\.'
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
        }
        
        It "Should handle multiple parameters in caller()" {
            $template = @'
{% macro render_table(items) -%}
    <table>
    {% for item in items -%}
        <tr>{{ caller(item.name, item.value) }}</tr>
    {% endfor -%}
    </table>
{% endmacro -%}

{% call(name, value) render_table(data) %}
    <td>{{ name }}</td><td>{{ value }}</td>
{% endcall %}
'@
            
            $context = @{
                data = @(
                    @{ name = 'Item 1'; value = 100 }
                    @{ name = 'Item 2'; value = 200 }
                )
            }
            
            $engine = [TemplateEngine]::new()
            $result = $engine.Render($template, $context)
            
            $result | Should -Match '<table>'
            $result | Should -Match '<tr>.*<td>Item 1</td><td>100</td>.*</tr>'
            $result | Should -Match '<tr>.*<td>Item 2</td><td>200</td>.*</tr>'
            $result | Should -Match '</table>'
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
            
            $context = @{
                names = @('alice', 'bob', 'charlie')
            }
            
            $engine = [TemplateEngine]::new()
            $result = $engine.Render($template, $context)
            
            $result | Should -Match '<li>.*ALICE.*</li>'
            $result | Should -Match '<li>.*BOB.*</li>'
            $result | Should -Match '<li>.*CHARLIE.*</li>'
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
            
            $context = @{
                list = @('A', 'B', 'C')
            }
            
            $engine = [TemplateEngine]::new()
            $result = $engine.Render($template, $context)
            
            $result | Should -Match '<div class="outer">'
            $result | Should -Match '<span>.*Item.*: A</span>'
            $result | Should -Match '<span>.*Item.*: B</span>'
            $result | Should -Match '<span>.*Item.*: C</span>'
        }
    }
}
