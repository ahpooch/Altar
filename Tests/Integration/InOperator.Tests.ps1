# Integration tests for the 'in' operator — enhanced with Jinja2 Oracle validation

BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
    } catch {
        Write-Warning "Jinja2 Oracle unavailable — oracle assertions skipped.`n  Run: pwsh oracle/setup.ps1 -Start"
    }

    function script:Confirm-MatchesOracle {
        param(
            [Parameter(Mandatory)] [string]    $Template,
            [hashtable]                        $Context       = @{},
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $AltarResult,
            [string]                           $UndefinedMode = 'default'
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

Describe "In Operator Tests" -Tag 'Integration' {
    Context "Basic 'in' operator functionality" {
        It "Should return true when item is in array" {
            $template = "{% if 'apple' in fruits %}found{% else %}not found{% endif %}"
            $context = @{
                fruits = @('apple', 'banana', 'orange')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should return false when item is not in array" {
            $template = "{% if 'grape' in fruits %}found{% else %}not found{% endif %}"
            $context = @{
                fruits = @('apple', 'banana', 'orange')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "not found"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should work with numeric values" {
            $template = "{% if 3 in numbers %}found{% else %}not found{% endif %}"
            $context = @{
                numbers = @(1, 2, 3, 4, 5)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should work with variables on both sides" {
            $template = "{% if item in list %}found{% else %}not found{% endif %}"
            $context = @{
                item = 'banana'
                list = @('apple', 'banana', 'orange')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should work with 'or' operator" {
            $template = "{% if 'yellow' in colors or 'green' in colors %}at least one{% else %}none{% endif %}"
            $context = @{
                colors = @('red', 'green', 'blue')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "at least one"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
    
    Context "'in' operator with set statement" {
        It "Should work with variables set in template" {
            $template = @"
{% set fruits = ['apple', 'banana', 'orange'] %}
{%- if 'apple' in fruits %}found{%- else %}not found{% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult ($result.Trim())
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
        
        It "Should handle single-item arrays" {
            $template = "{% if 'only' in single %}found{% else %}not found{% endif %}"
            $context = @{
                single = @('only')
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be "found"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }
}
