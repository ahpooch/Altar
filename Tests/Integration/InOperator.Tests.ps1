# Integration tests for the 'in' operator

BeforeAll {
    # Load the Altar template engine
    . "$PSScriptRoot/../../Altar.ps1"
}

Describe "In Operator Tests" {
    Context "Basic 'in' operator functionality" {
        It "Should return true when item is in array" {
            $template = "{% if 'apple' in fruits %}found{% else %}not found{% endif %}"
            $context = @{
                fruits = @('apple', 'banana', 'orange')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found"
        }
        
        It "Should return false when item is not in array" {
            $template = "{% if 'grape' in fruits %}found{% else %}not found{% endif %}"
            $context = @{
                fruits = @('apple', 'banana', 'orange')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "not found"
        }
        
        It "Should work with numeric values" {
            $template = "{% if 3 in numbers %}found{% else %}not found{% endif %}"
            $context = @{
                numbers = @(1, 2, 3, 4, 5)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found"
        }
        
        It "Should work with variables on both sides" {
            $template = "{% if item in list %}found{% else %}not found{% endif %}"
            $context = @{
                item = 'banana'
                list = @('apple', 'banana', 'orange')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found"
        }
    }
    
    Context "'in' operator with logical operators" {
        It "Should work with 'and' operator" {
            $template = "{% if 'red' in colors and 'blue' in colors %}both{% else %}not both{% endif %}"
            $context = @{
                colors = @('red', 'green', 'blue')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "both"
        }
        
        It "Should work with 'or' operator" {
            $template = "{% if 'yellow' in colors or 'green' in colors %}at least one{% else %}none{% endif %}"
            $context = @{
                colors = @('red', 'green', 'blue')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "at least one"
        }
    }
    
    Context "'in' operator in loops" {
        It "Should work inside for loops" {
            $template = @"
{% for item in items -%}
{% if item in allowed %}{{ item }},{% endif -%}
{% endfor -%}
"@
            $context = @{
                items = @('apple', 'banana', 'grape', 'orange')
                allowed = @('apple', 'orange')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "apple,orange,"
        }
    }
    
    Context "'in' operator with set statement" {
        It "Should work with variables set in template" {
            $template = @"
{% set fruits = ['apple', 'banana', 'orange'] %}
{% if 'apple' in fruits %}found{% else %}not found{% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "found"
        }
    }
    
    Context "'in' operator with output expressions" {
        It "Should work in ternary expressions" {
            $template = "{{ 'yes' if 'apple' in fruits else 'no' }}"
            $context = @{
                fruits = @('apple', 'banana', 'orange')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "yes"
        }
    }
    
    Context "Edge cases" {
        It "Should handle empty arrays" {
            $template = "{% if 'item' in empty_list %}found{% else %}not found{% endif %}"
            $context = @{
                empty_list = @()
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "not found"
        }
        
        It "Should handle single-item arrays" {
            $template = "{% if 'only' in single %}found{% else %}not found{% endif %}"
            $context = @{
                single = @('only')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found"
        }
    }
}
