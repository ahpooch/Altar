# Integration tests for Line Statements functionality — enhanced with Jinja2 Oracle boilerplate

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

Describe "Line Statements - Basic Functionality" {
    It "Should process basic line statement with for loop" {
        $template = @"
<ul>
# for item in items
    <li>{{ item }}</li>
# endfor
</ul>
"@
        
        $context = @{
            items = @('Apple', 'Banana', 'Cherry')
        }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '<li>Apple</li>'
        $result | Should -Match '<li>Banana</li>'
        $result | Should -Match '<li>Cherry</li>'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
    
    It "Should support colon at end of line statement" {
        $template = @"
# for item in items:
    {{ item }}
# endfor
"@
        
        $context = @{ items = @(1, 2, 3) }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '1'
        $result | Should -Match '2'
        $result | Should -Match '3'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
    
    It "Should process if statement as line statement" {
        $template = @"
# if show_greeting
Hello, {{ name }}!
# endif
"@
        
        $context = @{
            show_greeting = $true
            name = 'World'
        }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match 'Hello, World!'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
    
    It "Should process if-else statement as line statement" {
        $template = @"
# if user_logged_in:
    Welcome back, {{ username }}!
# else:
    Please log in.
# endif
"@
        
        $context = @{
            user_logged_in = $false
            username = 'John'
        }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match 'Please log in'
        $result | Should -Not -Match 'Welcome back'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
    
    It "Should work with custom prefix" {
        $template = @"
<ul>
% for item in items
    <li>{{ item }}</li>
% endfor
</ul>
"@
        
        $context = @{
            items = @('A', 'B', 'C')
        }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '%'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '<li>A</li>'
        $result | Should -Match '<li>B</li>'
        $result | Should -Match '<li>C</li>'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
    
    It "Should only process line statements at start of line" {
        $template = @"
# for item in items
    Text before # this is not a line statement
# endfor
"@
        
        $context = @{
            items = @('Test')
        }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match 'Text before # this is not a line statement'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
}

Describe "Line Comments - Basic Functionality" {
    It "Should ignore line comments" {
        $template = @"
# for item in items
    <li>{{ item }}</li>     ## this is a comment
# endfor
"@
        
        $context = @{ items = @('Test') }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        [Lexer]::LINE_COMMENT_PREFIX = '##'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Not -Match 'this is a comment'
        $result | Should -Match '<li>Test</li>'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
        [Lexer]::LINE_COMMENT_PREFIX = $null
    }
    
    It "Should ignore full line comments" {
        $template = @"
## This is a header comment
# for item in items
    <li>{{ item }}</li>
# endfor
## This is a footer comment
"@
        
        $context = @{ items = @('A', 'B') }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        [Lexer]::LINE_COMMENT_PREFIX = '##'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Not -Match 'header comment'
        $result | Should -Not -Match 'footer comment'
        $result | Should -Match '<li>A</li>'
        $result | Should -Match '<li>B</li>'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
        [Lexer]::LINE_COMMENT_PREFIX = $null
    }
    
    It "Should work with custom comment prefix" {
        $template = @"
// This is a comment
# for item in items
    {{ item }}  // inline comment
# endfor
"@
        
        $context = @{ items = @(1, 2) }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        [Lexer]::LINE_COMMENT_PREFIX = '//'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Not -Match 'This is a comment'
        $result | Should -Not -Match 'inline comment'
        $result | Should -Match '1'
        $result | Should -Match '2'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
        [Lexer]::LINE_COMMENT_PREFIX = $null
    }
}

Describe "Line Statements - Advanced Features" {
    It "Should handle nested line statements" {
        $template = @"
# for category in categories
    <h2>{{ category.name }}</h2>
    <ul>
    # for item in category.items
        <li>{{ item }}</li>
    # endfor
    </ul>
# endfor
"@
        
        $context = @{
            categories = @(
                @{ name = 'Fruits'; items = @('Apple', 'Banana') },
                @{ name = 'Vegetables'; items = @('Carrot', 'Potato') }
            )
        }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '<h2>Fruits</h2>'
        $result | Should -Match '<li>Apple</li>'
        $result | Should -Match '<h2>Vegetables</h2>'
        $result | Should -Match '<li>Carrot</li>'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
    
    It "Should handle line statements with whitespace before prefix" {
        $template = @"
<div>
    # if show_content
        <p>Content here</p>
    # endif
</div>
"@
        
        $context = @{ show_content = $true }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '<p>Content here</p>'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
    
    It "Should work without line statement prefix (normal mode)" {
        $template = @"
{% for item in items %}
    {{ item }}
{% endfor %}
"@
        
        $context = @{ items = @(1, 2, 3) }
        
        $engine = [TemplateEngine]::new()
        # No prefix set - should work normally
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '1'
        $result | Should -Match '2'
        $result | Should -Match '3'
    }
}

Describe "Line Statements - Edge Cases" {
    It "Should handle empty line statement body" {
        $template = @"
# for item in items
# endfor
Done
"@
        
        $context = @{ items = @(1, 2, 3) }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        
        $result = $engine.Render($template, $context)
        
        $result | Should -Match 'Done'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
    
    It "Should handle line statement with complex expression" {
        $template = @"
# for item in items | sort | reverse
    {{ item }}
# endfor
"@
        
        $context = @{ items = @(3, 1, 2) }
        
        $engine = [TemplateEngine]::new()
        [Lexer]::LINE_STATEMENT_PREFIX = '#'
        
        $result = $engine.Render($template, $context)
        
        # Should be sorted (1,2,3) then reversed (3,2,1)
        $lines = $result -split "`n" | Where-Object { $_ -match '\d' }
        $lines[0] | Should -Match '3'
        $lines[-1] | Should -Match '1'
        
        # Cleanup
        [Lexer]::LINE_STATEMENT_PREFIX = $null
    }
}
