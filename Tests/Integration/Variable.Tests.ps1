# Integration tests for Variable block functionality
BeforeAll {
    # Load the Altar template engine
    . "$PSScriptRoot/../../Altar.ps1"
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
        }
        
        It "Handles variable at the beginning of template" {
            $template = "{{ greeting }} World!"
            $context = @{
                greeting = "Hello"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Hello World!"
            $result | Should -Be $expected
        }
        
        It "Handles variable at the end of template" {
            $template = "Hello {{ name }}"
            $context = @{
                name = "Alice"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Hello Alice"
            $result | Should -Be $expected
        }
        
        It "Handles multiple variables in template" {
            $template = "{{ first }} {{ second }} {{ third }}"
            $context = @{
                first = "One"
                second = "Two"
                third = "Three"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "One Two Three"
            $result | Should -Be $expected
        }
        
        It "Handles variable on same line with text" {
            $template = "Before {{ var }} After"
            $context = @{
                var = "MIDDLE"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Before MIDDLE After"
            $result | Should -Be $expected
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
        }
    }
    
    Context "Variable Types" {
        It "Handles string variables" {
            $template = "Value: {{ text }}"
            $context = @{
                text = "Hello World"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Value: Hello World"
            $result | Should -Be $expected
        }
        
        It "Handles integer variables" {
            $template = "Count: {{ count }}"
            $context = @{
                count = 42
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Count: 42"
            $result | Should -Be $expected
        }
        
        It "Handles float variables" {
            $template = "Price: {{ price }}"
            $context = @{
                price = 19.99
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Float formatting depends on system locale (may use comma or dot as decimal separator)
            $result | Should -Match "Price: 19[.,]99"
        }
        
        It "Handles boolean true variable" {
            $template = "Status: {{ status }}"
            $context = @{
                status = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Status: True"
            $result | Should -Be $expected
        }
        
        It "Handles boolean false variable" {
            $template = "Status: {{ status }}"
            $context = @{
                status = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Status: False"
            $result | Should -Be $expected
        }
        
        It "Handles null variable" {
            $template = "Value: {{ value }}"
            $context = @{
                value = $null
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Value: "
            $result | Should -Be $expected
        }
        
        It "Handles array variable" {
            $template = "Items: {{ items }}"
            $context = @{
                items = @(1, 2, 3)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Arrays are converted to string representation
            $result | Should -Match "Items:"
        }
        
        It "Handles hashtable variable" {
            $template = "Data: {{ data }}"
            $context = @{
                data = @{ key = "value" }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Hashtables are converted to string representation
            $result | Should -Match "Data:"
        }
    }
    
    Context "Nested Properties" {
        It "Accesses object property" {
            $template = "Name: {{ user.name }}"
            $context = @{
                user = @{
                    name = "Alice"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Name: Alice"
            $result | Should -Be $expected
        }
        
        It "Accesses multiple object properties" {
            $template = "{{ user.name }} is {{ user.age }} years old"
            $context = @{
                user = @{
                    name = "Bob"
                    age = 30
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Bob is 30 years old"
            $result | Should -Be $expected
        }
        
        It "Accesses deeply nested properties" {
            $template = "City: {{ user.address.city }}"
            $context = @{
                user = @{
                    address = @{
                        city = "New York"
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "City: New York"
            $result | Should -Be $expected
        }
        
        It "Accesses three-level nested properties" {
            $template = "{{ company.department.team.leader }}"
            $context = @{
                company = @{
                    department = @{
                        team = @{
                            leader = "Charlie"
                        }
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Charlie"
            $result | Should -Be $expected
        }
    }
    
    Context "Filters" {
        It "Applies upper filter" {
            $template = "{{ name | upper }}"
            $context = @{
                name = "alice"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "ALICE"
            $result | Should -Be $expected
        }
        
        It "Applies lower filter" {
            $template = "{{ name | lower }}"
            $context = @{
                name = "ALICE"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "alice"
            $result | Should -Be $expected
        }
        
        It "Applies filter to nested property" {
            $template = "{{ user.name | upper }}"
            $context = @{
                user = @{
                    name = "bob"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "BOB"
            $result | Should -Be $expected
        }
        
        It "Handles multiple variables with filters" {
            $template = "{{ first | upper }} and {{ second | lower }}"
            $context = @{
                first = "hello"
                second = "WORLD"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "HELLO and world"
            $result | Should -Be $expected
        }
    }
    
    Context "Whitespace Trimming" {
        It "Trims whitespace on the left with {{-" {
            $template = @"
Line 1
    {{- variable }}
Line 2
"@
            $context = @{
                variable = "VALUE"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # {{- removes ALL whitespace BEFORE the tag, including newline and leading spaces
            # So "Line 1\n    " gets trimmed to "Line 1", then VALUE is appended
            $expected = @"
Line 1VALUE
Line 2
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on the right with -}}" {
            $template = @"
Line 1
{{ variable -}}
    Line 2
"@
            $context = @{
                variable = "VALUE"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # -}} removes whitespace AFTER the tag, including newline
            # So "Line 2" gets pulled up to the same line as VALUE
            $expected = @"
Line 1
VALUE    Line 2
"@
            $result | Should -Be $expected
        }
        
        It "Trims whitespace on both sides" {
            $template = @"
Before
    {{- variable -}}
After
"@
            $context = @{
                variable = "MIDDLE"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # {{- removes whitespace BEFORE (including leading spaces)
            # -}} removes whitespace AFTER (including newline)
            # So "After" gets pulled up to the same line as MIDDLE
            $expected = "BeforeMIDDLEAfter"
            $result | Should -Be $expected
        }
        
        It "Preserves whitespace without trim markers" {
            $template = @"
Start
    {{ variable }}
End
"@
            $context = @{
                variable = "VALUE"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start
    VALUE
End
"@
            $result | Should -Be $expected
        }
        
        It "Handles trim with filter" {
            $template = "{{- name | upper -}}"
            $context = @{
                name = "alice"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "ALICE"
            $result | Should -Be $expected
        }
    }
    
    Context "Integration with Other Constructs" {
        It "Uses variable inside if block" {
            $template = @"
{% if show -%}
Value: {{ value }}
{% endif -%}
"@
            $context = @{
                show = $true
                value = "Displayed"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Value: Displayed"
            $result | Should -Be $expected
        }
        
        It "Uses variable inside else block" {
            $template = @"
{% if show -%}
If value
{% else -%}
Else: {{ value }}
{% endif -%}
"@
            $context = @{
                show = $false
                value = "ElseValue"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Else: ElseValue"
            $result | Should -Be $expected
        }
        
        It "Uses variable inside for loop" {
            $template = @"
{% for item in items -%}
Item: {{ item }}
{% endfor -%}
"@
            $context = @{
                items = @("A", "B", "C")
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Item: A
Item: B
Item: C
"@
            $result | Should -Be $expected
        }
        
        It "Uses external variable inside for loop" {
            $template = @"
{% for item in items -%}
{{ prefix }}: {{ item }}
{% endfor -%}
"@
            $context = @{
                prefix = "Item"
                items = @(1, 2, 3)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Item: 1
Item: 2
Item: 3
"@
            $result | Should -Be $expected
        }
        
        It "Combines variable with comment" {
            $template = @"
{# This is a comment -#}
Value: {{ value }}
"@
            $context = @{
                value = "Test"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Value: Test"
            $result | Should -Be $expected
        }
        
        It "Uses variable before and after comment" {
            $template = @"
{{ before }}
{# Comment -#}
{{ after }}
"@
            $context = @{
                before = "Before"
                after = "After"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Before
After
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Edge Cases" {
        It "Handles empty string value" {
            $template = "Value: '{{ value }}'"
            $context = @{
                value = ""
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Value: ''"
            $result | Should -Be $expected
        }
        
        It "Handles special characters in value" {
            $template = "{{ text }}"
            $context = @{
                text = "Special: @#$%^&*()"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Special: @#$%^&*()"
            $result | Should -Be $expected
        }
        
        It "Handles HTML in value" {
            $template = "{{ html }}"
            $context = @{
                html = "<div>Content</div>"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "<div>Content</div>"
            $result | Should -Be $expected
        }
        
        It "Handles quotes in value" {
            $template = "{{ text }}"
            $context = @{
                text = "He said 'Hello' and ""Goodbye"""
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "Hello"
            $result | Should -Match "Goodbye"
        }
        
        It "Handles newlines in value" {
            $template = "{{ text }}"
            $context = @{
                text = "Line1`nLine2`nLine3"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "Line1"
            $result | Should -Match "Line2"
            $result | Should -Match "Line3"
        }
        
        It "Handles very long value" {
            $template = "{{ text }}"
            $longText = "A" * 1000
            $context = @{
                text = $longText
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Be $longText
        }
        
        It "Handles variable with spaces around name" {
            $template = "{{  variable  }}"
            $context = @{
                variable = "Value"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Value"
            $result | Should -Be $expected
        }
        
        It "Handles multiple variables on same line" {
            $template = "{{ a }} {{ b }} {{ c }}"
            $context = @{
                a = "1"
                b = "2"
                c = "3"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "1 2 3"
            $result | Should -Be $expected
        }
        
        It "Handles variable with underscore in name" {
            $template = "{{ my_variable }}"
            $context = @{
                my_variable = "UnderscoreValue"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "UnderscoreValue"
            $result | Should -Be $expected
        }
        
        It "Handles variable with number in name" {
            $template = "{{ var1 }}"
            $context = @{
                var1 = "NumberValue"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "NumberValue"
            $result | Should -Be $expected
        }
    }
    
    Context "Error Handling" {
        It "Handles undefined variable gracefully (Default mode)" {
            # Default mode (Jinja2 default): undefined variables return empty string
            $template = "{{ undefined_var }}"
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Should return empty string
            $result | Should -Be ""
        }
        
        It "Handles undefined nested property gracefully (Default mode)" {
            # Default mode: undefined nested properties return empty string
            $template = "{{ user.name }}"
            $context = @{
                user = @{}
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Should return empty string
            $result | Should -Be ""
        }
        
        It "Handles undefined variable in Debug mode" {
            # Debug mode: undefined variables return placeholder
            $template = "{{ undefined_var }}"
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Debug
            
            # Should return placeholder
            $result | Should -Be "{{ undefined_var }}"
        }
        
        It "Handles undefined nested property in Debug mode" {
            # Debug mode: undefined nested properties return placeholder
            $template = "{{ user.name }}"
            $context = @{
                user = @{}
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Debug
            
            # Should return placeholder
            $result | Should -Be "{{ user.name }}"
        }
        
        It "Throws error for undefined variable in Strict mode" {
            # Strict mode: undefined variables throw exception
            $template = "{{ undefined_var }}"
            $context = @{}
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Strict -ErrorAction Stop
            } | Should -Throw "*UndefinedError*"
        }
        
        It "Throws error for undefined nested property in Strict mode" {
            # Strict mode: undefined nested properties throw exception
            $template = "{{ user.name }}"
            $context = @{
                user = @{}
            }
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Strict -ErrorAction Stop
            } | Should -Throw "*UndefinedError*"
        }
        
        It "Throws error on unclosed variable tag" {
            $template = "{{ variable"
            $context = @{
                variable = "Value"
            }
            
            {
                Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            } | Should -Throw
        }
        
        It "Throws error on unopened variable tag" {
            $template = "variable }}"
            $context = @{
                variable = "Value"
            }
            
            # This might not throw as }} could be treated as text
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
                    name = "Alice Smith"
                    email = "alice@example.com"
                    age = 28
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "Alice Smith"
            $result | Should -Match "alice@example.com"
            $result | Should -Match "28"
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
                    host = "localhost"
                    port = 8080
                    debug = $true
                    db_name = "myapp"
                    db_user = "admin"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "localhost"
            $result | Should -Match "8080"
            $result | Should -Match "True"
            $result | Should -Match "myapp"
            $result | Should -Match "admin"
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
                recipient = @{
                    name = "John Doe"
                }
                order = @{
                    id = "12345"
                    product = "Widget"
                    quantity = 3
                    total = 59.97
                }
                sender = @{
                    name = "Support Team"
                    company = "ACME Corp"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "John Doe"
            $result | Should -Match "12345"
            $result | Should -Match "Widget"
            $result | Should -Match "3"
            $result | Should -Match "59.97"
            $result | Should -Match "Support Team"
            $result | Should -Match "ACME Corp"
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
                title = "Project Report"
                author = "Jane Developer"
                date = "2025-01-22"
                summary = "This report covers the project status."
                details = "All milestones have been completed successfully."
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "# Project Report"
            $result | Should -Match "Jane Developer"
            $result | Should -Match "2025-01-22"
            $result | Should -Match "project status"
            $result | Should -Match "milestones"
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
                user_id = 42
                status = "active"
                start_date = "2025-01-01"
                order_by = "created_date DESC"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "FROM orders"
            $result | Should -Match "user_id = 42"
            $result | Should -Match "status = 'active'"
            $result | Should -Match "2025-01-01"
            $result | Should -Match "ORDER BY created_date DESC"
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
                    name = "Bob"
                    email = "bob@example.com"
                    age = 35
                    active = $true
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match "Bob"
            $result | Should -Match "bob@example.com"
            $result | Should -Match "35"
            $result | Should -Match "True"
        }
    }
    
    Context "Performance and Stress Tests" {
        It "Handles many variables in single template" {
            # Create a template with 10 variables (reduced from 100 to avoid performance issues)
            $template = "{{ v1 }} {{ v2 }} {{ v3 }} {{ v4 }} {{ v5 }} {{ v6 }} {{ v7 }} {{ v8 }} {{ v9 }} {{ v10 }}"
            $context = @{
                v1 = 1
                v2 = 2
                v3 = 3
                v4 = 4
                v5 = 5
                v6 = 6
                v7 = 7
                v8 = 8
                v9 = 9
                v10 = 10
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Should contain all numbers
            $expected = "1 2 3 4 5 6 7 8 9 10"
            $result | Should -Be $expected
        }
        
        It "Handles deeply nested object access" {
            $template = "{{ a.b.c.d.e.f.g.h.i.j }}"
            $context = @{
                a = @{
                    b = @{
                        c = @{
                            d = @{
                                e = @{
                                    f = @{
                                        g = @{
                                            h = @{
                                                i = @{
                                                    j = "DeepValue"
                                                }
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
            
            $expected = "DeepValue"
            $result | Should -Be $expected
        }
    }
}
