# Macro Tests for Altar Template Engine
BeforeAll {
    . .\Altar.ps1
}

Describe "Macro Tests" {
    
    Context "Basic Macro Definition and Call" {
        It "Should define and call a simple macro" {
            $template = @"
{% macro greeting(name) %}
Hello, {{ name }}!
{% endmacro %}

{{ greeting('World') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "Hello, World!"
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
{% macro user_info(name, age, city) %}
Name: {{ name }}, Age: {{ age }}, City: {{ city }}
{% endmacro %}

{{ user_info('Alice', 30, 'New York') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "Name: Alice, Age: 30, City: New York"
        }
    }
    
    Context "Macro with Default Parameters" {
        It "Should use default parameter values" {
            $template = @"
{% macro greeting(name, salutation='Hello') %}
{{ salutation }}, {{ name }}!
{% endmacro %}

{{ greeting('World') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "Hello, World!"
        }
        
        It "Should override default parameter values" {
            $template = @"
{% macro greeting(name, salutation='Hello') %}
{{ salutation }}, {{ name }}!
{% endmacro %}

{{ greeting('World', 'Hi') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "Hi, World!"
        }
    }
    
    Context "Macro with Named Arguments" {
        It "Should handle named arguments" {
            $template = @"
{% macro user_info(name, age, city) %}
Name: {{ name }}, Age: {{ age }}, City: {{ city }}
{% endmacro %}

{{ user_info(city='Tokyo', name='Bob', age=25) }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "Name: Bob, Age: 25, City: Tokyo"
        }
        
        It "Should mix positional and named arguments" {
            $template = @"
{% macro user_info(name, age, city) %}
Name: {{ name }}, Age: {{ age }}, City: {{ city }}
{% endmacro %}

{{ user_info('Charlie', city='London', age=35) }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "Name: Charlie, Age: 35, City: London"
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
{% macro shout(text) %}
{{ text }}
{% endmacro %}

{{ shout('hello world') | upper }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "HELLO WORLD"
        }
        
        It "Should use filters inside macro" {
            $template = @"
{% macro format_name(name) %}
{{ name | upper }}
{% endmacro %}

{{ format_name('alice') }}
"@
            $context = @{}
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "ALICE"
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
            $result.Trim() | Should -Be "Outer: [test]"
        }
    }
    
    Context "Macro with Context Variables" {
        It "Should access context variables from macro" {
            $template = @"
{% macro show_user() %}
User: {{ username }}
{% endmacro %}

{{ show_user() }}
"@
            $context = @{
                username = 'JohnDoe'
            }
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "User: JohnDoe"
        }
    }
}
