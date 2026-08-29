# Integration tests for filters functionality — enhanced with Jinja2 Oracle validation

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

Describe "String Filters" {
    It "string filter should convert number to string" {
        $template = '{{ value | string }}'
        $context = @{ value = 123 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "123"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "string filter should convert boolean to string" {
        $template = '{{ value | string }}'
        $context = @{ value = $true }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "True"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "string filter should convert null to 'None'" {
        $template = '{{ value | string }}'
        $context = @{ value = $null }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "None"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "string filter should handle string input unchanged" {
        $template = '{{ value | string }}'
        $context = @{ value = "hello world" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "hello world"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "capitalize filter should capitalize first letter" {
        $template = '{{ "hello world" | capitalize }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "Hello world"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "upper filter should convert to uppercase" {
        $template = '{{ "hello world" | upper }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "HELLO WORLD"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "lower filter should convert to lowercase" {
        $template = '{{ "HELLO WORLD" | lower }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "hello world"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "title filter should convert to title case" {
        $template = '{{ "hello world" | title }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "Hello World"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "trim filter should remove whitespace" {
        $template = '{{ "  hello  " | trim }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "hello"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "replace filter should replace substring" {
        $template = '{{ "hello world" | replace("world", "universe") }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "hello universe"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "center filter should center text" {
        $template = '{{ "test" | center(10) }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "   test   "
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "ljust filter should left-justify text" {
        $template = '{{ "test" | ljust(10) }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "test      "
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "rjust filter should right-justify text" {
        $template = '{{ "test" | rjust(10) }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "      test"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "reverse filter should reverse string" {
        $template = '{{ "hello" | reverse }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "olleh"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "striptags filter should remove HTML tags" {
        $template = '{{ "<p>Hello</p>" | striptags }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "Hello"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "truncate filter should truncate long text" {
        $template = '{{ "This is a very long text" | truncate(10) }}'
        $result = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Match "^This.*\.\.\.$"
    }
    
    It "wordcount filter should count words" {
        $template = '{{ "This is a test" | wordcount }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "4"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "replace filter should replace only first occurrence with count=1" {
        $template = '{{ text | replace("a", "X", 1) }}'
        $context = @{ text = "banana" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnana"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "replace filter should replace first two occurrences with count=2" {
        $template = '{{ text | replace("a", "X", 2) }}'
        $context = @{ text = "banana" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnXna"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "replace filter should replace all when count exceeds occurrences" {
        $template = '{{ text | replace("a", "X", 10) }}'
        $context = @{ text = "banana" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnXnX"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "replace filter should handle count=0 as replace all" {
        $template = '{{ text | replace("a", "X", 0) }}'
        $context = @{ text = "banana" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnXnX"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "replace filter should handle negative count as replace all" {
        $template = '{{ text | replace("a", "X", count) }}'
        $context = @{ text = "banana"; count = -1 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "bXnXnX"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "replace filter should handle multi-character replacements with count" {
        $template = '{{ text | replace("Hello", "Goodbye", 1) }}'
        $context = @{ text = "Hello World Hello Universe" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "Goodbye World Hello Universe"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}

Describe "Escape Filters" {
    It "escape filter should escape HTML" {
        $template = '{{ "<script>alert(''xss'')</script>" | escape }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "urlencode filter should URL encode" {
        $template = '{{ "hello world" | urlencode }}'
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "hello%20world"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}

Describe "List Filters" {
    It "first filter should get first element" {
        $template = '{{ items | first }}'
        $context = @{ items = @(1, 2, 3) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "1"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "last filter should get last element" {
        $template = '{{ items | last }}'
        $context = @{ items = @(1, 2, 3) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "3"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "join filter should join array elements" {
        $template = '{{ items | join(", ") }}'
        $context = @{ items = @("a", "b", "c") }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "a, b, c"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "length filter should get array length" {
        $template = '{{ items | length }}'
        $context = @{ items = @(1, 2, 3) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "3"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "reverse filter should reverse array" {
        $template = '{{ items | reverse | join(",") }}'
        $context = @{ items = @(1, 2, 3) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "3,2,1"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "sort filter should sort array" {
        $template = '{{ items | sort | join(",") }}'
        $context = @{ items = @(3, 1, 2) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "1,2,3"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "unique filter should get unique elements" {
        $template = '{{ items | unique | join(",") }}'
        $context = @{ items = @(1, 2, 2, 3, 1) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "1,2,3"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "sum filter should sum numeric values" {
        $template = '{{ items | sum }}'
        $context = @{ items = @(1, 2, 3, 4, 5) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "15"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "min filter should get minimum value" {
        $template = '{{ items | min }}'
        $context = @{ items = @(5, 2, 8, 1, 9) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "1"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "max filter should get maximum value" {
        $template = '{{ items | max }}'
        $context = @{ items = @(5, 2, 8, 1, 9) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "9"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}

Describe "Number Filters" {
    It "abs filter should get absolute value" {
        $template = '{{ num | abs }}'
        $context = @{ num = -5 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "5"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "int filter should convert to integer" {
        $template = '{{ val | int }}'
        $context = @{ val = "42" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "42"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "float filter should convert to float" {
        $template = '{{ val | float }}'
        $context = @{ val = "3.14" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "3.14"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "round filter should round number" {
        $template = '{{ num | round(2) }}'
        $context = @{ num = 3.14159 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "3.14"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
        $context = @{ dict = @{ name = "John"; age = 30 } }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "John"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}

Describe "Conversion Filters" {
    It "list filter should convert to array" {
        $template = '{{ val | list | length }}'
        $context = @{ val = "hello" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "5"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
        $context = @{ val = $null }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "N/A"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "default filter should not replace non-null value" {
        $template = '{{ val | default("N/A") }}'
        $context = @{ val = "test" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "test"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "HELLO UNIVERSE"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "should support filters with variables" {
        $template = '{{ name | upper | default("UNKNOWN") }}'
        $context = @{ name = "john" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "JOHN"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
    
    It "should chain string filter with other filters" {
        $template = '{{ value | string | upper }}'
        $context = @{ value = 123 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "123"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
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
