# Invoke-Pester -Path .\Tests\Integration\Ternary.Tests.ps1 -Output Detailed
BeforeAll {
    . .\Altar.ps1
}

Describe 'Ternary Operator Integration Tests' -Tag 'Integration' {
    
    Context "Basic Ternary Operator Functionality" {
        It "Returns true value when condition is true" {
            $template = @"
Result: {{ 'yes' if true else 'no' }}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: yes"
            $result | Should -Be $expected
        }
        
        It "Returns false value when condition is false" {
            $template = @"
Result: {{ 'yes' if false else 'no' }}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: no"
            $result | Should -Be $expected
        }
        
        It "Works with variable in condition" {
            $template = @"
Status: {{ 'Active' if is_active else 'Inactive' }}
"@
            $context = @{
                is_active = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Status: Active"
            $result | Should -Be $expected
        }
        
        It "Returns else value when variable is false" {
            $template = @"
Status: {{ 'Active' if is_active else 'Inactive' }}
"@
            $context = @{
                is_active = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Status: Inactive"
            $result | Should -Be $expected
        }
        
        It "Works with comparison operators" {
            $template = @"
Age group: {{ 'Adult' if age >= 18 else 'Minor' }}
"@
            $context = @{
                age = 25
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Age group: Adult"
            $result | Should -Be $expected
        }
        
        It "Returns else value when comparison is false" {
            $template = @"
Age group: {{ 'Adult' if age >= 18 else 'Minor' }}
"@
            $context = @{
                age = 15
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Age group: Minor"
            $result | Should -Be $expected
        }
    }
    
    Context "Nested Ternary Operators" {
        It "Handles nested ternary for grade calculation" {
            $template = @"
Grade: {{ 'A' if score >= 90 else 'B' if score >= 80 else 'C' if score >= 70 else 'F' }}
"@
            $context = @{
                score = 95
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Grade: A"
            $result | Should -Be $expected
        }
        
        It "Returns second level in nested ternary" {
            $template = @"
Grade: {{ 'A' if score >= 90 else 'B' if score >= 80 else 'C' if score >= 70 else 'F' }}
"@
            $context = @{
                score = 85
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Grade: B"
            $result | Should -Be $expected
        }
        
        It "Returns third level in nested ternary" {
            $template = @"
Grade: {{ 'A' if score >= 90 else 'B' if score >= 80 else 'C' if score >= 70 else 'F' }}
"@
            $context = @{
                score = 75
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Grade: C"
            $result | Should -Be $expected
        }
        
        It "Returns final else value in nested ternary" {
            $template = @"
Grade: {{ 'A' if score >= 90 else 'B' if score >= 80 else 'C' if score >= 70 else 'F' }}
"@
            $context = @{
                score = 55
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Grade: F"
            $result | Should -Be $expected
        }
        
        It "Handles edge case at boundary" {
            $template = @"
Grade: {{ 'A' if score >= 90 else 'B' if score >= 80 else 'C' if score >= 70 else 'F' }}
"@
            $context = @{
                score = 90
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Grade: A"
            $result | Should -Be $expected
        }
    }
    
    Context "Ternary with Filters" {
        It "Applies filter to true value" {
            $template = @"
Name: {{ name | upper if show_uppercase else name | lower }}
"@
            $context = @{
                name = "Alice"
                show_uppercase = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Name: ALICE"
            $result | Should -Be $expected
        }
        
        It "Applies filter to false value" {
            $template = @"
Name: {{ name | upper if show_uppercase else name | lower }}
"@
            $context = @{
                name = "Alice"
                show_uppercase = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Name: alice"
            $result | Should -Be $expected
        }
        
        It "Works with multiple filters on true branch" {
            $template = @"
{{ text | upper | trim if format else text }}
"@
            $context = @{
                text = "  hello  "
                format = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "HELLO"
            $result | Should -Be $expected
        }
        
        It "Works with multiple filters on false branch" {
            $template = @"
{{ text if keep_original else text | lower | trim }}
"@
            $context = @{
                text = "  HELLO  "
                keep_original = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "hello"
            $result | Should -Be $expected
        }
    }
    
    Context "Complex Expressions in Conditions" {
        It "Handles logical AND in condition" {
            $template = @"
Access: {{ 'Granted' if user.role == 'admin' and user.active else 'Denied' }}
"@
            $context = @{
                user = @{
                    role = "admin"
                    active = $true
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Access: Granted"
            $result | Should -Be $expected
        }
        
        It "Returns false when AND condition fails" {
            $template = @"
Access: {{ 'Granted' if user.role == 'admin' and user.active else 'Denied' }}
"@
            $context = @{
                user = @{
                    role = "admin"
                    active = $false
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Access: Denied"
            $result | Should -Be $expected
        }
        
        It "Handles logical OR in condition" {
            $template = @"
Status: {{ 'Available' if is_online or is_away else 'Offline' }}
"@
            $context = @{
                is_online = $false
                is_away = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Status: Available"
            $result | Should -Be $expected
        }
        
        It "Handles multiple comparison operators" {
            $template = @"
Result: {{ 'Valid' if value > 0 and value < 100 else 'Invalid' }}
"@
            $context = @{
                value = 50
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: Valid"
            $result | Should -Be $expected
        }
        
        It "Handles string equality in condition" {
            $template = @"
Message: {{ 'Welcome!' if status == 'success' else 'Error occurred' }}
"@
            $context = @{
                status = "success"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Message: Welcome!"
            $result | Should -Be $expected
        }
        
        It "Handles inequality operator" {
            $template = @"
Result: {{ 'Different' if a != b else 'Same' }}
"@
            $context = @{
                a = 5
                b = 10
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: Different"
            $result | Should -Be $expected
        }
    }
    
    Context "Ternary with Property Access" {
        It "Accesses property based on condition" {
            $template = @"
Value: {{ obj.success_value if obj.is_success else obj.error_value }}
"@
            $context = @{
                obj = @{
                    is_success = $true
                    success_value = "Operation completed"
                    error_value = "Operation failed"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Value: Operation completed"
            $result | Should -Be $expected
        }
        
        It "Accesses error property when condition is false" {
            $template = @"
Value: {{ obj.success_value if obj.is_success else obj.error_value }}
"@
            $context = @{
                obj = @{
                    is_success = $false
                    success_value = "Operation completed"
                    error_value = "Operation failed"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Value: Operation failed"
            $result | Should -Be $expected
        }
        
        It "Works with nested property access" {
            $template = @"
{{ user.profile.name if user.is_logged_in else 'Guest' }}
"@
            $context = @{
                user = @{
                    is_logged_in = $true
                    profile = @{
                        name = "John Doe"
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "John Doe"
            $result | Should -Be $expected
        }
        
        It "Returns else value with nested property access" {
            $template = @"
{{ user.profile.name if user.is_logged_in else 'Guest' }}
"@
            $context = @{
                user = @{
                    is_logged_in = $false
                    profile = @{
                        name = "John Doe"
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Guest"
            $result | Should -Be $expected
        }
    }
    
    Context "Ternary with Numeric Values" {
        It "Returns numeric values" {
            $template = @"
Count: {{ 100 if is_large else 10 }}
"@
            $context = @{
                is_large = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Count: 100"
            $result | Should -Be $expected
        }
        
        It "Works with numeric comparisons" {
            $template = @"
Price: {{ discounted_price if discount else price }}
"@
            $context = @{
                price = 100
                discounted_price = 90
                discount = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Price: 90"
            $result | Should -Be $expected
        }
        
        It "Handles zero values" {
            $template = @"
Result: {{ 0 if reset else value }}
"@
            $context = @{
                reset = $true
                value = 42
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: 0"
            $result | Should -Be $expected
        }
        
        It "Handles negative numbers" {
            $template = @"
Balance: {{ debit_amount if is_debit else amount }}
"@
            $context = @{
                amount = 50
                debit_amount = -50
                is_debit = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Balance: -50"
            $result | Should -Be $expected
        }
    }
    
    Context "Whitespace Handling" {
        It "Preserves whitespace in output" {
            $template = @"
Result: {{ 'yes' if true else 'no' }}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: yes"
            $result | Should -Be $expected
        }
        
        It "Works with whitespace trimming markers" {
            $template = @"
Start
{{ 'value' if true else 'other' }}
End
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Start
value
End
"@
            $result | Should -Be $expected
        }
        
        It "Handles multiline templates with ternary" {
            $template = @"
First line
{{ 'Active' if status else 'Inactive' }}
Last line
"@
            $context = @{
                status = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
First line
Active
Last line
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Edge Cases" {
        It "Handles explicit true condition" {
            $template = @"
Result: {{ 'has value' if has_value else 'no value' }}
"@
            $context = @{
                has_value = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: has value"
            $result | Should -Be $expected
        }
        
        It "Handles explicit false condition" {
            $template = @"
Result: {{ 'has text' if has_text else 'empty' }}
"@
            $context = @{
                has_text = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: empty"
            $result | Should -Be $expected
        }
        
        It "Handles comparison with zero" {
            $template = @"
Result: {{ 'non-zero' if count > 0 else 'zero' }}
"@
            $context = @{
                count = 5
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: non-zero"
            $result | Should -Be $expected
        }
        
        It "Handles defined variable in condition" {
            $template = @"
Result: {{ 'defined' if defined_var else 'undefined' }}
"@
            $context = @{
                defined_var = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Result: defined"
            $result | Should -Be $expected
        }
        
        It "Handles boolean true literal" {
            $template = @"
{{ 'yes' if true else 'no' }}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "yes"
            $result | Should -Be $expected
        }
        
        It "Handles boolean false literal" {
            $template = @"
{{ 'yes' if false else 'no' }}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "no"
            $result | Should -Be $expected
        }
    }
    
    Context "Integration with Other Constructs" {
        It "Works inside for loop with property check" {
            $template = @"
{% for item in items -%}
{{ item.name }}: {{ 'Active' if item.active else 'Inactive' }}
{% endfor -%}
"@
            $context = @{
                items = @(
                    @{ name = "Item1"; active = $true },
                    @{ name = "Item2"; active = $false },
                    @{ name = "Item3"; active = $true }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Item1: Active
Item2: Inactive
Item3: Active
"@
            $result | Should -Be $expected
        }
        
        It "Works with if statement" {
            $template = @"
{% if show_status -%}
Status: {{ 'Online' if is_online else 'Offline' }}
{% endif -%}
"@
            $context = @{
                show_status = $true
                is_online = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Status: Online"
            $result | Should -Be $expected
        }
        
        It "Multiple ternaries in same line" {
            $template = @"
{{ 'A' if x else 'B' }} and {{ 'C' if y else 'D' }}
"@
            $context = @{
                x = $true
                y = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "A and D"
            $result | Should -Be $expected
        }
        
        It "Ternary with variable assignment result" {
            $template = @"
{% for user in users -%}
{{ user.name }}: {{ 'Admin' if user.role == 'admin' else 'User' }}
{% endfor -%}
"@
            $context = @{
                users = @(
                    @{ name = "Alice"; role = "admin" },
                    @{ name = "Bob"; role = "user" },
                    @{ name = "Charlie"; role = "admin" }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Alice: Admin
Bob: User
Charlie: Admin
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Real-world Scenarios" {
        It "Generates conditional CSS classes" {
            $template = @"
<div class="{{ 'active' if is_active else 'inactive' }}">
  <span class="{{ 'text-success' if status == 'ok' else 'text-danger' }}">
    {{ message }}
  </span>
</div>
"@
            $context = @{
                is_active = $true
                status = "ok"
                message = "All systems operational"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match 'class="active"'
            $result | Should -Match 'class="text-success"'
            $result | Should -Match 'All systems operational'
        }
        
        It "Generates status badges" {
            $template = @"
Status: {{ '✓ Pass' if test_passed else '✗ Fail' }}
Coverage: {{ 'Good' if coverage >= 80 else 'Low' }}
"@
            $context = @{
                test_passed = $true
                coverage = 85
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
Status: ✓ Pass
Coverage: Good
"@
            $result | Should -Be $expected
        }
        
        It "Generates conditional links" {
            $template = @"
<a href="{{ '/dashboard' if is_logged_in else '/login' }}">
  {{ 'Dashboard' if is_logged_in else 'Sign In' }}
</a>
"@
            $context = @{
                is_logged_in = $false
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match 'href="/login"'
            $result | Should -Match 'Sign In'
        }
        
        It "Generates pricing display" {
            $template = @'
Price: ${{ discounted_price if has_discount else regular_price }}
{{ '(Save $' + (regular_price - discounted_price) + ')' if has_discount else '' }}
'@
            $context = @{
                has_discount = $true
                regular_price = 100
                discounted_price = 75
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $result | Should -Match '\$75'
            $result | Should -Match 'Save'
        }
        
        It "Generates user greeting" {
            $template = @"
{{ greeting if is_logged_in else 'Welcome, Guest!' }}
"@
            $context = @{
                is_logged_in = $true
                greeting = "Welcome back, Alice!"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "Welcome back, Alice!"
            $result | Should -Be $expected
        }
        
        It "Generates conditional icon display" {
            $template = @"
{% for item in items -%}
{{ '✓' if item.completed else '○' }} {{ item.task }}
{% endfor -%}
"@
            $context = @{
                items = @(
                    @{ task = "Write tests"; completed = $true },
                    @{ task = "Review code"; completed = $false },
                    @{ task = "Deploy"; completed = $false }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
✓ Write tests
○ Review code
○ Deploy
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Performance and Complex Scenarios" {
        It "Handles deeply nested ternary operators" {
            $template = @"
{{ 'A' if level == 1 else 'B' if level == 2 else 'C' if level == 3 else 'D' if level == 4 else 'E' }}
"@
            $context = @{
                level = 3
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "C"
            $result | Should -Be $expected
        }
        
        It "Handles ternary with complex object navigation" {
            $template = @"
{{ data.first_result if data.success and data.has_results else 'No data' }}
"@
            $context = @{
                data = @{
                    success = $true
                    has_results = $true
                    first_result = "First result"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = "First result"
            $result | Should -Be $expected
        }
        
        It "Handles multiple ternaries in loop" {
            $template = @"
{% for item in items -%}
{{ item.label }}: {{ 'Yes' if item.flag1 else 'No' }} / {{ 'On' if item.flag2 else 'Off' }}
{% endfor -%}
"@
            $context = @{
                items = @(
                    @{ label = "A"; flag1 = $true; flag2 = $false },
                    @{ label = "B"; flag1 = $false; flag2 = $true },
                    @{ label = "C"; flag1 = $true; flag2 = $true }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"
A: Yes / Off
B: No / On
C: Yes / On
"@
            $result | Should -Be $expected
        }
    }
}
