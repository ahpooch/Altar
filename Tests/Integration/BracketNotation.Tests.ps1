# Integration tests for bracket notation (Jinja2 compatibility)
# Tests that foo['bar'] works identically to foo.bar

BeforeAll {
    # Load the Altar template engine
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"
    
    # Mock environment variables to ensure test isolation
    Mock Get-AltarEnvironmentVariable { 
        return $null 
    }

    # ------------------------------------------------------------------
    # Jinja2 Oracle lifecycle
    # Start automatically; all tests degrade gracefully when unavailable.
    # ------------------------------------------------------------------
    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
        $oraEnv = Get-OracleEnvironment
        Write-Host "  [Oracle] Jinja2 $($oraEnv.version) / Python $($oraEnv.python_version)" -ForegroundColor DarkGray
    } catch {
        Write-Warning "Jinja2 Oracle unavailable — oracle assertions skipped.`n  Run: pwsh oracle/setup.ps1 -Start"
    }

    # ------------------------------------------------------------------
    # Confirm-MatchesOracle
    #   Sends the same template+context to the reference Jinja2 service
    #   and asserts that Altar's output is byte-for-byte identical.
    #   Line endings are normalised to LF before comparison (Jinja2 always
    #   returns LF; Altar on Windows may return CRLF — both are correct).
    #   No-op when the oracle is not running.
    # ------------------------------------------------------------------
    function script:Confirm-MatchesOracle {
        param(
            [Parameter(Mandatory)] [string]    $Template,
            [hashtable]                         $Context       = @{},
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $AltarResult,
            [string]                            $UndefinedMode = 'default'
        )
        if (-not $script:OracleAvailable) { return }

        $oracle     = Invoke-OracleRender -Template $Template -Context $Context -UndefinedMode $UndefinedMode
        $altarNorm  = $AltarResult -replace '\r\n', "`n" -replace '\r', "`n"
        $oracleNorm = $oracle      -replace '\r\n', "`n" -replace '\r', "`n"
        $altarNorm | Should -Be $oracleNorm -Because 'Altar output must match canonical Jinja2 rendering'
    }
}

AfterAll {
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should support multiple numeric indices" {
            $template = "{{ items[0] }}, {{ items[1] }}, {{ items[2] }}"
            $context = @{
                items = @("a", "b", "c")
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "a, b, c"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
    
    Context "Expression-Based Indexing" {
        
        It "Should support variable as index" {
            $template = @"
{%- set key = 'name' -%}
{{ user[key] }}
"@
            $context = @{
                user = @{
                    name = "Bob"
                    age = 25
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Bob"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should support expression as index" {
            $template = "{{ items[1 + 1] }}"
            $context = @{
                items = @("a", "b", "c", "d")
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "c"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
    
    Context "Bracket Notation in Control Structures" {
        
        It "Should work in if conditions" {
            $template = @"
{%- if user['active'] -%}
Active
{%- else -%}
Inactive
{%- endif -%}
"@
            $context = @{
                user = @{
                    active = $true
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "Active"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should work in for loops" {
            $template = @"
{%- for item in items %}
{{ item['name'] }}
{%- endfor -%}
"@
            $context = @{
                items = @(
                    @{ name = "Item1" },
                    @{ name = "Item2" },
                    @{ name = "Item3" }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

Item1
Item2
Item3
"@

            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should work with loop variable" {
            $template = @"
{%- for item in items %}
{{ loop['index'] }}: {{ item['name'] }}
{%- endfor -%}
"@
            $context = @{
                items = @(
                    @{ name = "A" },
                    @{ name = "B" }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            $expected = @"

1: A
2: B
"@
            
            $result | Should -Be $expected
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result -UndefinedMode 'default'
        }
        
        It "Should throw in Strict mode for undefined property" {
            $template = "{{ user['missing'] }}"
            $context = @{
                user = @{
                    name = "Alice"
                }
            }
            
            { Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Strict -ErrorAction Stop } | Should -Throw

            # Oracle confirms Jinja2 StrictUndefined also raises UndefinedError
            if ($script:OracleAvailable) {
                $resp = Invoke-OracleRender -Template $template -Context $context -UndefinedMode 'strict' -AllowError
                $resp.success   | Should -BeFalse  -Because 'Jinja2 StrictUndefined must raise UndefinedError'
                $resp.exception | Should -Be 'UndefinedError'
            }
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should produce identical results with filters" {
            $template = @"
{%- set dot_result = user.name | upper -%}
{%- set bracket_result = user['name'] | upper -%}
{{- dot_result == bracket_result -}}
"@
            $context = @{
                user = @{
                    name = "test"
                }
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "True"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
}
