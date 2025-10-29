# Integration tests for Jinja2 filters in Altar template engine

BeforeAll {
    # Load the Altar template engine
    . "$PSScriptRoot/../../Altar.ps1"
}

Describe "String Filters" {
    It "string filter should convert number to string" {
        $template = '{{ value | string }}'
        $context = @{ value = 123 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "123"
    }
    
    It "string filter should convert boolean to string" {
        $template = '{{ value | string }}'
        $context = @{ value = $true }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "True"
    }
    
    It "string filter should convert null to empty string" {
        $template = '{{ value | string }}'
        $context = @{ value = $null }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be ""
    }
    
    It "string filter should handle string input unchanged" {
        $template = '{{ value | string }}'
        $context = @{ value = "hello world" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "hello world"
    }
    
    It "capitalize filter should capitalize first letter" {
        $template = '{{ "hello world" | capitalize }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "Hello world"
    }
    
    It "upper filter should convert to uppercase" {
        $template = '{{ "hello world" | upper }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "HELLO WORLD"
    }
    
    It "lower filter should convert to lowercase" {
        $template = '{{ "HELLO WORLD" | lower }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "hello world"
    }
    
    It "title filter should convert to title case" {
        $template = '{{ "hello world" | title }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "Hello World"
    }
    
    It "trim filter should remove whitespace" {
        $template = '{{ "  hello  " | trim }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "hello"
    }
    
    It "replace filter should replace substring" {
        $template = '{{ "hello world" | replace("world", "universe") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "hello universe"
    }
    
    It "center filter should center text" {
        $template = '{{ "test" | center(10) }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "   test   "
    }
    
    It "ljust filter should left-justify text" {
        $template = '{{ "test" | ljust(10) }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "test      "
    }
    
    It "rjust filter should right-justify text" {
        $template = '{{ "test" | rjust(10) }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "      test"
    }
    
    It "reverse filter should reverse string" {
        $template = '{{ "hello" | reverse }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "olleh"
    }
    
    It "striptags filter should remove HTML tags" {
        $template = '{{ "<p>Hello</p>" | striptags }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "Hello"
    }
    
    It "truncate filter should truncate long text" {
        $template = '{{ "This is a very long text" | truncate(10) }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Match "^This.*\.\.\.$"
    }
    
    It "wordcount filter should count words" {
        $template = '{{ "This is a test" | wordcount }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "4"
    }
    
    It "urlize filter should convert simple HTTP URL to link" {
        $template = '{{ text | urlize }}'
        $context = @{ text = "Visit http://example.com for more info" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match '<a href="http://example.com">http://example.com</a>'
    }
    
    It "urlize filter should convert HTTPS URL to link" {
        $template = '{{ text | urlize }}'
        $context = @{ text = "Check out https://github.com/ahpooch/Altar" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match '<a href="https://github.com/ahpooch/Altar">https://github.com/ahpooch/Altar</a>'
    }
    
    It "urlize filter should convert www URL to link with http prefix" {
        $template = '{{ text | urlize }}'
        $context = @{ text = "Go to www.example.com" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match '<a href="http://www.example.com">www.example.com</a>'
    }
    
    It "urlize filter should handle multiple URLs in text" {
        $template = '{{ text | urlize }}'
        $context = @{ text = "Visit http://example.com and https://github.com" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match '<a href="http://example.com">http://example.com</a>'
        $result | Should -Match '<a href="https://github.com">https://github.com</a>'
    }
    
    It "urlize filter should trim URL display with limit parameter" {
        $template = '{{ text | urlize(20) }}'
        $context = @{ text = "Visit https://github.com/ahpooch/Altar/blob/main/README.md" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match 'https://github.com/a...'
    }
    
    It "urlize filter should add nofollow attribute when specified" {
        $template = '{{ text | urlize(null, true) }}'
        $context = @{ text = "Visit http://example.com" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match 'rel="nofollow"'
    }
    
    It "urlize filter should add target attribute when specified" {
        $template = '{{ text | urlize(null, false, "_blank") }}'
        $context = @{ text = "Visit http://example.com" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match 'target="_blank"'
    }
    
    It "urlize filter should handle text without URLs unchanged" {
        $template = '{{ text | urlize }}'
        $context = @{ text = "This is just plain text without any links" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "This is just plain text without any links"
    }
    
    It "urlize filter should preserve surrounding text" {
        $template = '{{ text | urlize }}'
        $context = @{ text = "Before http://example.com after" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match '^Before <a href="http://example.com">http://example.com</a> after$'
    }
    
    It "replace filter should replace all occurrences without count parameter" {
        $template = '{{ text | replace("a", "X") }}'
        $context = @{ text = "banana" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnXnX"
    }
    
    It "replace filter should replace only first occurrence with count=1" {
        $template = '{{ text | replace("a", "X", 1) }}'
        $context = @{ text = "banana" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnana"
    }
    
    It "replace filter should replace first two occurrences with count=2" {
        $template = '{{ text | replace("a", "X", 2) }}'
        $context = @{ text = "banana" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnXna"
    }
    
    It "replace filter should replace all when count exceeds occurrences" {
        $template = '{{ text | replace("a", "X", 10) }}'
        $context = @{ text = "banana" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnXnX"
    }
    
    It "replace filter should handle count=0 as replace all" {
        $template = '{{ text | replace("a", "X", 0) }}'
        $context = @{ text = "banana" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnXnX"
    }
    
    It "replace filter should handle negative count as replace all" {
        $template = '{{ text | replace("a", "X", count) }}'
        $context = @{ text = "banana"; count = -1 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnXnX"
    }
    
    It "replace filter should handle multi-character replacements with count" {
        $template = '{{ text | replace("Hello", "Goodbye", 1) }}'
        $context = @{ text = "Hello World Hello Universe" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "Goodbye World Hello Universe"
    }
}

Describe "Escape Filters" {
    It "escape filter should escape HTML" {
        $template = '{{ "<script>alert(''xss'')</script>" | escape }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
    }
    
    It "urlencode filter should URL encode" {
        $template = '{{ "hello world" | urlencode }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "hello%20world"
    }
}

Describe "List Filters" {
    It "first filter should get first element" {
        $template = '{{ items | first }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @(1, 2, 3) }
        $result | Should -Be "1"
    }
    
    It "last filter should get last element" {
        $template = '{{ items | last }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @(1, 2, 3) }
        $result | Should -Be "3"
    }
    
    It "join filter should join array elements" {
        $template = '{{ items | join(", ") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @("a", "b", "c") }
        $result | Should -Be "a, b, c"
    }
    
    It "length filter should get array length" {
        $template = '{{ items | length }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @(1, 2, 3) }
        $result | Should -Be "3"
    }
    
    It "reverse filter should reverse array" {
        $template = '{{ items | reverse | join(",") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @(1, 2, 3) }
        $result | Should -Be "3,2,1"
    }
    
    It "sort filter should sort array" {
        $template = '{{ items | sort | join(",") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @(3, 1, 2) }
        $result | Should -Be "1,2,3"
    }
    
    It "unique filter should get unique elements" {
        $template = '{{ items | unique | join(",") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @(1, 2, 2, 3, 1) }
        $result | Should -Be "1,2,3"
    }
    
    It "sum filter should sum numeric values" {
        $template = '{{ items | sum }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @(1, 2, 3, 4, 5) }
        $result | Should -Be "15"
    }
    
    It "min filter should get minimum value" {
        $template = '{{ items | min }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @(5, 2, 8, 1, 9) }
        $result | Should -Be "1"
    }
    
    It "max filter should get maximum value" {
        $template = '{{ items | max }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ items = @(5, 2, 8, 1, 9) }
        $result | Should -Be "9"
    }
}

Describe "Number Filters" {
    It "abs filter should get absolute value" {
        $template = '{{ num | abs }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ num = -5 }
        $result | Should -Be "5"
    }
    
    It "int filter should convert to integer" {
        $template = '{{ val | int }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ val = "42" }
        $result | Should -Be "42"
    }
    
    It "float filter should convert to float" {
        $template = '{{ val | float }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ val = "3.14" }
        $result | Should -Be "3.14"
    }
    
    It "round filter should round number" {
        $template = '{{ num | round(2) }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ num = 3.14159 }
        $result | Should -Be "3.14"
    }
}

Describe "Dictionary Filters" {
    It "items filter should get key-value pairs" {
        $template = '{% for pair in dict | items %}{{ pair[0] }}:{{ pair[1] }} {% endfor %}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ dict = @{ name = "John"; age = 30 } }
        $result | Should -Match "name:John"
        $result | Should -Match "age:30"
    }
    
    It "attr filter should get attribute value" {
        $template = '{{ dict | attr("name") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ dict = @{ name = "John"; age = 30 } }
        $result | Should -Be "John"
    }
}

Describe "Conversion Filters" {
    It "list filter should convert to array" {
        $template = '{{ val | list | length }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ val = "hello" }
        $result | Should -Be "5"
    }
    
    It "tojson filter should convert to JSON" {
        $template = '{{ dict | tojson }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ dict = @{ name = "John" } }
        $result | Should -Match '"name"'
        $result | Should -Match '"John"'
    }
}

Describe "Other Filters" {
    It "default filter should provide default value for null" {
        $template = '{{ val | default("N/A") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ val = $null }
        $result | Should -Be "N/A"
    }
    
    It "default filter should not replace non-null value" {
        $template = '{{ val | default("N/A") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ val = "test" }
        $result | Should -Be "test"
    }
    
    It "filesizeformat filter should format bytes" {
        $template = '{{ size | filesizeformat }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ size = 1024 }
        $result | Should -Match "1\.0 kB"
    }
    
    It "filesizeformat filter should format bytes in binary" {
        $template = '{{ size | filesizeformat(true) }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ size = 1024 }
        $result | Should -Match "1\.0 KiB"
    }
    
    It "xmlattr filter should generate XML attributes" {
        $template = '<div{{ attrs | xmlattr }}></div>'
        $result = Invoke-AltarTemplate -Template $template -Context @{ attrs = @{ class = "btn"; id = "submit" } }
        $result | Should -Match 'class="btn"'
        $result | Should -Match 'id="submit"'
    }
}

Describe "Filter Chaining" {
    It "should support chaining multiple filters" {
        $template = '{{ "  hello world  " | trim | upper | replace("WORLD", "UNIVERSE") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be "HELLO UNIVERSE"
    }
    
    It "should support filters with variables" {
        $template = '{{ name | upper | default("UNKNOWN") }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{ name = "john" }
        $result | Should -Be "JOHN"
    }
    
    It "should chain string filter with other filters" {
        $template = '{{ value | string | upper }}'
        $context = @{ value = 123 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "123"
    }
    
    It "should chain urlize with other filters" {
        $template = '{{ text | urlize | upper }}'
        $context = @{ text = "visit http://example.com" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match 'VISIT.*<A HREF="HTTP://EXAMPLE.COM">HTTP://EXAMPLE.COM</A>'
    }
    
    It "should use replace with count in complex template" {
        $template = @'
{% for item in items %}
{{ item | replace("a", "*", 1) }}
{% endfor %}
'@
        $context = @{ items = @("apple", "banana", "avocado") }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match '\*pple'
        $result | Should -Match 'b\*nana'
        $result | Should -Match '\*vocado'
    }
}

Describe "Real-World Use Cases" {
    It "should format user bio with clickable links" {
        $template = @'
<div class="bio">
{{ bio | urlize(50, true, "_blank") }}
</div>
'@
        $context = @{ 
            bio = "Check out my projects at https://github.com/username and visit my blog at http://myblog.com"
        }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match 'target="_blank"'
        $result | Should -Match 'rel="nofollow"'
        $result | Should -Match 'https://github.com/username'
    }
    
    It "should sanitize and format user input" {
        $template = '{{ input | string | escape | truncate(50) }}'
        $context = @{ 
            input = "<script>alert('xss')</script>This is a very long text that should be truncated"
        }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match '&lt;script&gt;'
        $result | Should -Match '\.\.\.$'
    }
    
    It "should perform limited text replacements in template" {
        $template = @'
Original: {{ text }}
First replacement: {{ text | replace("the", "THE", 1) }}
All replacements: {{ text | replace("the", "THE") }}
'@
        $context = @{ text = "the quick brown fox jumps over the lazy dog near the river" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Match 'First replacement: THE quick brown fox jumps over the lazy dog near the river'
        $result | Should -Match 'All replacements: THE quick brown fox jumps over THE lazy dog near THE river'
    }
}
