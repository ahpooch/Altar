# Invoke-Pester -Path .\Tests\Integration\Raw.Tests.ps1 -Output Detailed
BeforeAll {
    . .\Altar.ps1
}

Describe 'Raw Block Integration Tests' -Tag 'Integration' {
    
    Context "Basic Raw Block Functionality" {
        It "Preserves content inside raw block without processing" {
            $template = @"
First line.

{% raw %}
This section will not be processed by Altar.
You can include {{ variables }} or {% for loops %} here,
and they will be displayed as literal text.
{% endraw %}

Last line.
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.


This section will not be processed by Altar.
You can include {{ variables }} or {% for loops %} here,
and they will be displayed as literal text.


Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Preserves variable syntax inside raw block" {
            $template = @"
{% raw %}
{{ variable }}
{{ another.variable }}
{{ object.property }}
{% endraw %}
"@
            $context = @{
                variable = "value"
                another = @{ variable = "test" }
                object = @{ property = "data" }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

{{ variable }}
{{ another.variable }}
{{ object.property }}
"@
            $result | Should -Be $expected
        }
        
        It "Preserves statement syntax inside raw block" {
            $template = @"
{% raw %}
{% if condition %}
{% for item in items %}
{% endif %}
{% endfor %}
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

{% if condition %}
{% for item in items %}
{% endif %}
{% endfor %}
"@
            $result | Should -Be $expected
        }
        
        It "Preserves comment syntax inside raw block" {
            $template = @"
{% raw %}
{# This is a comment #}
{#- Another comment -#}
{#
Multi-line comment
-#}
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

{# This is a comment #}
{#- Another comment -#}
{#
Multi-line comment
-#}
"@
            $result | Should -Be $expected
        }
        
        It "Handles raw block at the beginning of template" {
            $template = @"
{% raw %}
Raw content at start
{{ variable }}
{% endraw %}
Normal content
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

Raw content at start
{{ variable }}

Normal content
"@
            $result | Should -Be $expected
        }
        
        It "Handles raw block at the end of template" {
            $template = @"
Normal content
{% raw %}
Raw content at end
{{ variable }}
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Normal content

Raw content at end
{{ variable }}
"@
            $result | Should -Be $expected
        }
        
        It "Handles empty raw block" {
            $template = @"
Before
{% raw %}{% endraw %}
After
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Before

After
"@
            $result | Should -Be $expected
        }
        
        It "Handles raw block with only whitespace" {
            $template = @"
Before
{% raw %}   {% endraw %}
After
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Before
   
After
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Whitespace Trimming with Raw Blocks" {
        It "Trims whitespace on the left with {%-" {
            $template = @"
Line 1
    {%- raw %}
Raw content
{% endraw %}
Line 2
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Line 1

Raw content

Line 2
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on the right with -%}" {
            $template = @"
Line 1
{% raw -%}
Raw content
{% endraw %}
    Line 2
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Line 1
Raw content

    Line 2
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on both sides of opening tag" {
            $template = @"
Before
    {%- raw -%}
Raw content
{% endraw %}
After
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Before
Raw content

After
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on the left of closing tag" {
            $template = @"
Start
{% raw %}
Raw content
    {%- endraw %}
End
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start

Raw content
    
End
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on the right of closing tag" {
            $template = @"
Start
{% raw %}
Raw content
{% endraw -%}
    End
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start

Raw content
    End
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on both sides of closing tag" {
            $template = @"
Start
{% raw %}
Raw content
    {%- endraw -%}
End
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start

Raw content
    End
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on all tags" {
            $template = @"
Before
    {%- raw -%}
Raw content
    {%- endraw -%}
After
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Before
Raw content
    After
"@
            $result | Should -Be $expected
        }
        
        It "Preserves whitespace without trim markers" {
            $template = @"
Start
    {% raw %}
    Raw content
    {% endraw %}
End
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start
    
    Raw content
    
End
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Multiple Raw Blocks" {
        It "Handles multiple raw blocks in sequence" {
            $template = @"
First
{% raw %}
Raw 1: {{ var }}
{% endraw %}
Middle
{% raw %}
Raw 2: {% if %}
{% endraw %}
Last
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First

Raw 1: {{ var }}

Middle

Raw 2: {% if %}

Last
"@
            $result | Should -Be $expected
        }
        
        It "Handles raw blocks separated by processed content" {
            $template = @"
{% raw %}
{{ unprocessed }}
{% endraw %}
{{ processed }}
{% raw %}
{{ also_unprocessed }}
{% endraw %}
"@
            $context = @{
                processed = "PROCESSED"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

{{ unprocessed }}

PROCESSED

{{ also_unprocessed }}
"@
            $result | Should -Be $expected
        }
        
        It "Handles three consecutive raw blocks" {
            $template = @"
{% raw %}Block 1{% endraw %}
{% raw %}Block 2{% endraw %}
{% raw %}Block 3{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Block 1
Block 2
Block 3
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Raw Blocks with Other Constructs" {
        It "Processes content before raw block" {
            $template = @"
{{ greeting }}
{% raw %}
{{ unprocessed }}
{% endraw %}
"@
            $context = @{
                greeting = "Hello"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Hello

{{ unprocessed }}
"@
            $result | Should -Be $expected
        }
        
        It "Processes content after raw block" {
            $template = @"
{% raw %}
{{ unprocessed }}
{% endraw %}
{{ farewell }}
"@
            $context = @{
                farewell = "Goodbye"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

{{ unprocessed }}

Goodbye
"@
            $result | Should -Be $expected
        }
        
        It "Handles raw block between if statements" {
            $template = @"
{% if show_first -%}
First
{% endif -%}
{% raw %}
{{ raw_content }}
{% endraw %}
{% if show_last -%}
Last
{% endif -%}
"@
            $context = @{
                show_first = $true
                show_last = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First

{{ raw_content }}

Last
"@
            $result | Should -Be $expected
        }
        
        It "Handles raw block between for loops" {
            $template = @"
{% for i in first -%}
{{ i }}
{% endfor -%}
{% raw %}
{% for item in items %}
{% endraw %}
{% for j in second -%}
{{ j }}
{% endfor -%}
"@
            $context = @{
                first = @(1, 2)
                second = @(3, 4)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
1
2

{% for item in items %}

3
4
"@
            $result | Should -Be $expected
        }
        
        It "Handles raw block with comments outside" {
            $template = @"
{# Comment before -#}
{% raw %}
{# This comment is preserved #}
{% endraw %}
{# Comment after -#}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

{# This comment is preserved #}
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Raw Block Content Preservation" {
        It "Preserves special characters" {
            $template = @"
{% raw %}
Special chars: @#$%^&*()[]{}|<>?/\~`!-+=_;:'"
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

Special chars: @#$%^&*()[]{}|<>?/\~`!-+=_;:'"
"@
            $result | Should -Be $expected
        }
        
        It "Preserves numbers and operators" {
            $template = @"
{% raw %}
Math: 1 + 2 = 3
Comparison: x > 5 && y < 10
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

Math: 1 + 2 = 3
Comparison: x > 5 && y < 10
"@
            $result | Should -Be $expected
        }
        
        It "Preserves indentation inside raw block" {
            $template = @"
{% raw %}
    Indented line 1
        More indented line 2
    Back to first indent
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

    Indented line 1
        More indented line 2
    Back to first indent
"@
            $result | Should -Be $expected
        }
        
        It "Preserves empty lines inside raw block" {
            $template = @"
{% raw %}
Line 1

Line 3 (line 2 was empty)


Line 6 (lines 4-5 were empty)
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

Line 1

Line 3 (line 2 was empty)


Line 6 (lines 4-5 were empty)
"@
            $result | Should -Be $expected
        }
        
        It "Preserves mixed Altar syntax" {
            $template = @"
{% raw %}
Variables: {{ var1 }}, {{ var2.prop }}
Statements: {% if x %}, {% for i in list %}
Comments: {# comment #}, {#- trimmed -#}
Filters: {{ value | upper | trim }}
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

Variables: {{ var1 }}, {{ var2.prop }}
Statements: {% if x %}, {% for i in list %}
Comments: {# comment #}, {#- trimmed -#}
Filters: {{ value | upper | trim }}
"@
            $result | Should -Be $expected
        }
        
        It "Preserves HTML/XML tags" {
            $template = @"
{% raw %}
<div class="{{ dynamic_class }}">
  <p>{{ content }}</p>
  {% if show_button %}
  <button>Click</button>
  {% endif %}
</div>
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

<div class="{{ dynamic_class }}">
  <p>{{ content }}</p>
  {% if show_button %}
  <button>Click</button>
  {% endif %}
</div>
"@
            $result | Should -Be $expected
        }
        
        It "Preserves code snippets" {
            $template = @"
{% raw %}
function example() {
  const x = {{ variable }};
  if ({% condition %}) {
    return x;
  }
}
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

function example() {
  const x = {{ variable }};
  if ({% condition %}) {
    return x;
  }
}
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Edge Cases" {
        It "Handles raw block on single line" {
            $template = "Before {% raw %}{{ var }}{% endraw %} After"
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Before {{ var }} After"
            $result | Should -Be $expected
        }
        
        It "Handles multiple raw blocks on same line" {
            $template = "{% raw %}{{ a }}{% endraw %} middle {% raw %}{{ b }}{% endraw %}"
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "{{ a }} middle {{ b }}"
            $result | Should -Be $expected
        }
        
        It "Handles raw block with only newlines" {
            $template = @"
Start
{% raw %}

{% endraw %}
End
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start



End
"@
            $result | Should -Be $expected
        }
        
        It "Handles raw block containing endraw-like text" {
            $template = @"
{% raw %}
This text mentions {% endraw %} but it's just text
The actual end is below
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Note: This tests how the parser handles endraw-like text inside raw blocks
            # The exact behavior depends on parser implementation
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Handles very long raw block content" {
            $longContent = @"
Line 1
Line 2
Line 3
Line 4
Line 5
Line 6
Line 7
Line 8
Line 9
Line 10
"@
            $template = @"
{% raw %}
$longContent
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "Line 1"
            $result | Should -Match "Line 10"
        }
    }
    
    Context "Real-world Scenarios" {
        It "Documents template syntax in documentation" {
            $template = @"
# Template Documentation

## Variable Syntax
{% raw %}
Use {{ variable_name }} to insert variables.
Example: {{ user.name }}
{% endraw %}

## Control Flow
{% raw %}
Use {% if condition %} for conditionals.
Use {% for item in list %} for loops.
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "Use \{\{ variable_name \}\} to insert variables"
            $result | Should -Match "Use \{% if condition %\} for conditionals"
        }
        
        It "Shows code examples in tutorial" {
            $template = @"
To display a user's name, use:
{% raw %}
{{ user.name }}
{% endraw %}

To loop through items:
{% raw %}
{% for item in items %}
  {{ item }}
{% endfor %}
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "\{\{ user\.name \}\}"
            $result | Should -Match "\{% for item in items %\}"
        }
        
        It "Preserves template code in blog post" {
            $template = @"
<article>
  <h1>{{ post.title }}</h1>
  <p>Here's how to use templates:</p>
  <pre><code>
{% raw %}
{% if user.is_admin %}
  <button>Admin Panel</button>
{% endif %}
{% endraw %}
  </code></pre>
</article>
"@
            $context = @{
                post = @{
                    title = "Template Tutorial"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "Template Tutorial"
            $result | Should -Match "\{% if user\.is_admin %\}"
        }
        
        It "Shows configuration examples" {
            $template = @"
Configuration file example:
{% raw %}
{
  "api_url": "{{ config.api_url }}",
  "timeout": {{ config.timeout }},
  "enabled": {% if config.enabled %}true{% else %}false{% endif %}
}
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match '"api_url": "\{\{ config\.api_url \}\}"'
            $result | Should -Match '"timeout": \{\{ config\.timeout \}\}'
        }
        
        It "Displays template syntax in error messages" {
            $template = @"
Error: Invalid syntax detected.

Expected:
{% raw %}
{% if condition %}
  content
{% endif %}
{% endraw %}

Found:
{% raw %}
{% if condition %}
  content
{# missing endif #}
{% endraw %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "Expected:"
            $result | Should -Match "Found:"
            $result | Should -Match "\{% endif %\}"
        }
        
        It "Creates template cheat sheet" {
            $template = @"
# Altar Template Cheat Sheet

## Variables
{% raw %}{{ variable }}{% endraw %} - Simple variable
{% raw %}{{ object.property }}{% endraw %} - Object property

## Filters
{% raw %}{{ text | upper }}{% endraw %} - Uppercase filter
{% raw %}{{ text | lower | trim }}{% endraw %} - Chained filters

## Control Flow
{% raw %}{% if condition %}...{% endif %}{% endraw %} - Conditional
{% raw %}{% for item in list %}...{% endfor %}{% endraw %} - Loop

## Comments
{% raw %}{# comment #}{% endraw %} - Single line
{% raw %}{# multi-line
comment #}{% endraw %} - Multi-line
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "Altar Template Cheat Sheet"
            $result | Should -Match "\{\{ variable \}\}"
            $result | Should -Match "\{% if condition %\}"
        }
    }
    
    Context "Error Handling" {
        It "Throws error when endraw is missing" {
            $template = @"
{% raw %}
Content without closing tag
"@
            $context = @{}
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            } | Should -Throw
        }
        
        It "Handles malformed raw tag gracefully" {
            $template = @"
{% raw
Missing closing bracket
{% endraw %}
"@
            $context = @{}
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            } | Should -Throw
        }
        
        It "Handles malformed endraw tag gracefully" {
            $template = @"
{% raw %}
Content
{% endraw
Missing closing bracket
"@
            $context = @{}
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            } | Should -Throw
        }
    }
}
