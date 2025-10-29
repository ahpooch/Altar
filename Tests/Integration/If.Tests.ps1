# Invoke-Pester -Path .\Tests\Integration\If.Tests.ps1 -Output Detailed
BeforeAll {
    . .\Altar.ps1
}

Describe 'If Statement Integration Tests' -Tag 'Integration' {
    
    Context "Basic If Statement Functionality" {
        It "Executes if block when condition is true" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% endif -%}
  
Last line.
"@
            $context = @{
                fact = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  fact is true
  
Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Skips if block when condition is false" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% endif -%}
  
Last line.
"@
            $context = @{
                fact = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  
Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Handles if with variable comparison" {
            $template = @"
{% if count > 5 -%}
Large count
{% endif -%}
"@
            $context = @{
                count = 10
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Large count"
            $result | Should -Be $expected
        }
        
        It "Handles if with string comparison" {
            $template = @"
{% if name == "Alice" -%}
Hello Alice!
{% endif -%}
"@
            $context = @{
                name = "Alice"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Hello Alice!"
            $result | Should -Be $expected
        }
    }
    
    Context "If-Else Statement" {
        It "Executes if block when condition is true" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% else -%}
  fact is false
{% endif -%}

Last line.
"@
            $context = @{
                fact = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  fact is true

Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Executes else block when condition is false" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% else -%}
  fact is false
{% endif -%}

Last line.
"@
            $context = @{
                fact = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  fact is false

Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Handles if-else with numeric comparison" {
            $template = @"
{% if score >= 60 -%}
Pass
{% else -%}
Fail
{% endif -%}
"@
            $context = @{
                score = 75
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Pass"
            $result | Should -Be $expected
        }
    }
    
    Context "If-Elif Statement" {
        It "Executes if block when first condition is true" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% elif fact2 -%}
  fact2 is true
{% elif fact3 -%}
  fact3 is true
{% endif -%}

Last line.
"@
            $context = @{
                fact = $true
                fact2 = $false
                fact3 = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  fact is true

Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Executes first elif block when if is false and elif is true" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% elif fact2 -%}
  fact2 is true
{% elif fact3 -%}
  fact3 is true
{% endif -%}

Last line.
"@
            $context = @{
                fact = $false
                fact2 = $true
                fact3 = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  fact2 is true

Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Executes second elif block when previous conditions are false" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% elif fact2 -%}
  fact2 is true
{% elif fact3 -%}
  fact3 is true
{% endif -%}

Last line.
"@
            $context = @{
                fact = $false
                fact2 = $false
                fact3 = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  fact3 is true

Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Skips all blocks when all conditions are false" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% elif fact2 -%}
  fact2 is true
{% elif fact3 -%}
  fact3 is true
{% endif -%}

Last line.
"@
            $context = @{
                fact = $false
                fact2 = $false
                fact3 = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.


Last line.
"@
            $result | Should -Be $expected
        }
    }
    
    Context "If-Elif-Else Statement" {
        It "Executes if block when first condition is true" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% elif fact2 -%}
  fact2 is true
{% elif fact3 -%}
  fact3 is true
{% else -%}
  all facts are false
{% endif -%}

Last line.
"@
            $context = @{
                fact = $true
                fact2 = $false
                fact3 = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  fact is true

Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Executes first elif block when if is false and elif is true" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% elif fact2 -%}
  fact2 is true
{% elif fact3 -%}
  fact3 is true
{% else -%}
  all facts are false
{% endif -%}

Last line.
"@
            $context = @{
                fact = $false
                fact2 = $true
                fact3 = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  fact2 is true

Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Executes second elif block when previous conditions are false" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% elif fact2 -%}
  fact2 is true
{% elif fact3 -%}
  fact3 is true
{% else -%}
  all facts are false
{% endif -%}

Last line.
"@
            $context = @{
                fact = $false
                fact2 = $false
                fact3 = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  fact3 is true

Last line.
"@
            $result | Should -Be $expected
        }
        
        It "Executes else block when all conditions are false" {
            $template = @"
First line.

{% if fact -%}
  fact is true
{% elif fact2 -%}
  fact2 is true
{% elif fact3 -%}
  fact3 is true
{% else -%}
  all facts are false
{% endif -%}

Last line.
"@
            $context = @{
                fact = $false
                fact2 = $false
                fact3 = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line.

  all facts are false

Last line.
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Whitespace Trimming" {
        It "Trims whitespace on the left with {%-" {
            $template = @"
Line 1
    {%- if fact -%}
Content
{% endif -%}
Line 2
"@
            $context = @{
                fact = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # {%- removes ALL whitespace BEFORE the tag, including newline and leading spaces
            $expected = @"
Line 1Content
Line 2
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on the right with -%}" {
            $template = @"
Start
{% if fact -%}
Content
{% endif -%}
    End
"@
            $context = @{
                fact = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start
Content
    End
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on both sides" {
            $template = @"
Before
    {%- if fact -%}
Content
{%- endif -%}
After
"@
            $context = @{
                fact = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # {%- removes whitespace before, -%} removes whitespace after
            # This creates compact output
            $expected = "BeforeContentAfter"
            $result | Should -Be $expected
        }
        
        It "Preserves content whitespace without trim markers" {
            $template = @"
Start
{% if fact %}
  Content
{% endif %}
End
"@
            $context = @{
                fact = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start

  Content

End
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Nested If Statements" {
        It "Handles nested if statements" {
            $template = @"
{% if outer -%}
Outer is true
{% if inner -%}
Inner is also true
{% endif -%}
{% endif -%}
"@
            $context = @{
                outer = $true
                inner = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Outer is true
Inner is also true
"@
            $result | Should -Be $expected
        }
        
        It "Handles nested if-else statements" {
            $template = @"
{% if outer -%}
{% if inner -%}
Both true
{% else -%}
Outer true, inner false
{% endif -%}
{% else -%}
Outer false
{% endif -%}
"@
            $context = @{
                outer = $true
                inner = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Outer true, inner false
"@
            $result | Should -Be $expected
        }
        
        It "Handles triple nested if statements" {
            $template = @"
{% if level1 -%}
L1
{% if level2 -%}
L2
{% if level3 -%}
L3
{% endif -%}
{% endif -%}
{% endif -%}
"@
            $context = @{
                level1 = $true
                level2 = $true
                level3 = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
L1
L2
L3
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Integration with Other Constructs" {
        It "Combines if statement with for loop" {
            $template = @"
{% for item in items -%}
{% if item > 5 -%}
Big: {{ item }}
{% else -%}
Small: {{ item }}
{% endif -%}
{% endfor -%}
"@
            $context = @{
                items = @(3, 7, 2, 9)
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
        
        It "Uses filters inside if statement" {
            $template = @"
{% if name -%}
{{ name | upper }}
{% endif -%}
"@
            $context = @{
                name = "alice"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "ALICE"
            $result | Should -Be $expected
        }
        
        It "Combines if with variable interpolation" {
            $template = @"
{% if user.active -%}
Welcome, {{ user.name }}!
{% else -%}
Account inactive for {{ user.name }}
{% endif -%}
"@
            $context = @{
                user = @{
                    name = "Bob"
                    active = $true
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Welcome, Bob!"
            $result | Should -Be $expected
        }
    }
    
    Context "Complex Conditions" {
        It "Handles logical AND conditions" {
            $template = @"
{% if a and b -%}
Both true
{% endif -%}
"@
            $context = @{
                a = $true
                b = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Both true"
            $result | Should -Be $expected
        }
        
        It "Handles logical OR conditions" {
            $template = @"
{% if a or b -%}
At least one true
{% endif -%}
"@
            $context = @{
                a = $false
                b = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "At least one true"
            $result | Should -Be $expected
        }
        
        It "Handles negation with comparison" {
            $template = @"
{% if flag == false -%}
Flag is false
{% endif -%}
"@
            $context = @{
                flag = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Flag is false"
            $result | Should -Be $expected
        }
        
        It "Handles inequality operators" {
            $template = @"
{% if value != 0 -%}
Non-zero
{% endif -%}
"@
            $context = @{
                value = 5
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Non-zero"
            $result | Should -Be $expected
        }
    }
    
    Context "Edge Cases" {
        It "Handles null values in conditions" {
            $template = @"
{% if value -%}
Has value
{% else -%}
No value
{% endif -%}
"@
            $context = @{
                value = $null
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "No value"
            $result | Should -Be $expected
        }
        
        It "Handles empty string in conditions" {
            $template = @"
{% if text -%}
Has text
{% else -%}
Empty
{% endif -%}
"@
            $context = @{
                text = ""
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Empty"
            $result | Should -Be $expected
        }
        
        It "Handles zero in numeric conditions" {
            $template = @"
{% if count -%}
Non-zero
{% else -%}
Zero
{% endif -%}
"@
            $context = @{
                count = 0
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Zero"
            $result | Should -Be $expected
        }
        
        It "Handles undefined variables gracefully" {
            $template = @"
{% if undefined_var -%}
Defined
{% else -%}
Undefined
{% endif -%}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Undefined"
            $result | Should -Be $expected
        }
    }
    
    Context "Error Handling" {
        It "Throws error when endif is missing" {
            $template = @"
{% if fact -%}
Content
"@
            $context = @{
                fact = $true
            }
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            } | Should -Throw
        }
        
        It "Throws error when condition is missing" {
            $template = @"
{% if -%}
Content
{% endif -%}
"@
            $context = @{}
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            } | Should -Throw
        }
        
        It "Throws error when else appears before elif" {
            $template = @"
{% if fact -%}
A
{% else -%}
B
{% elif fact2 -%}
C
{% endif -%}
"@
            $context = @{
                fact = $false
                fact2 = $true
            }
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            } | Should -Throw
        }
    }
    
    Context "Real-world Scenarios" {
        It "Generates conditional HTML content" {
            $template = @"
<div>
{% if user.is_admin -%}
  <button>Admin Panel</button>
{% endif -%}
{% if user.is_logged_in -%}
  <a href="/logout">Logout</a>
{% else -%}
  <a href="/login">Login</a>
{% endif -%}
</div>
"@
            $context = @{
                user = @{
                    is_admin = $true
                    is_logged_in = $true
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
<div>
  <button>Admin Panel</button>
  <a href="/logout">Logout</a>
</div>
"@
            $result | Should -Be $expected
        }
        
        It "Generates status messages based on conditions" {
            $template = @"
{% if status == "success" -%}
✓ Operation completed successfully
{% elif status == "warning" -%}
⚠ Operation completed with warnings
{% elif status == "error" -%}
✗ Operation failed
{% else -%}
? Unknown status
{% endif -%}
"@
            $context = @{
                status = "warning"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "⚠ Operation completed with warnings"
            $result | Should -Be $expected
        }
        
        It "Generates conditional markdown content" {
            $template = @"
# Report

{% if data.has_errors -%}
## Errors
{{ data.error_count }} errors found.
{% endif -%}

{% if data.has_warnings -%}
## Warnings
{{ data.warning_count }} warnings found.
{% endif -%}

{% if data.all_clear -%}
All checks passed! ✓
{% endif -%}
"@
            $context = @{
                data = @{
                    has_errors = $false
                    has_warnings = $false
                    error_count = 0
                    warning_count = 0
                    all_clear = $true
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "All checks passed!"
        }
    }
}
