# Integration tests for the 'is' operator in Altar template engine

BeforeAll {
    . .\Altar.ps1
}

Describe "Is Operator Tests" {
    Context "Basic 'is defined' test" {
        It "Should return true when variable is defined" {
            $template = "{% if my_var is defined %}defined{% else %}not defined{% endif %}"
            $context = @{
                my_var = 'hello'
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "defined"
        }
        
        It "Should return false when variable is not defined" {
            $template = "{% if undefined_var is defined %}defined{% else %}not defined{% endif %}"
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "not defined"
        }
        
        It "Should work with 'is not defined'" {
            $template = "{% if undefined_var is not defined %}not defined{% else %}defined{% endif %}"
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "not defined"
        }
    }
    
    Context "'is none' and 'is null' tests" {
        It "Should return true when variable is null" {
            $template = "{% if my_var is none %}is none{% else %}not none{% endif %}"
            $context = @{
                my_var = $null
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "is none"
        }
        
        It "Should return false when variable is not null" {
            $template = "{% if my_var is none %}is none{% else %}not none{% endif %}"
            $context = @{
                my_var = 'hello'
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "not none"
        }
        
        It "Should work with 'is null' (alias for 'is none')" {
            $template = "{% if my_var is null %}is null{% else %}not null{% endif %}"
            $context = @{
                my_var = $null
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "is null"
        }
        
        It "Should work with 'is not none'" {
            $template = "{% if my_var is not none %}not none{% else %}is none{% endif %}"
            $context = @{
                my_var = 'hello'
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "not none"
        }
    }
    
    Context "'is even' test" {
        It "Should return true for even numbers" {
            $template = "{% if num is even %}even{% else %}odd{% endif %}"
            $context = @{
                num = 4
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "even"
        }
        
        It "Should return false for odd numbers" {
            $template = "{% if num is even %}even{% else %}odd{% endif %}"
            $context = @{
                num = 5
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "odd"
        }
        
        It "Should work with zero" {
            $template = "{% if num is even %}even{% else %}odd{% endif %}"
            $context = @{
                num = 0
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "even"
        }
    }
    
    Context "'is odd' test" {
        It "Should return true for odd numbers" {
            $template = "{% if num is odd %}odd{% else %}even{% endif %}"
            $context = @{
                num = 7
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "odd"
        }
        
        It "Should return false for even numbers" {
            $template = "{% if num is odd %}odd{% else %}even{% endif %}"
            $context = @{
                num = 8
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "even"
        }
    }
    
    Context "'is' with logical operators" {
        It "Should work with 'and' operator" {
            $template = "{% if var1 is defined and var2 is defined %}both{% else %}not both{% endif %}"
            $context = @{
                var1 = 'hello'
                var2 = 'world'
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "both"
        }
        
        It "Should work with 'or' operator" {
            $template = "{% if var1 is defined or var2 is defined %}at least one{% else %}none{% endif %}"
            $context = @{
                var1 = 'hello'
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "at least one"
        }
    }
    
    Context "'is' in loops" {
        It "Should filter even numbers in a loop" {
            $template = @"
{% for num in numbers -%}
{% if num is even %}{{ num }},{% endif -%}
{% endfor -%}
"@
            $context = @{
                numbers = @(1, 2, 3, 4, 5, 6)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "2,4,6,"
        }
        
        It "Should filter odd numbers in a loop" {
            $template = @"
{% for num in numbers -%}
{% if num is odd %}{{ num }},{% endif -%}
{% endfor -%}
"@
            $context = @{
                numbers = @(1, 2, 3, 4, 5, 6)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "1,3,5,"
        }
    }
    
    Context "'is' with ternary operator" {
        It "Should work in ternary expressions" {
            $template = "{{ 'Active' if user is defined else 'Inactive' }}"
            $context = @{
                user = 'Alice'
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Active"
        }
        
        It "Should work with 'is even' in ternary" {
            $template = "{{ 'Even' if num is even else 'Odd' }}"
            $context = @{
                num = 10
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Even"
        }
    }
    
    Context "Combining 'is' with 'in' operator" {
        It "Should work with both 'is' and 'in' operators" {
            $template = "{% if value in items and value is even %}found and even{% else %}not found or odd{% endif %}"
            $context = @{
                value = 4
                items = @(2, 4, 6, 8)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found and even"
        }
    }
    
    Context "'is' with set statement" {
        It "Should work with variables set in template" {
            $template = @"
{% set my_var = 'hello' %}
{% if my_var is defined %}defined{% else %}not defined{% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "defined"
        }
        
        It "Should work with null values set in template" {
            $template = @"
{% set my_var = null %}
{% if my_var is none %}is none{% else %}not none{% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "is none"
        }
    }
    
    Context "New 'is' tests" {
        It "Should test 'is divisibleby'" {
            $template = "{% if 15 is divisibleby(3) %}yes{% else %}no{% endif %}"
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "yes"
        }
        
        It "Should test 'is number'" {
            $template = "{% if value is number %}number{% else %}not number{% endif %}"
            $context = @{ value = 42 }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "number"
        }
        
        It "Should test 'is string'" {
            $template = "{% if value is string %}string{% else %}not string{% endif %}"
            $context = @{ value = 'hello' }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "string"
        }
        
        It "Should test 'is iterable'" {
            $template = "{% if items is iterable %}iterable{% else %}not iterable{% endif %}"
            $context = @{ items = @(1, 2, 3) }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "iterable"
        }
        
        It "Should test 'is sequence'" {
            $template = "{% if items is sequence %}sequence{% else %}not sequence{% endif %}"
            $context = @{ items = @(1, 2, 3) }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "sequence"
        }
        
        It "Should test 'is mapping'" {
            $template = "{% if dict is mapping %}mapping{% else %}not mapping{% endif %}"
            $context = @{ dict = @{ key = 'value' } }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "mapping"
        }
        
        It "Should test 'is lower'" {
            $template = "{% if text is lower %}lower{% else %}not lower{% endif %}"
            $context = @{ text = 'hello' }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "lower"
        }
        
        It "Should test 'is upper'" {
            $template = "{% if text is upper %}upper{% else %}not upper{% endif %}"
            $context = @{ text = 'HELLO' }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "upper"
        }
        
        It "Should test 'is sameas'" {
            $template = "{% set obj1 = [1, 2, 3] %}{% set obj2 = obj1 %}{% if obj1 is sameas(obj2) %}same{% else %}different{% endif %}"
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "same"
        }
    }
}
