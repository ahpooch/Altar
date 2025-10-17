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
            
            $expected = @"
Line 1
A
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
            
            $expected = @"
Before
1
2
After
"@
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
            
            $expected = @"
List:
    Empty list
Done
"@
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
}
