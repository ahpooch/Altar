# Environment Variables Integration Tests — enhanced with Jinja2 Oracle boilerplate
BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

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

Describe "Environment Variables Integration Tests" {
    Context "Altar_TrimBlocks Environment Variable" {
        
        It "Should use environment variable when parameter not specified" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "true" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one", "two") }
            
            # Act
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Assert - TrimBlocks removes first newline after %}, indentation preserved
            $expected = @"
<ul>
        <li>one</li>
        <li>two</li>
    </ul>
"@
            $result | Should -Be $expected
        }
        
        It "Should use false from environment variable" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "false" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one", "two") }
            
            # Act
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Assert
            $expected = @"
<ul>
    
    <li>one</li>
    
    <li>two</li>
    
</ul>
"@
            $result | Should -Be $expected
        }
        
        It "Should override environment variable with explicit parameter" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "false" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one", "two") }
            
            # Act - Explicitly set TrimBlocks to true
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # Assert - Should use true (from param), indentation preserved
            $expected = @"
<ul>
        <li>one</li>
        <li>two</li>
    </ul>
"@
            $result | Should -Be $expected
        }
        
        It "Should handle invalid environment variable value gracefully" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "invalid_value" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = "{% if true %}test{% endif %}"
            $context = @{}
            
            # Act - Should use default value and not throw
            $result = Invoke-AltarTemplate -Template $template -Context $context -WarningAction SilentlyContinue
            
            # Assert - Should still render successfully with default value
            $result | Should -Be "test"
        }
        
        It "Should use default value when environment variable is empty string" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one") }
            
            # Act
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Assert - Should use default (false)
            $expected = @"
<ul>
    
    <li>one</li>
    
</ul>
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Altar_LstripBlocks Environment Variable" {
        
        It "Should use environment variable when parameter not specified" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "true" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one", "two") }
            
            # Act
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Assert - LstripBlocks removes spaces before {%, but not before <li>
            $expected = @"
<ul>

    <li>one</li>

    <li>two</li>

</ul>
"@
            $result | Should -Be $expected
        }
        
        It "Should use false from environment variable" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "false" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one") }
            
            # Act
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Assert - Should preserve leading spaces
            $expected = @"
<ul>
    
    <li>one</li>
    
</ul>
"@
            $result | Should -Be $expected
        }
        
        It "Should override environment variable with explicit parameter" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "false" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one") }
            
            # Act - Explicitly set LstripBlocks to true
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $true
            
            # Assert - LstripBlocks removes spaces before {%, but not before <li>
            $expected = @"
<ul>

    <li>one</li>

</ul>
"@
            $result | Should -Be $expected
        }
        
        It "Should handle invalid environment variable value gracefully" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "not_a_boolean" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = "{% if true %}test{% endif %}"
            $context = @{}
            
            # Act - Should use default value and not throw
            $result = Invoke-AltarTemplate -Template $template -Context $context -WarningAction SilentlyContinue
            
            # Assert - Should still render successfully with default value
            $result | Should -Be "test"
        }
    }
    
    Context "Both Environment Variables Together" {
        
        It "Should use both environment variables when neither parameter specified" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "true" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "true" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one", "two") }
            
            # Act
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Assert - Both applied: lstrip removes spaces before {%, trim removes newline after %}
            $expected = @"
<ul>
    <li>one</li>
    <li>two</li>
</ul>
"@
            $result | Should -Be $expected
        }
        
        It "Should allow mixed override - one from env, one from parameter" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "false" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "false" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one") }
            
            # Act - Override only TrimBlocks
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # Assert - TrimBlocks=true (from param), LstripBlocks=false (from env), indentation preserved
            $expected = @"
<ul>
        <li>one</li>
    </ul>
"@
            $result | Should -Be $expected
        }
        
        It "Should work with both parameters explicitly set, ignoring environment" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "false" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "false" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{ items = @("one", "two") }
            
            # Act - Both explicitly set to true
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            # Assert - Both applied: lstrip removes spaces before {%, trim removes newline after %}
            $expected = @"
<ul>
    <li>one</li>
    <li>two</li>
</ul>
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Environment Variable Case Sensitivity" {
        
        It "Should accept 'True' with capital T" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "True" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<div>
    {% if true %}
    <p>test</p>
    {% endif %}
</div>
"@
            $context = @{}
            
            # Act
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Assert - TrimBlocks removes newline after %}, indentation preserved
            $expected = @"
<div>
        <p>test</p>
    </div>
"@
            $result | Should -Be $expected
        }
        
        It "Should accept 'FALSE' in all caps" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "FALSE" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = "    {% if true %}test{% endif %}"
            $context = @{}
            
            # Act
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Assert - Should preserve leading spaces
            $result | Should -Be "    test"
        }
    }
    
    Context "Real-world Scenario - CI/CD Pipeline" {
        
        It "Should work in CI/CD scenario with global environment settings" {
            # Arrange - Simulate CI/CD environment with global settings
            Mock Get-AltarEnvironmentVariable { 
                return "true" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "true" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            # Multiple template renders in the same session
            $template1 = @"
<html>
    {% for page in pages %}
    <link href="{{ page }}">
    {% endfor %}
</html>
"@
            
            $template2 = @"
<div>
    {% if user %}
    <p>{{ user }}</p>
    {% endif %}
</div>
"@
            
            $context1 = @{ pages = @("page1.css", "page2.css") }
            $context2 = @{ user = "John" }
            
            # Act
            $result1 = Invoke-AltarTemplate -Template $template1 -Context $context1
            $result2 = Invoke-AltarTemplate -Template $template2 -Context $context2
            
            # Assert - Both applied: lstrip removes spaces before {%, trim removes newline after %}
            $expected1 = @"
<html>
    <link href="page1.css">
    <link href="page2.css">
</html>
"@
            $expected2 = @"
<div>
    <p>John</p>
</div>
"@
            
            $result1 | Should -Be $expected1
            $result2 | Should -Be $expected2
        }
    }
    
    Context "Edge Cases" {
        
        It "Should handle null environment variable" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return $null 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = "{% if true %}test{% endif %}"
            $context = @{}
            
            # Act - Should use default value
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Assert
            $result | Should -Be "test"
        }
        
        It "Should handle numeric-like strings in environment variable" {
            # Arrange
            Mock Get-AltarEnvironmentVariable { 
                return "1" 
            } -ParameterFilter { $Name -eq "Altar_TrimBlocks" }
            
            Mock Get-AltarEnvironmentVariable { 
                return "0" 
            } -ParameterFilter { $Name -eq "Altar_LstripBlocks" }
            
            $template = @"
<div>
    {% if true %}
    <p>test</p>
    {% endif %}
</div>
"@
            $context = @{}
            
            # Act - Should ignore "1" and "0" as invalid and use defaults
            $result = Invoke-AltarTemplate -Template $template -Context $context -WarningAction SilentlyContinue
            
            # Assert - Both invalid, should use default (false), newlines preserved
            $expected = @"
<div>
    
    <p>test</p>
    
</div>
"@
            $result | Should -Be $expected
        }
    }
}
