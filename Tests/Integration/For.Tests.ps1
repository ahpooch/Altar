# Invoke-Pester -Path .\Tests\Integration\For.Tests.ps1 -Output Detailed
BeforeAll {
    . .\Altar.ps1
}

Describe 'For Statement Integration Tests' -Tag 'Integration' {
    
    Context "Basic For Loop Functionality" {
        It "Iterates over simple string array" {
            $template = @"
First line.

{% for item in items -%}
  - {{ item }}
{% endfor -%}

Last line.
"@
            $context = @{
                items = @('apple', 'banana', 'cherry')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  - apple
  - banana
  - cherry

Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Iterates over number array" {
            $template = @"
{% for num in numbers -%}
{{ num }}
{% endfor -%}
"@
            $context = @{
                numbers = @(1, 2, 3, 4, 5)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
1
2
3
4
5
"@
            $result | Should -Be $expected
        }
        
        It "Handles empty array" {
            $template = @"
Start
{% for item in items -%}
  - {{ item }}
{% endfor -%}
End
"@
            $context = @{
                items = @()
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start
End
"@
            $result | Should -Be $expected
        }
        
        It "Iterates over single element array" {
            $template = @"
{% for item in items -%}
Item: {{ item }}
{% endfor -%}
"@
            $context = @{
                items = @('only-one')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Item: only-one"
            $result | Should -Be $expected
        }
    }
    
    Context "Whitespace Trimming" {
        It "Trims whitespace on the left with {%-" {
            $template = @"
Line 1
    {%- for item in items -%}
{{ item }}
{% endfor -%}
Line 2
"@
            $context = @{
                items = @('A', 'B')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # {%- removes ALL whitespace BEFORE the tag, including newline and leading spaces
            # So "Line 1\n    " gets trimmed to "Line 1", then loop content follows
            $expected = @"
Line 1A
B
Line 2
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on the right with -%}" {
            $template = @"
Start
{% for item in items -%}
{{ item }}
{% endfor -%}
    End
"@
            $context = @{
                items = @('X', 'Y')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start
X
Y
    End
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on both sides" {
            $template = @"
Before
    {%- for item in items -%}
{{ item }}
{%- endfor -%}
After
"@
            $context = @{
                items = @('1', '2')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # {%- removes whitespace before, -%} removes whitespace after
            # This creates a compact output with all items on same line
            $expected = "Before12After"
            $result | Should -Be $expected
        }
        
        It "Preserves content whitespace without trim markers" {
            $template = @"
Start
{% for item in items %}
  {{ item }}
{% endfor %}
End
"@
            $context = @{
                items = @('A', 'B')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start

  A

  B

End
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Else Branch" {
        It "Executes else branch when array is empty" {
            $template = @"
{% for item in items -%}
  - {{ item }}
{% else -%}
No items found.
{% endfor -%}
"@
            $context = @{
                items = @()
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "No items found."
            $result | Should -Be $expected
        }
        
        It "Does not execute else branch when array has items" {
            $template = @"
{% for item in items -%}
  - {{ item }}
{% else -%}
No items found.
{% endfor -%}
"@
            $context = @{
                items = @('apple', 'banana')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
  - apple
  - banana
"@
            $result | Should -Be $expected
        }
        
        It "Handles else branch with whitespace trimming" {
            $template = @"
List:
{%- for item in items -%}
{{ item }}
{%- else -%}
    Empty list
{%- endfor -%}
Done
"@
            $context = @{
                items = @()
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # {%- removes newline before, -%} removes newline after
            # So everything gets compacted
            $expected = "List:    Empty listDone"
            $result | Should -Be $expected
        }
    }
    
    Context "Nested Loops" {
        It "Handles nested for loops" {
            $template = @"
{% for row in matrix -%}
Row:
{% for cell in row -%}
  {{ cell }}
{% endfor -%}
{% endfor -%}
"@
            $context = @{
                matrix = @(
                    @('A1', 'A2'),
                    @('B1', 'B2')
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Row:
  A1
  A2
Row:
  B1
  B2
"@
            $result | Should -Be $expected
        }
        
        It "Handles triple nested loops" {
            $template = @"
{% for i in outer -%}
{% for j in middle -%}
{% for k in inner -%}
{{ i }}-{{ j }}-{{ k }}
{% endfor -%}
{% endfor -%}
{% endfor -%}
"@
            $context = @{
                outer = @(1, 2)
                middle = @('A', 'B')
                inner = @('x', 'y')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
1-A-x
1-A-y
1-B-x
1-B-y
2-A-x
2-A-y
2-B-x
2-B-y
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Integration with Other Constructs" {
        It "Combines for loop with if statement" {
            $template = @"
{% for num in numbers -%}
{% if num > 5 -%}
Big: {{ num }}
{% else -%}
Small: {{ num }}
{% endif -%}
{% endfor -%}
"@
            $context = @{
                numbers = @(3, 7, 2, 9)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Small: 3
Big: 7
Small: 2
Big: 9
"@
            $result | Should -Be $expected
        }
        
        It "Uses filters inside for loop" {
            $template = @"
{% for name in names -%}
{{ name | upper }}
{% endfor -%}
"@
            $context = @{
                names = @('alice', 'bob', 'charlie')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
ALICE
BOB
CHARLIE
"@
            $result | Should -Be $expected
        }
        
        It "Combines multiple filters in for loop" {
            $template = @"
{% for text in items -%}
{{ text | trim | upper }}
{% endfor -%}
"@
            $context = @{
                items = @('  hello  ', '  world  ')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
HELLO
WORLD
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Object Iteration" {
        It "Iterates over array of hashtables with property access" {
            $template = @"
{% for user in users -%}
Name: {{ user.name }}, Age: {{ user.age }}
{% endfor -%}
"@
            $context = @{
                users = @(
                    @{ name = 'Alice'; age = 30 },
                    @{ name = 'Bob'; age = 25 }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Name: Alice, Age: 30
Name: Bob, Age: 25
"@
            $result | Should -Be $expected
        }
        
        It "Iterates over array of PSCustomObjects" {
            $template = @"
{% for product in products -%}
{{ product.name }}: `${{ product.price }}
{% endfor -%}
"@
            
            $products = @(
                [PSCustomObject]@{ name = 'Apple'; price = 1.50 },
                [PSCustomObject]@{ name = 'Banana'; price = 0.75 }
            )
            
            $context = @{
                products = $products
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Use culture-independent comparison (decimal separator may vary)
            $result | Should -Match "Apple: \`$1[.,]5"
            $result | Should -Match "Banana: \`$0[.,]75"
        }
    }
    
    Context "Edge Cases" {
        It "Handles array with null values" {
            $template = @"
{% for item in items -%}
[{{ item }}]
{% endfor -%}
"@
            $context = @{
                items = @('A', $null, 'B', $null, 'C')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
[A]
[]
[B]
[]
[C]
"@
            $result | Should -Be $expected
        }
        
        It "Handles array with empty strings" {
            $template = @"
{% for item in items -%}
Item: "{{ item }}"
{% endfor -%}
"@
            $context = @{
                items = @('first', '', 'third')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Item: "first"
Item: ""
Item: "third"
"@
            $result | Should -Be $expected
        }
        
        It "Handles special characters in array elements" {
            $template = @"
{% for item in items -%}
{{ item }}
{% endfor -%}
"@
            $context = @{
                items = @('<html>', 'a&b', 'x"y', "a'b")
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
<html>
a&b
x"y
a'b
"@
            $result | Should -Be $expected
        }
        
        It "Handles large array efficiently" {
            $template = @"
{% for num in numbers -%}
{{ num }}
{% endfor -%}
"@
            $largeArray = 1..100
            $context = @{
                numbers = $largeArray
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Verify first and last elements (platform-independent line endings)
            $result | Should -Match "^1\r?\n"
            $result | Should -Match "100$"
            
            # Verify content includes all numbers
            $result | Should -Match "50"
            $result | Should -Match "99"
        }
        
        It "Handles array with mixed types" {
            $template = @"
{% for item in items -%}
{{ item }}
{% endfor -%}
"@
            $context = @{
                items = @(1, 'text', 3.14, $true, $false)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Use culture-independent comparison for decimal separator
            $result | Should -Match "^1\r?\n"
            $result | Should -Match "text"
            $result | Should -Match "3[.,]14"
            $result | Should -Match "True"
            $result | Should -Match "False"
        }
    }
    
    Context "Loop Variable" {
        It "Provides loop.index (1-based counter)" {
            $template = @"
{% for item in items -%}
{{ loop.index }}
{% endfor -%}
"@
            $context = @{
                items = @('A', 'B', 'C')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
1
2
3
"@
            $result | Should -Be $expected
        }
        
        It "Provides loop.index0 (0-based counter)" {
            $template = @"
{% for item in items -%}
{{ loop.index0 }}
{% endfor -%}
"@
            $context = @{
                items = @('A', 'B', 'C')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
0
1
2
"@
            $result | Should -Be $expected
        }
        
        It "Provides loop.first flag" {
            $template = @"
{% for item in items -%}
{% if loop.first -%}
FIRST: {{ item }}
{% else -%}
{{ item }}
{% endif -%}
{% endfor -%}
"@
            $context = @{
                items = @('A', 'B', 'C')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
FIRST: A
B
C
"@
            $result | Should -Be $expected
        }
        
        It "Provides loop.last flag" {
            $template = @"
{% for item in items -%}
{% if loop.last -%}
LAST: {{ item }}
{% else -%}
{{ item }}
{% endif -%}
{% endfor -%}
"@
            $context = @{
                items = @('A', 'B', 'C')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
A
B
LAST: C
"@
            $result | Should -Be $expected
        }
        
        It "Provides loop.length" {
            $template = @"
{% for item in items -%}
{{ loop.index }}/{{ loop.length }}: {{ item }}
{% endfor -%}
"@
            $context = @{
                items = @('A', 'B', 'C')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
1/3: A
2/3: B
3/3: C
"@
            $result | Should -Be $expected
        }
        
        It "Combines all loop variables" {
            $template = @"
{% for item in items -%}
{{ loop.index }}. {{ item }} (index0: {{ loop.index0 }}, first: {{ loop.first }}, last: {{ loop.last }}, length: {{ loop.length }})
{% endfor -%}
"@
            $context = @{
                items = @('apple', 'banana', 'cherry')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
1. apple (index0: 0, first: True, last: False, length: 3)
2. banana (index0: 1, first: False, last: False, length: 3)
3. cherry (index0: 2, first: False, last: True, length: 3)
"@
            $result | Should -Be $expected
        }
        
        It "Works with single item array" {
            $template = @"
{% for item in items -%}
{{ loop.index }}/{{ loop.length }}: {{ item }} (first: {{ loop.first }}, last: {{ loop.last }})
{% endfor -%}
"@
            $context = @{
                items = @('only-one')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "1/1: only-one (first: True, last: True)"
            $result | Should -Be $expected
        }
    }
    
    Context "Error Handling" {
        It "Throws error when endfor is missing" {
            $template = @"
{% for item in items -%}
{{ item }}
"@
            $context = @{
                items = @('A', 'B')
            }
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            } | Should -Throw
        }
        
        It "Throws error when 'in' keyword is missing" {
            $template = @"
{% for item items -%}
{{ item }}
{% endfor -%}
"@
            $context = @{
                items = @('A', 'B')
            }
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            } | Should -Throw
        }
        
        It "Handles iteration over non-array gracefully" {
            $template = @"
{% for item in notAnArray -%}
{{ item }}
{% endfor -%}
"@
            $context = @{
                notAnArray = "single string"
            }
            
            # PowerShell treats single values as arrays with one element
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "single string"
        }
    }
    
    Context "Real-world Scenarios" {
        It "Generates HTML list from array" {
            $template = @"
<ul>
{% for item in items -%}
  <li>{{ item }}</li>
{% endfor -%}
</ul>
"@
            $context = @{
                items = @('Home', 'About', 'Contact')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
<ul>
  <li>Home</li>
  <li>About</li>
  <li>Contact</li>
</ul>
"@
            $result | Should -Be $expected
        }
        
        It "Generates table rows from data" {
            $template = @"
<table>
{% for row in data -%}
  <tr>
    <td>{{ row.id }}</td>
    <td>{{ row.name }}</td>
  </tr>
{% endfor -%}
</table>
"@
            $context = @{
                data = @(
                    @{ id = 1; name = 'Alice' },
                    @{ id = 2; name = 'Bob' }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
<table>
  <tr>
    <td>1</td>
    <td>Alice</td>
  </tr>
  <tr>
    <td>2</td>
    <td>Bob</td>
  </tr>
</table>
"@
            $result | Should -Be $expected
        }
        
        It "Generates markdown list with else fallback" {
            $template = @"
# Items

{% for item in items -%}
- {{ item }}
{% else -%}
*No items to display*
{% endfor -%}
"@
            $context = @{
                items = @()
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
# Items

*No items to display*
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Scoped Modifier (Jinja2 Compatibility)" {
        It "Accepts 'scoped' modifier without errors" {
            $template = @"
{% for item in items -%}
<li>{% block loop_item scoped %}{{ item }}{% endblock %}</li>
{% endfor -%}
"@
            $context = @{ items = @('apple', 'banana', 'cherry') }
            
            { Invoke-AltarTemplate -Template $template -Context $context } | Should -Not -Throw
        }

        It "Renders correctly with 'scoped' modifier" {
            $template = @"
{% for item in items -%}
<li>{% block loop_item scoped %}{{ item }}{% endblock %}</li>
{% endfor -%}
"@
            $context = @{ items = @('apple', 'banana', 'cherry') }
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match '<li>apple</li>'
            $result | Should -Match '<li>banana</li>'
            $result | Should -Match '<li>cherry</li>'
        }

        It "Works the same with or without 'scoped' modifier (Altar behavior)" {
            $templateWithScoped = @"
{% for item in items -%}
<li>{% block loop_item scoped %}{{ item }}{% endblock %}</li>
{% endfor -%}
"@
            $templateWithoutScoped = @"
{% for item in items -%}
<li>{% block loop_item %}{{ item }}{% endblock %}</li>
{% endfor -%}
"@
            $context = @{ items = @('apple', 'banana', 'cherry') }
            
            $resultWith = Invoke-AltarTemplate -Template $templateWithScoped -Context $context
            $resultWithout = Invoke-AltarTemplate -Template $templateWithoutScoped -Context $context
            
            # Both should produce the same output in Altar
            $resultWith.Trim() | Should -Be $resultWithout.Trim()
        }
        
        It "Works with nested loops and scoped modifier" {
            $template = @"
{% for category in categories -%}
<div>
  <h2>{{ category.name }}</h2>
  <ul>
  {% for item in category.items -%}
    <li>{% block item_display scoped %}{{ item }}{% endblock %}</li>
  {% endfor -%}
  </ul>
</div>
{% endfor -%}
"@
            $context = @{
                categories = @(
                    @{ name = "Fruits"; items = @("apple", "banana") },
                    @{ name = "Vegetables"; items = @("carrot", "potato") }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match '<h2>Fruits</h2>'
            $result | Should -Match '<li>apple</li>'
            $result | Should -Match '<h2>Vegetables</h2>'
            $result | Should -Match '<li>carrot</li>'
        }

        It "Works with loop variable access in scoped blocks" {
            $template = @"
{% for item in items -%}
{% block item_block scoped -%}
Item {{ loop.index }}: {{ item }}
{% endblock -%}
{% endfor -%}
"@
            $context = @{ items = @('first', 'second', 'third') }
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match 'Item 1: first'
            $result | Should -Match 'Item 2: second'
            $result | Should -Match 'Item 3: third'
        }

        It "Works with filters inside scoped blocks" {
            $template = @"
{% for item in items -%}
{% block filtered_item scoped %}{{ item | upper }}{% endblock %}
{% endfor -%}
"@
            $context = @{ items = @('apple', 'banana') }
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match 'APPLE'
            $result | Should -Match 'BANANA'
        }

        It "Works with conditionals inside scoped blocks" {
            $template = @"
{% for item in items -%}
{% block conditional_item scoped -%}
{% if item == 'special' -%}
Special: {{ item }}
{% else -%}
Regular: {{ item }}
{% endif -%}
{% endblock -%}
{% endfor -%}
"@
            $context = @{ items = @('normal', 'special', 'normal') }
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match 'Regular: normal'
            $result | Should -Match 'Special: special'
        }
        
        It "Parses Jinja2 templates with scoped modifier" {
            # This is a typical Jinja2 pattern that should now work in Altar
            $template = @"
<ul>
{% for item in navigation -%}
    <li>{% block nav_item scoped %}<a href="{{ item.href }}">{{ item.caption }}</a>{% endblock %}</li>
{% endfor -%}
</ul>
"@
            $context = @{
                navigation = @(
                    @{ href = "/home"; caption = "Home" },
                    @{ href = "/about"; caption = "About" }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match '<a href="/home">Home</a>'
            $result | Should -Match '<a href="/about">About</a>'
        }
    }
}
