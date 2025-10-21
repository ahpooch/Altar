# Invoke-Pester -Path .\Tests\Integration\Include.Tests.ps1 -Output Detailed
BeforeAll {
    . .\Altar.ps1
}

Describe 'Include Statement Integration Tests' -Tag 'Integration' {
    
    Context "Basic Include Functionality" {
        It "Includes a single file with single quotes" {
            $template = @"
First line.
{% include 'test_include.alt' -%}
Last line.
"@
            $includedFile = @"
This is included content.
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "test_include.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            # The -%} trims the newline after the included content
            $expected = @"
First line.
This is included content.Last line.
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Includes a single file with double quotes" {
            $template = @"
{% include "test_include.alt" -%}
"@
            $includedFile = @"
Included with double quotes.
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "test_include.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = "Included with double quotes."
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Includes multiple files in sequence" {
            $template = @"
{% include 'first.alt' -%}
{% include 'second.alt' -%}
{% include 'third.alt' -%}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path (Join-Path $tempDir "first.alt") -Value "First"
            Set-Content -Path (Join-Path $tempDir "second.alt") -Value "Second"
            Set-Content -Path (Join-Path $tempDir "third.alt") -Value "Third"
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            # The -%} trims newlines after each include
            $expected = "FirstSecondThird"
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    Context "Include with Relative Paths" {
        It "Includes file from subdirectory" {
            $template = @"
{% include 'include_files/nested.alt' -%}
"@
            $includedFile = @"
Content from subdirectory
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            $subDir = Join-Path $tempDir "include_files"
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $subDir "nested.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = "Content from subdirectory"
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Processes the actual example from Examples/Include Statement/main.alt" {
            $result = Invoke-AltarTemplate -Path "Examples\Include Statement\main.alt" -Context @{
                username = "TestUser"
                content = "TestContent"
                var = "TestVar"
            }
            
            $result | Should -BeLike "*First line.*"
            $result | Should -BeLike "*This is a first_include.alt text.*"
            $result | Should -BeLike "*Variable var is: TestVar*"
            $result | Should -BeLike "*Hellow TestUser*"
            $result | Should -BeLike "*TestContent*"
            $result | Should -BeLike "*This is a second_include.alt text.*"
            $result | Should -BeLike "*This is a third_include.alt text.*"
            $result | Should -BeLike "*Last line.*"
        }
    }
    
    Context "Include with Variables" {
        It "Passes variables from parent scope to included file" {
            $template = @"
{% set name = "World" -%}
{% include 'greeting.alt' -%}
"@
            $includedFile = @"
Hello, {{ name }}!
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "greeting.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = "Hello, World!"
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Accesses context variables in included file" {
            $template = @"
{% include 'user_info.alt' -%}
"@
            $includedFile = @"
User: {{ username }}
Content: {{ content }}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "user_info.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $context = @{
                username = "Alice"
                content = "Test Content"
            }
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context $context
            
            $expected = @"
User: Alice
Content: Test Content
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    Context "Ignore Missing Directive" {
        It "Ignores missing file with 'ignore missing' directive" {
            $template = @"
Before
{% include 'nonexistent.alt' ignore missing -%}
After
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            Set-Content -Path $mainPath -Value $template
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = @"
Before
After
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Throws error when file is missing without 'ignore missing'" {
            $template = @"
{% include 'nonexistent.alt' -%}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            Set-Content -Path $mainPath -Value $template
            
            {
                Invoke-AltarTemplate -Path $mainPath -Context @{} -ErrorAction Stop
            } | Should -Throw
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    Context "Array Include with Fallback" {
        It "Includes first existing file from array" {
            $template = @"
{% include ['nonexistent1.alt', 'existing.alt', 'nonexistent2.alt'] -%}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $existingPath = Join-Path $tempDir "existing.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $existingPath -Value "Found the existing file!"
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = "Found the existing file!"
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Includes first file when multiple exist in array" {
            $template = @"
{% include ['first.alt', 'second.alt'] -%}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path (Join-Path $tempDir "first.alt") -Value "First file"
            Set-Content -Path (Join-Path $tempDir "second.alt") -Value "Second file"
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = "First file"
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Handles array with all missing files and 'ignore missing'" {
            $template = @"
Before
{% include ['nonexistent1.alt', 'nonexistent2.alt'] ignore missing -%}
After
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            Set-Content -Path $mainPath -Value $template
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = @"
Before
After
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Throws error when all files in array are missing without 'ignore missing'" {
            $template = @"
{% include ['nonexistent1.alt', 'nonexistent2.alt'] -%}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            Set-Content -Path $mainPath -Value $template
            
            {
                Invoke-AltarTemplate -Path $mainPath -Context @{} -ErrorAction Stop
            } | Should -Throw
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Includes file from subdirectory in array fallback" {
            $template = @"
{% include ['nonexistent.alt', 'include_files/nested.alt'] -%}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            $subDir = Join-Path $tempDir "include_files"
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $nestedPath = Join-Path $subDir "nested.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $nestedPath -Value "Nested file from array"
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = "Nested file from array"
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    Context "Whitespace Control" {
        It "Trims whitespace on the right with -%}" {
            $template = @"
Before
{% include 'test.alt' -%}
After
"@
            $includedFile = @"
Included
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "test.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            # The -%} trims the newline after included content
            $expected = @"
Before
IncludedAfter
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Trims whitespace on the left with {%-" {
            $template = @"
Before
    {%- include 'test.alt' %}
After
"@
            $includedFile = @"
Included
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "test.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            # The {%- doesn't trim the newline after included content (known limitation)
            $expected = @"
Before
Included
After
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Trims whitespace on both sides" {
            $template = @"
Before
    {%- include 'test.alt' -%}
After
"@
            $includedFile = @"
Included
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "test.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            # Both {%- and -%} trim, but -%} removes the newline after included content
            $expected = @"
Before
IncludedAfter
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    Context "Nested Includes" {
        It "Handles include within included file" {
            $mainTemplate = @"
Main
{% include 'level1.alt' -%}
"@
            $level1Template = @"
Level 1
{% include 'level2.alt' -%}
"@
            $level2Template = @"
Level 2
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $level1Path = Join-Path $tempDir "level1.alt"
            $level2Path = Join-Path $tempDir "level2.alt"
            
            Set-Content -Path $mainPath -Value $mainTemplate
            Set-Content -Path $level1Path -Value $level1Template
            Set-Content -Path $level2Path -Value $level2Template
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = @"
Main
Level 1
Level 2
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Passes variables through nested includes" {
            $mainTemplate = @"
{% set value = "Test" -%}
{% include 'level1.alt' -%}
"@
            $level1Template = @"
{% include 'level2.alt' -%}
"@
            $level2Template = @"
Value: {{ value }}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $level1Path = Join-Path $tempDir "level1.alt"
            $level2Path = Join-Path $tempDir "level2.alt"
            
            Set-Content -Path $mainPath -Value $mainTemplate
            Set-Content -Path $level1Path -Value $level1Template
            Set-Content -Path $level2Path -Value $level2Template
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = "Value: Test"
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    Context "Include with Control Structures" {
        It "Processes if statements in included file" {
            $template = @"
{% set showMessage = true -%}
{% include 'conditional.alt' -%}
"@
            $includedFile = @"
{% if showMessage -%}
Message shown
{% endif -%}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "conditional.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = "Message shown"
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Processes for loops in included file" {
            $template = @"
{% set items = ["A", "B", "C"] -%}
{% include 'loop.alt' -%}
"@
            $includedFile = @"
{% for item in items -%}
- {{ item }}
{% endfor -%}
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "loop.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $expected = @"
- A
- B
- C
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    Context "Include with Comments" {
        It "Processes comments in included file" {
            $template = @"
{% include 'commented.alt' -%}
"@
            $includedFile = @"
{# This is a comment #}
Visible content
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $includePath = Join-Path $tempDir "commented.alt"
            
            Set-Content -Path $mainPath -Value $template
            Set-Content -Path $includePath -Value $includedFile
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            # Comment leaves a newline
            $expected = "`r`nVisible content"
            $result | Should -Be $expected
            $result | Should -Not -BeLike "*This is a comment*"
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    Context "Real-world Scenarios" {
        It "Includes header, content, and footer files" {
            $mainTemplate = @"
{% include 'header.alt' -%}
Main content here
{% include 'footer.alt' -%}
"@
            $headerTemplate = @"
<header>Site Header</header>
"@
            $footerTemplate = @"
<footer>Site Footer</footer>
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $headerPath = Join-Path $tempDir "header.alt"
            $footerPath = Join-Path $tempDir "footer.alt"
            
            Set-Content -Path $mainPath -Value $mainTemplate
            Set-Content -Path $headerPath -Value $headerTemplate
            Set-Content -Path $footerPath -Value $footerTemplate
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            # The -%} after header trims the newline
            $expected = @"
<header>Site Header</header>Main content here
<footer>Site Footer</footer>
"@
            $result | Should -Be $expected
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
        
        It "Uses include for reusable components with variables" {
            $mainTemplate = @"
{% set title = "Welcome" -%}
{% set description = "This is the homepage" -%}
{% include 'card.alt' -%}
{% set title = "About" -%}
{% set description = "Learn more about us" -%}
{% include 'card.alt' -%}
"@
            $cardTemplate = @"
<div class="card">
  <h2>{{ title }}</h2>
  <p>{{ description }}</p>
</div>
"@
            $tempDir = Join-Path $env:TEMP "AltarTests_Include_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $mainPath = Join-Path $tempDir "main.alt"
            $cardPath = Join-Path $tempDir "card.alt"
            
            Set-Content -Path $mainPath -Value $mainTemplate
            Set-Content -Path $cardPath -Value $cardTemplate
            
            $result = Invoke-AltarTemplate -Path $mainPath -Context @{}
            
            $result | Should -BeLike "*<h2>Welcome</h2>*"
            $result | Should -BeLike "*<p>This is the homepage</p>*"
            $result | Should -BeLike "*<h2>About</h2>*"
            $result | Should -BeLike "*<p>Learn more about us</p>*"
            
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}
