# Integration tests for self.blockname() functionality (Jinja2 compatibility)
# Tests the ability to call blocks as functions from anywhere in the template

BeforeAll {
    . .\Altar.ps1
}

Describe "Self Variable - Basic Functionality" {
    It "Should call a block from within the template" {
        $template = @'
{% block title %}Welcome{% endblock %}

<h1>{{ self.title() }}</h1>
<p>Page: {{ self.title() }}</p>
'@
        
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match "Welcome"
        $result | Should -Match "<h1>Welcome</h1>"
        $result | Should -Match "<p>Page: Welcome</p>"
    }
    
    It "Should call a block multiple times" {
        $template = @'
{% block greeting %}Hello, World!{% endblock %}

{{ self.greeting() }}
{{ self.greeting() }}
{{ self.greeting() }}
'@
        
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        # Should have the block content 4 times (1 from block definition + 3 from self calls)
        $matches = [regex]::Matches($result, "Hello, World!")
        $matches.Count | Should -Be 4
    }
    
    It "Should work with blocks containing variables" {
        $template = @'
{% block user_info %}User: {{ username }}{% endblock %}

<div>{{ self.user_info() }}</div>
<span>{{ self.user_info() }}</span>
'@
        
        $context = @{
            username = "John"
        }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match "User: John"
        $result | Should -Match "<div>User: John</div>"
        $result | Should -Match "<span>User: John</span>"
    }
    
    It "Should work with blocks containing expressions" {
        $template = @'
{% block calculation %}{{ 5 + 3 }}{% endblock %}

Result 1: {{ self.calculation() }}
Result 2: {{ self.calculation() }}
'@
        
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match "8"
        $result | Should -Match "Result 1: 8"
        $result | Should -Match "Result 2: 8"
    }
}

Describe "Self Variable - With Filters" {
    It "Should work with filtered self calls" {
        $template = @'
{% block name %}john doe{% endblock %}

{{ self.name() | upper }}
{{ self.name() | title }}
'@
        
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match "JOHN DOE"
        $result | Should -Match "John Doe"
    }
    
    It "Should work with multiple filters on self calls" {
        $template = @'
{% block text %}  hello world  {% endblock %}

{{ self.text() | trim | upper }}
'@
        
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match "HELLO WORLD"
    }
}

Describe "Self Variable - With Template Inheritance" {
    BeforeAll {
        # Create temporary directory for test templates
        $script:TestDir = Join-Path $TestDrive "SelfTests"
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
    }
    
    It "Should work with inherited blocks" {
        # Create base template
        $baseTemplate = @'
{% block title %}Base Title{% endblock %}

<h1>{{ self.title() }}</h1>
{% block content %}
Base content
{% endblock %}
'@
        
        # Create child template
        $childTemplate = @'
{% extends "base.alt" %}

{% block title %}Child Title{% endblock %}

{% block content %}
Child content: {{ self.title() }}
{% endblock %}
'@
        
        $basePath = Join-Path $script:TestDir "base.alt"
        $childPath = Join-Path $script:TestDir "child.alt"
        
        Set-Content -Path $basePath -Value $baseTemplate
        Set-Content -Path $childPath -Value $childTemplate
        
        $context = @{}
        $result = Invoke-AltarTemplate -Path $childPath -Context $context
        
        $result | Should -Match "Child Title"
        $result | Should -Match "<h1>Child Title</h1>"
        $result | Should -Match "Child content: Child Title"
    }
    
    It "Should call overridden blocks via self" {
        # Create base template
        $baseTemplate = @'
{% block greeting %}Hello{% endblock %}

Base: {{ self.greeting() }}
{% block content %}
Content
{% endblock %}
'@
        
        # Create child template that overrides greeting
        $childTemplate = @'
{% extends "base2.alt" %}

{% block greeting %}Hi there{% endblock %}

{% block content %}
Child says: {{ self.greeting() }}
{% endblock %}
'@
        
        $basePath = Join-Path $script:TestDir "base2.alt"
        $childPath = Join-Path $script:TestDir "child2.alt"
        
        Set-Content -Path $basePath -Value $baseTemplate
        Set-Content -Path $childPath -Value $childTemplate
        
        $context = @{}
        $result = Invoke-AltarTemplate -Path $childPath -Context $context
        
        # Both self calls should use the child's overridden block
        $result | Should -Match "Base: Hi there"
        $result | Should -Match "Child says: Hi there"
    }
}

