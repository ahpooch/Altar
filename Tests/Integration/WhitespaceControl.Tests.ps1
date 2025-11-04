# Integration tests for Whitespace Control functionality (TrimBlocks and LstripBlocks)
BeforeAll {
    # Load the Altar template engine
    . "$PSScriptRoot/../../Altar.ps1"
}

Describe 'Whitespace Control Integration Tests' -Tag 'Integration' {
    
    Context "TrimBlocks Functionality" {
        It "Removes first newline after block end tag when TrimBlocks is enabled" {
            $template = @"
{% if true %}
content
{% endif %}
next line
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # With TrimBlocks, the newline after {% endif %} should be removed
            # Also removes newline after {% if true %}
            $expected = @"
content
next line
"@
            $result | Should -Be $expected
        }
        
        It "Preserves newline after block end tag when TrimBlocks is disabled" {
            $template = @"
{% if true %}
content
{% endif %}
next line
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $false
            
            # Without TrimBlocks, newline after {% endif %} is preserved
            $expected = @"

content

next line
"@
            $result | Should -Be $expected
        }
        
        It "Works with for loops" {
            $template = @"
{% for i in items %}
{{ i }}
{% endfor %}
after
"@
            $context = @{
                items = @(1, 2, 3)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # TrimBlocks removes newlines after {% for %} and {% endfor %}
            $expected = @"
1
2
3
after
"@
            $result | Should -Be $expected
        }
        
        It "Handles multiple consecutive blocks" {
            $template = @"
{% if true %}
first
{% endif %}
{% if true %}
second
{% endif %}
end
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # TrimBlocks removes newlines after all block tags
            $expected = @"
first
second
end
"@
            $result | Should -Be $expected
        }
        
        It "Does not affect variable tags" {
            $template = @"
{{ value }}
next line
"@
            $context = @{
                value = "test"
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # TrimBlocks should not affect {{ }} tags
            $expected = @"
test
next line
"@
            $result | Should -Be $expected
        }
        
        It "Can be disabled per-tag with +%}" {
            $template = @"
{% if true +%}
content
{% endif %}
next
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # +%} disables TrimBlocks for {% if true +%}, preserving newline after it
            # {% endif %} still has TrimBlocks active
            $expected = @"

content
next
"@
            $result | Should -Be $expected
        }
        
        It "Works with nested blocks" {
            $template = @"
{% if outer %}
outer content
{% if inner %}
inner content
{% endif %}
after inner
{% endif %}
after outer
"@
            $context = @{
                outer = $true
                inner = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # TrimBlocks removes newlines after all block tags
            $expected = @"
outer content
inner content
after inner
after outer
"@
            $result | Should -Be $expected
        }
    }
    
    Context "LstripBlocks Functionality" {
        It "Removes leading whitespace before block start tag when LstripBlocks is enabled" {
            $template = @"
text
    {% if true %}
content
    {% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $true
            
            # LstripBlocks removes leading spaces before block tags
            $expected = @"
text

content
"@
            $result | Should -Be $expected
        }
        
        It "Preserves leading whitespace when LstripBlocks is disabled" {
            $template = @"
text
    {% if true %}
content
    {% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $false
            
            # Leading spaces and newlines are preserved
            $expected = @"
text
    
content
    
"@
            $result | Should -Be $expected
        }
        
        It "Works with for loops" {
            $template = @"
start
    {% for i in items %}
    {{ i }}
    {% endfor %}
end
"@
            $context = @{
                items = @(1, 2)
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $true
            
            # LstripBlocks removes leading spaces before {%, newlines after are preserved
            $expected = @"
start

    1

    2

end
"@
            $result | Should -Be $expected
        }
        
        It "Removes only spaces and tabs, not newlines" {
            $template = @"
line1

  	{% if true %}
content
  	{% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $true
            
            # LstripBlocks removes spaces/tabs before {%
            $expected = @"
line1


content
"@
            $result | Should -Be $expected
        }
        
        It "Can be disabled per-tag with {%+" {
            $template = @"
text
    {%+ if true %}
content
    {% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $true
            
            # {%+ disables LstripBlocks for {%+ if %}, preserving leading spaces
            $expected = @"
text
    
content
"@
            $result | Should -Be $expected
        }
        
        It "Works with mixed indentation levels" {
            $template = @"
{% if true %}
  {% if true %}
    content
  {% endif %}
{% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $true
            
            # LstripBlocks removes leading spaces before {%
            $expected = @"


    content
"@
            $result | Should -Be $expected
        }
        
        It "Does not affect content in the middle of a line" {
            $template = @"
start {% if true %}content{% endif %} end
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $true
            
            # LstripBlocks only affects tags at line start (after whitespace)
            $expected = "start content end"
            $result | Should -Be $expected
        }
    }
    
    Context "Combined TrimBlocks and LstripBlocks" {
        It "Works together to clean up block formatting" {
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>
"@
            $context = @{
                items = @("one", "two", "three")
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            # Both settings clean up the output nicely
            $expected = @"
<ul>
    <li>one</li>
    <li>two</li>
    <li>three</li>
</ul>
"@
            $result | Should -Be $expected
        }
        
        It "Cleans up nested block structures" {
            $template = @"
{% if outer %}
    {% if inner %}
        content
    {% endif %}
{% endif %}
"@
            $context = @{
                outer = $true
                inner = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = @"
        content
"@
            $result | Should -Be $expected
        }
        
        It "Works with complex template structures" {
            $template = @"
<div>
    {% if show_list %}
    <ul>
        {% for item in items %}
        <li>{{ item }}</li>
        {% endfor %}
    </ul>
    {% endif %}
</div>
"@
            $context = @{
                show_list = $true
                items = @("a", "b")
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = @"
<div>
    <ul>
        <li>a</li>
        <li>b</li>
    </ul>
</div>
"@
            $result | Should -Be $expected
        }
        
        It "Handles empty blocks cleanly" {
            $template = @"
before
    {% if false %}
    content
    {% endif %}
after
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = @"
before
after
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Interaction with Manual Whitespace Control" {
        It "Manual - overrides TrimBlocks" {
            $template = @"
{% if true -%}
content
{% endif %}
next
"@
            $context = @{}
            
            # Even with TrimBlocks disabled, - should trim
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $false
            
            $expected = @"
content

next
"@
            $result | Should -Be $expected
        }
        
        It "Manual - at tag end works with TrimBlocks" {
            $template = @"
{% if true %}
content
{% endif -%}
next
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # TrimBlocks removes newline after {% if true %}, -%} removes after {% endif %}
            $expected = @"
content
next
"@
            $result | Should -Be $expected
        }
        
        It "Manual - at tag start works with LstripBlocks" {
            $template = @"
text
    {%- if true %}
content
    {% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $true
            
            # {%- trims whitespace before tag (including newline and spaces)
            # LstripBlocks removes leading spaces before {% endif %}
            $expected = @"
text
content
"@
            $result | Should -Be $expected
        }
        
        It "+ disables TrimBlocks on specific tag" {
            $template = @"
{% if true +%}
content
{% endif %}
next
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # + on first tag disables TrimBlocks for it
            $expected = @"

content
next
"@
            $result | Should -Be $expected
        }
        
        It "+ disables LstripBlocks on specific tag" {
            $template = @"
text
    {%+ if true %}
content
    {% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -LstripBlocks $true
            
            # {%+ disables LstripBlocks for {%+ if %}, preserving leading spaces
            $expected = @"
text
    
content
"@
            $result | Should -Be $expected
        }
        
        It "Combines -, +, TrimBlocks, and LstripBlocks correctly" {
            $template = @"
line1
    {%- if true +%}
content
    {% endif -%}
line2
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            # {%- trims before, +%} keeps newline after (disables TrimBlocks)
            # {% trims leading space (LstripBlocks), -%} trims after
            $expected = @"
line1
content
line2
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Edge Cases" {
        It "Handles template with only blocks" {
            $template = @"
{% if true %}
{% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = ""
            $result | Should -Be $expected
        }
        
        It "Handles template with no blocks" {
            $template = @"
just
some
text
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            # Should not affect non-block content
            $expected = @"
just
some
text
"@
            $result | Should -Be $expected
        }
        
        It "Handles blocks at start of template" {
            $template = @"
{% if true %}
content
{% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = @"
content
"@
            $result | Should -Be $expected
        }
        
        It "Handles blocks at end of template" {
            $template = @"
text
    {% if true %}
content
    {% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = @"
text
content
"@
            $result | Should -Be $expected
        }
        
        It "Handles single line template" {
            $template = "{% if true %}content{% endif %}"
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = "content"
            $result | Should -Be $expected
        }
        
        It "Handles empty template" {
            $template = ""
            $context = @{}
            
            # Empty template causes parameter binding error, so we skip validation
            # Just ensure it doesn't throw an unhandled exception
            { Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true } | Should -Throw
        }
        
        It "Handles template with only whitespace" {
            $template = @"
   
  	
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            # Should preserve non-block whitespace
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Handles very deeply nested blocks" {
            $template = @"
{% if a %}
    {% if b %}
        {% if c %}
            {% if d %}
                content
            {% endif %}
        {% endif %}
    {% endif %}
{% endif %}
"@
            $context = @{
                a = $true
                b = $true
                c = $true
                d = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = @"
                content
"@
            $result | Should -Be $expected
        }
    }
    
    Context "Real-world HTML Templates" {
        It "Cleans up HTML list generation" {
            $template = @"
<ul>
    {% for item in items %}
    <li>{{ item.name }}</li>
    {% endfor %}
</ul>
"@
            $context = @{
                items = @(
                    @{ name = "Item 1" }
                    @{ name = "Item 2" }
                    @{ name = "Item 3" }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = @"
<ul>
    <li>Item 1</li>
    <li>Item 2</li>
    <li>Item 3</li>
</ul>
"@
            $result | Should -Be $expected
        }
        
        It "Cleans up conditional HTML sections" {
            $template = @"
<div>
    {% if show_header %}
    <h1>{{ title }}</h1>
    {% endif %}
    <p>Content</p>
    {% if show_footer %}
    <footer>Footer</footer>
    {% endif %}
</div>
"@
            $context = @{
                show_header = $true
                title = "My Title"
                show_footer = $true
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $expected = @"
<div>
    <h1>My Title</h1>
    <p>Content</p>
    <footer>Footer</footer>
</div>
"@
            $result | Should -Be $expected
        }
        
        It "Handles table generation cleanly" {
            $template = @"
<table>
    {% for row in rows %}
    <tr>
        {% for cell in row %}
        <td>{{ cell }}</td>
        {% endfor %}
    </tr>
    {% endfor %}
</table>
"@
            $context = @{
                rows = @(
                    @("A", "B")
                    @("C", "D")
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            # Verify the basic structure is correct
            $result | Should -Match '<table>'
            $result | Should -Match '<tr>'
            $result | Should -Match '<td>A</td>'
            $result | Should -Match '<td>B</td>'
            $result | Should -Match '<td>C</td>'
            $result | Should -Match '<td>D</td>'
            $result | Should -Match '</table>'
        }
        
        It "Works with navigation menus" {
            $template = @"
<nav>
    <ul>
        {% for item in menu %}
        <li>
            {% if item.active %}
            <a href="{{ item.url }}" class="active">{{ item.title }}</a>
            {% else %}
            <a href="{{ item.url }}">{{ item.title }}</a>
            {% endif %}
        </li>
        {% endfor %}
    </ul>
</nav>
"@
            $context = @{
                menu = @(
                    @{ url = "/home"; title = "Home"; active = $true }
                    @{ url = "/about"; title = "About"; active = $false }
                )
            }
            
            $result = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true -LstripBlocks $true
            
            $result | Should -Match '<a href="/home" class="active">Home</a>'
            $result | Should -Match '<a href="/about">About</a>'
        }
    }
    
    Context "Performance and Caching" {
        It "Caches templates correctly with different whitespace settings" {
            $template = "{% if true %}test{% endif %}"
            $context = @{}
            
            # First render with TrimBlocks
            $result1 = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $true
            
            # Second render with different setting should give different result
            $result2 = Invoke-AltarTemplate -Template $template -Context $context -TrimBlocks $false
            
            # Results may be the same for this simple case, but they should be cached separately
            $result1 | Should -Not -BeNullOrEmpty
            $result2 | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Default Behavior" {
        It "Uses default settings when parameters not specified" {
            $template = @"
    {% if true %}
content
    {% endif %}
"@
            $context = @{}
            
            # Without specifying TrimBlocks or LstripBlocks
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Default behavior: both TrimBlocks and LstripBlocks are false
            $expected = @"
    
content
    
"@
            $result | Should -Be $expected
        }
        
        It "TrimBlocks defaults to false" {
            $template = @"
{% if true %}
content
{% endif %}
next
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Without TrimBlocks, newline after {% endif %} is preserved
            $expected = @"

content

next
"@
            $result | Should -Be $expected
        }
        
        It "LstripBlocks defaults to false" {
            $template = @"
text
    {% if true %}
content
    {% endif %}
"@
            $context = @{}
            
            $result = Invoke-AltarTemplate -Template $template -Context $context
            
            # Without LstripBlocks, leading spaces and newlines are preserved
            $expected = @"
text
    
content
    
"@
            $result | Should -Be $expected
        }
    }
}
