# Integration tests for bracket notation (Jinja2 compatibility)
# Tests that foo['bar'] works identically to foo.bar

BeforeAll {
    # Load the Altar template engine
    . "$PSScriptRoot/../../Altar.ps1"
}

Describe "Bracket Notation Tests" {
    
    Context "Basic Property Access" {
        
        It "Should access PSCustomObject property with bracket notation" {
            $template = "{{ user['name'] }}"
            $context = @{
                user = [PSCustomObject]@{
                    name = "John Doe"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "John Doe"
        }
        
        It "Should access hashtable property with bracket notation" {
            $template = "{{ config['setting'] }}"
            $context = @{
                config = @{
                    setting = "enabled"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "enabled"
        }
        
        It "Should produce identical results for dot and bracket notation" {
            $template = "{{ user.name }} == {{ user['name'] }}"
            $context = @{
                user = @{
                    name = "Alice"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Alice == Alice"
        }
    }
    
    Context "Nested Property Access" {
        
        It "Should access nested properties with bracket notation" {
            $template = "{{ data['user']['name'] }}"
            $context = @{
                data = @{
                    user = @{
                        name = "Jane Smith"
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Jane Smith"
        }
        
        It "Should support mixed dot and bracket notation" {
            $template = "{{ data.user['name'] }}"
            $context = @{
                data = @{
                    user = @{
                        name = "Bob"
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Bob"
        }
        
        It "Should support bracket then dot notation" {
            $template = "{{ data['user'].name }}"
            $context = @{
                data = @{
                    user = @{
                        name = "Charlie"
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Charlie"
        }
        
        It "Should handle deeply nested bracket notation" {
            $template = "{{ a['b']['c']['d'] }}"
            $context = @{
                a = @{
                    b = @{
                        c = @{
                            d = "deep value"
                        }
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "deep value"
        }
    }
    
    Context "Bracket Notation with Filters" {
        
        It "Should apply filters to bracket notation" {
            $template = "{{ user['name'] | upper }}"
            $context = @{
                user = @{
                    name = "alice"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "ALICE"
        }
        
        It "Should chain multiple filters with bracket notation" {
            $template = "{{ user['name'] | upper | reverse }}"
            $context = @{
                user = @{
                    name = "alice"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "ECILA"
        }
        
        It "Should apply filters to nested bracket notation" {
            $template = "{{ data['user']['name'] | title }}"
            $context = @{
                data = @{
                    user = @{
                        name = "john doe"
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "John Doe"
        }
    }
    
    Context "Numeric Array Indexing" {
        
        It "Should still support numeric array indexing" {
            $template = "{{ items[0] }}"
            $context = @{
                items = @("apple", "banana", "cherry")
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "apple"
        }
        
        It "Should support multiple numeric indices" {
            $template = "{{ items[0] }}, {{ items[1] }}, {{ items[2] }}"
            $context = @{
                items = @("a", "b", "c")
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "a, b, c"
        }
        
        It "Should support nested array indexing" {
            $template = "{{ matrix[0][1] }}"
            $context = @{
                matrix = @(
                    @(1, 2, 3),
                    @(4, 5, 6)
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "2"
        }
    }
    
    Context "Expression-Based Indexing" {
        
        It "Should support variable as index" {
            $template = @"
{% set key = 'name' %}
{{ user[key] }}
"@
            $context = @{
                user = @{
                    name = "Bob"
                    age = 25
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "Bob"
        }
        
        It "Should support expression as index" {
            $template = "{{ items[1 + 1] }}"
            $context = @{
                items = @("a", "b", "c", "d")
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "c"
        }
    }
    
    Context "Bracket Notation in Control Structures" {
        
        It "Should work in if conditions" {
            $template = @"
{% if user['active'] %}
Active
{% else %}
Inactive
{% endif %}
"@
            $context = @{
                user = @{
                    active = $true
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "Active"
        }
        
        It "Should work in for loops" {
            $template = @"
{% for item in items %}
{{ item['name'] }}
{% endfor %}
"@
            $context = @{
                items = @(
                    @{ name = "Item1" },
                    @{ name = "Item2" },
                    @{ name = "Item3" }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() -replace '\s+', ' ' | Should -Be "Item1 Item2 Item3"
        }
        
        It "Should work with loop variable" {
            $template = @"
{% for item in items %}
{{ loop['index'] }}: {{ item['name'] }}
{% endfor %}
"@
            $context = @{
                items = @(
                    @{ name = "A" },
                    @{ name = "B" }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() -replace '\s+', ' ' | Should -Be "1: A 2: B"
        }
    }
    
    Context "Undefined Behavior with Bracket Notation" {
        
        It "Should handle undefined property in Default mode" {
            $template = "{{ user['missing'] }}"
            $context = @{
                user = @{
                    name = "Alice"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Default
            $result | Should -Be ""
        }
        
        It "Should throw in Strict mode for undefined property" {
            $template = "{{ user['missing'] }}"
            $context = @{
                user = @{
                    name = "Alice"
                }
            }
            
            { Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Strict -ErrorAction Stop } | Should -Throw
        }
        
        It "Should show placeholder in Debug mode for undefined property" {
            $template = "{{ user['missing'] }}"
            $context = @{
                user = @{
                    name = "Alice"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Debug
            $result | Should -Be "{{ user.missing }}"
        }
    }
    
    Context "Special Characters in Property Names" {
        
        It "Should handle property names with spaces using bracket notation" {
            $template = "{{ data['property name'] }}"
            $context = @{
                data = @{
                    'property name' = "value with spaces"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "value with spaces"
        }
        
        It "Should handle property names with special characters" {
            $template = "{{ data['prop-name'] }}"
            $context = @{
                data = @{
                    'prop-name' = "hyphenated"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "hyphenated"
        }
    }
    
    Context "Comparison with Dot Notation" {
        
        It "Should produce identical results for simple access" {
            $template = @"
Dot: {{ user.name }}
Bracket: {{ user['name'] }}
Equal: {{ user.name == user['name'] }}
"@
            $context = @{
                user = @{
                    name = "Test"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Match "Dot: Test"
            $result | Should -Match "Bracket: Test"
            $result | Should -Match "Equal: True"
        }
        
        It "Should produce identical results for nested access" {
            $template = "{{ a.b.c == a['b']['c'] }}"
            $context = @{
                a = @{
                    b = @{
                        c = "value"
                    }
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "True"
        }
        
        It "Should produce identical results with filters" {
            $template = @"
{% set dot_result = user.name | upper %}
{% set bracket_result = user['name'] | upper %}
{{ dot_result == bracket_result }}
"@
            $context = @{
                user = @{
                    name = "test"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result.Trim() | Should -Be "True"
        }
    }
}