Describe "Self Variable - Recursion Protection" {
    It "Should prevent infinite recursion with default depth limit" {
        $template = @'
{% block recursive %}{{ self.recursive() }}{% endblock %}
'@
        
        $context = @{}
        
        # Should throw an error about recursion depth
        try {
            $result = Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            # If we get here, the test failed
            $false | Should -Be $true -Because "Expected recursion error but got result: $result"
        }
        catch {
            $_.Exception.Message | Should -Match "Maximum self recursion depth exceeded"
        }
    }
    
    It "Should allow calling different blocks without recursion" {
        $template = @'
{% block first %}First Block{% endblock %}
{% block second %}Second: {{ self.first() }}{% endblock %}

{{ self.second() }}
'@
        
        $context = @{}
        
        # This should work because second calls first, which doesn't call anything else
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match "First Block"
        $result | Should -Match "Second: First Block"
    }
    
    It "Should respect custom recursion depth limit" {
        # Temporarily increase recursion depth
        $originalDepth = [TemplateEngine]::MaxSelfRecursionDepth
        try {
            [TemplateEngine]::MaxSelfRecursionDepth = 2
            
            $template = @'
{% block counter %}{{ count }}{% if count > 0 %}{{ self.counter() }}{% endif %}{% endblock %}
'@
            
            $context = @{
                count = 1
            }
            
            # With depth 2, this should work (count=1, then count=0)
            # But it will fail because count doesn't change between calls
            try {
                $result = Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
                # If we get here, the test failed
                $false | Should -Be $true -Because "Expected recursion error but got result: $result"
            }
            catch {
                $_.Exception.Message | Should -Match "Maximum self recursion depth exceeded"
            }
        }
        finally {
            [TemplateEngine]::MaxSelfRecursionDepth = $originalDepth
        }
    }
}

Describe "Self Variable - Complex Scenarios" {
    It "Should work inside for loops" {
        $template = @'
{% block item_display %}Item: {{ item }}{% endblock %}

{% for item in items %}
{{ self.item_display() }}
{% endfor %}
'@
        
        $context = @{
            items = @("Apple", "Banana", "Cherry")
        }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match "Item: Apple"
        $result | Should -Match "Item: Banana"
        $result | Should -Match "Item: Cherry"
    }
    
    It "Should work inside if statements" {
        $template = @'
{% block status %}Active{% endblock %}

{% if show_status %}
Status: {{ self.status() }}
{% endif %}
'@
        
        $context = @{
            show_status = $true
        }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match "Status: Active"
    }
    
    It "Should work with multiple different blocks" {
        $template = @'
{% block header %}Header Content{% endblock %}
{% block footer %}Footer Content{% endblock %}

<div class="header">{{ self.header() }}</div>
<div class="footer">{{ self.footer() }}</div>
<div class="header-again">{{ self.header() }}</div>
'@
        
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match '<div class="header">Header Content</div>'
        $result | Should -Match '<div class="footer">Footer Content</div>'
        $result | Should -Match '<div class="header-again">Header Content</div>'
    }
}

Describe "Self Variable - Error Handling" {
    It "Should throw error when calling non-existent block" {
        $template = @'
{% block existing %}Content{% endblock %}

{{ self.nonexistent() }}
'@
        
        $context = @{}
        
        # Should throw an error about block not found
        try {
            $result = Invoke-AltarTemplate -Template $template -Context $context -ErrorAction Stop
            # If we get here, the test failed
            $false | Should -Be $true -Because "Expected error for non-existent block but got result: $result"
        }
        catch {
            $_.Exception.Message | Should -Match "__BLOCK_nonexistent__"
        }
    }
    
    It "Should work in templates without blocks" {
        $template = @'
Regular template without blocks
'@
        
        $context = @{}
        
        # Should render normally (no self calls)
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match "Regular template without blocks"
    }
}

Describe "Self Variable - With Super()" {
    BeforeAll {
        # Create temporary directory for test templates
        $script:TestDir = Join-Path $TestDrive "SelfSuperTests"
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
    }
    
    It "Should work with super() in the same block" {
        # Create base template
        $baseTemplate = @'
{% block content %}
Base content
{% endblock %}

{% block title %}Base Title{% endblock %}
'@
        
        # Create child template
        $childTemplate = @'
{% extends "base_super.alt" %}

{% block content %}
{{ super() }}
Child content
Title: {{ self.title() }}
{% endblock %}

{% block title %}Child Title{% endblock %}
'@
        
        $basePath = Join-Path $script:TestDir "base_super.alt"
        $childPath = Join-Path $script:TestDir "child_super.alt"
        
        Set-Content -Path $basePath -Value $baseTemplate
        Set-Content -Path $childPath -Value $childTemplate
        
        $context = @{}
        $result = Invoke-AltarTemplate -Path $childPath -Context $context
        
        $result | Should -Match "Base content"
        $result | Should -Match "Child content"
        $result | Should -Match "Title: Child Title"
    }
}

Describe "Self Variable - Practical Use Cases" {
    It "Should work for reusable UI components" {
        $template = @'
{% block button %}<button class="btn">{{ label }}</button>{% endblock %}

<div class="toolbar">
    {% set label = "Save" %}{{ self.button() }}
    {% set label = "Cancel" %}{{ self.button() }}
    {% set label = "Delete" %}{{ self.button() }}
</div>
'@
        
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        $result | Should -Match '<button class="btn">Save</button>'
        $result | Should -Match '<button class="btn">Cancel</button>'
        $result | Should -Match '<button class="btn">Delete</button>'
    }
    
    It "Should work for table headers and footers" {
        $template = @'
{% block table_header %}
<tr>
    <th>Name</th>
    <th>Age</th>
</tr>
{% endblock %}

<table>
    <thead>{{ self.table_header() }}</thead>
    <tbody>
        <tr><td>John</td><td>30</td></tr>
    </tbody>
    <tfoot>{{ self.table_header() }}</tfoot>
</table>
'@
        
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        
        # Header should appear 3 times (1 from block definition + 2 from self calls in thead and tfoot)
        $matches = [regex]::Matches($result, "<th>Name</th>")
        $matches.Count | Should -Be 3
    }
}
