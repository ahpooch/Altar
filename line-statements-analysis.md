# Analysis of Line Statements and Line Comments Implementation in Altar

## Jinja2 Feature Overview

### Line Statements
Jinja2 allows using a special prefix (e.g., `#`) to mark lines as statements:

```jinja2
# for item in seq:
    <li>{{ item }}</li>
# endfor
```

Equivalent to:
```jinja2
{% for item in seq %}
    <li>{{ item }}</li>
{% endfor %}
```

**Features:**
1. The prefix can appear anywhere on a line, as long as there is no text before it
2. Statements can end with a colon `:` for readability
3. Support for multi-line statements with open brackets

### Line Comments
Allows using a prefix (e.g., `##`) for comments:

```jinja2
# for item in seq:
    <li>{{ item }}</li>     ## this comment is ignored
# endfor
```

## Implementation Feasibility in Altar

### ✅ CAN BE IMPLEMENTED

Yes, this functionality can be implemented in Altar. Here is why:

#### 1. Architectural Compatibility
- Altar uses a three-stage pipeline: Lexer → Parser → Compiler
- Line statements and line comments are handled at the **Lexer** stage
- The current Lexer architecture already supports states and can be extended

#### 2. Existing Analogues in Altar
Altar already has similar mechanisms:
- Whitespace trimming (`{%-` and `-%}`)
- Various token types (TEXT, BLOCK_START, COMMENT_START)
- Multi-line construct handling (raw blocks)

#### 3. Integration Points

**In the Lexer class:**
```powershell
class Lexer {
    static [string]$LINE_STATEMENT_PREFIX = $null  # e.g.: '#'
    static [string]$LINE_COMMENT_PREFIX = $null    # e.g.: '##'
    
    # New method for handling line statements
    [void]TokenizeLineStatement([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens)
    
    # New method for handling line comments
    [void]TokenizeLineComment([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens)
}
```

**In the TokenizeInitial method:**
- Check the beginning of a line for the presence of line_statement_prefix
- Check for the presence of line_comment_prefix
- Convert a line statement into regular BLOCK_START/BLOCK_END tokens

## Detailed Implementation Plan

### Stage 1: Extending the Lexer

#### 1.1 Adding Static Properties
```powershell
class Lexer {
    static [string]$LINE_STATEMENT_PREFIX = $null
    static [string]$LINE_COMMENT_PREFIX = $null
}
```

#### 1.2 Modifying TokenizeInitial
Add checks at the beginning of the method:
```powershell
[void]TokenizeInitial([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
    # Check for line comment
    if (![string]::IsNullOrEmpty([Lexer]::LINE_COMMENT_PREFIX)) {
        if ($this.CheckLineComment($state)) {
            $this.TokenizeLineComment($state, $tokens)
            return
        }
    }
    
    # Check for line statement
    if (![string]::IsNullOrEmpty([Lexer]::LINE_STATEMENT_PREFIX)) {
        if ($this.CheckLineStatement($state)) {
            $this.TokenizeLineStatement($state, $tokens)
            return
        }
    }
    
    # Existing logic...
}
```

#### 1.3 New Helper Methods

**CheckLineStatement:**
```powershell
[bool]CheckLineStatement([LexerState]$state) {
    # Check that we are at the beginning of a line or after whitespace
    if ($state.Column -eq 1 -or $this.IsAtLineStart($state)) {
        # Check for the prefix
        $prefix = [Lexer]::LINE_STATEMENT_PREFIX
        $prefixLen = $prefix.Length
        
        for ($i = 0; $i -lt $prefixLen; $i++) {
            if ($state.PeekOffset($i) -ne $prefix[$i]) {
                return $false
            }
        }
        
        return $true
    }
    
    return $false
}
```

**TokenizeLineStatement:**
```powershell
[void]TokenizeLineStatement([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
    $state.CaptureStart()
    
    # Skip the prefix
    $prefix = [Lexer]::LINE_STATEMENT_PREFIX
    for ($i = 0; $i -lt $prefix.Length; $i++) {
        $state.Consume()
    }
    
    # Skip whitespace after the prefix
    $this.SkipWhitespace($state)
    
    # Add BLOCK_START token
    $tokens.Add([Token]::new([TokenType]::BLOCK_START, '{%', $state.StartLine, $state.StartColumn, $state.Filename))
    
    # Switch to BLOCK state
    $state.States.Push("BLOCK")
    
    # Collect content until end of line
    $lineContent = ""
    $hasOpenBrackets = $false
    
    while (-not $state.IsEOF()) {
        $char = $state.Peek()
        
        # Check for open brackets for multi-line statements
        if ($char -in @('(', '[', '{')) {
            $hasOpenBrackets = $true
        }
        elseif ($char -in @(')', ']', '}')) {
            # Check if all brackets are closed
            # (requires more complex counting logic)
        }
        
        # Check for end of line
        if ($char -eq "`n" -and -not $hasOpenBrackets) {
            # Remove optional trailing colon
            if ($lineContent.TrimEnd().EndsWith(':')) {
                $lineContent = $lineContent.TrimEnd().TrimEnd(':')
            }
            
            break
        }
        
        $lineContent += $char
        $state.Consume()
    }
    
    # Tokenize the content as a regular expression
    # (create a temporary lexer to process the content)
    $tempLexer = [Lexer]::new()
    $tempState = [LexerState]::new($lineContent, $state.Filename)
    
    while (-not $tempState.IsEOF()) {
        $tempLexer.TokenizeExpression($tempState, $tokens, "BLOCK")
    }
    
    # Add BLOCK_END token
    $tokens.Add([Token]::new([TokenType]::BLOCK_END, '%}', $state.Line, $state.Column, $state.Filename))
    
    # Return to INITIAL state
    $state.States.Pop()
}
```

**CheckLineComment:**
```powershell
[bool]CheckLineComment([LexerState]$state) {
    $prefix = [Lexer]::LINE_COMMENT_PREFIX
    $prefixLen = $prefix.Length
    
    for ($i = 0; $i -lt $prefixLen; $i++) {
        if ($state.PeekOffset($i) -ne $prefix[$i]) {
            return $false
        }
    }
    
    return $true
}
```

**TokenizeLineComment:**
```powershell
[void]TokenizeLineComment([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
    # Skip the prefix
    $prefix = [Lexer]::LINE_COMMENT_PREFIX
    for ($i = 0; $i -lt $prefix.Length; $i++) {
        $state.Consume()
    }
    
    # Skip everything until end of line
    while (-not $state.IsEOF() -and $state.Peek() -ne "`n") {
        $state.Consume()
    }
    
    # Skip the newline character
    if (-not $state.IsEOF() -and $state.Peek() -eq "`n") {
        $state.Consume()
    }
    
    # No tokens are added — the comment is ignored
}
```

### Stage 2: Configuration API

#### 2.1 Adding to TemplateEngine
```powershell
class TemplateEngine {
    [string]$LineStatementPrefix
    [string]$LineCommentPrefix
    
    TemplateEngine() {
        $this.TemplateDir = ""
        $this.LineStatementPrefix = $null
        $this.LineCommentPrefix = $null
    }
    
    [string]Render([string]$template, [hashtable]$context) {
        # Set prefixes in the Lexer before tokenization
        [Lexer]::LINE_STATEMENT_PREFIX = $this.LineStatementPrefix
        [Lexer]::LINE_COMMENT_PREFIX = $this.LineCommentPrefix
        
        # Existing logic...
    }
}
```

#### 2.2 Updating Invoke-AltarTemplate
```powershell
function Invoke-AltarTemplate {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path', Position = 0)]
        [string]$Path,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Template', Position = 0)]
        [string]$Template,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [hashtable]$Context,
        
        [Parameter(Mandatory = $false)]
        [string]$LineStatementPrefix,
        
        [Parameter(Mandatory = $false)]
        [string]$LineCommentPrefix
    )
    
    $engine = [TemplateEngine]::new()
    
    if ($LineStatementPrefix) {
        $engine.LineStatementPrefix = $LineStatementPrefix
    }
    
    if ($LineCommentPrefix) {
        $engine.LineCommentPrefix = $LineCommentPrefix
    }
    
    # Existing logic...
}
```

### Stage 3: Testing

#### 3.1 Tests for Line Statements
```powershell
# Tests/Integration/LineStatements.Tests.ps1

Describe "Line Statements" {
    BeforeAll {
        . "$PSScriptRoot/../../Altar.ps1"
    }
    
    It "Should process basic line statement" {
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
        $engine.LineStatementPrefix = '#'
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '<li>Apple</li>'
        $result | Should -Match '<li>Banana</li>'
        $result | Should -Match '<li>Cherry</li>'
    }
    
    It "Should support colon at end of line statement" {
        $template = @"
# for item in items:
    {{ item }}
# endfor
"@
        
        $context = @{ items = @(1, 2, 3) }
        
        $engine = [TemplateEngine]::new()
        $engine.LineStatementPrefix = '#'
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '1'
        $result | Should -Match '2'
        $result | Should -Match '3'
    }
    
    It "Should support multiline line statements" {
        $template = @"
# for href, caption in [('index.html', 'Index'),
                        ('about.html', 'About')]:
    <a href="{{ href }}">{{ caption }}</a>
# endfor
"@
        
        $context = @{}
        
        $engine = [TemplateEngine]::new()
        $engine.LineStatementPrefix = '#'
        $result = $engine.Render($template, $context)
        
        $result | Should -Match 'index.html.*Index'
        $result | Should -Match 'about.html.*About'
    }
}
```

#### 3.2 Tests for Line Comments
```powershell
Describe "Line Comments" {
    It "Should ignore line comments" {
        $template = @"
# for item in items:
    <li>{{ item }}</li>     ## this is a comment
# endfor
"@
        
        $context = @{ items = @('Test') }
        
        $engine = [TemplateEngine]::new()
        $engine.LineStatementPrefix = '#'
        $engine.LineCommentPrefix = '##'
        $result = $engine.Render($template, $context)
        
        $result | Should -Not -Match 'this is a comment'
        $result | Should -Match '<li>Test</li>'
    }
}
```

## Challenges and Limitations

### 1. Multi-line statements
**Problem:** Requires tracking of open/closed brackets
**Solution:** Implement a bracket counter in TokenizeLineStatement

### 2. Prefix in the middle of a line
**Problem:** Jinja2 allows the prefix anywhere as long as there is no text before it
**Solution:** Verify that only whitespace precedes the prefix

### 3. Interaction with existing tokens
**Problem:** Line statements must work correctly with `{{`, `{%`, `{#`
**Solution:** Check the line statement prefix at the beginning of TokenizeInitial, before checking other tokens

### 4. Performance
**Problem:** Additional checks on every line
**Solution:** Checks are performed only if prefixes are set (not null)

## Usage Examples

### Example 1: Basic Usage
```powershell
$template = @"
<ul>
# for item in items
    <li>{{ item }}</li>
# endfor
</ul>
"@

$engine = [TemplateEngine]::new()
$engine.LineStatementPrefix = '#'

$result = $engine.Render($template, @{ items = @(1, 2, 3) })
```

### Example 2: With Comments
```powershell
$template = @"
## This is a header comment
# for item in items:  ## Loop through items
    <li>{{ item }}</li>
# endfor
"@

$engine = [TemplateEngine]::new()
$engine.LineStatementPrefix = '#'
$engine.LineCommentPrefix = '##'

$result = $engine.Render($template, @{ items = @('A', 'B') })
```

### Example 3: Using Invoke-AltarTemplate
```powershell
Invoke-AltarTemplate -Template $template -Context @{ items = @(1, 2, 3) } `
    -LineStatementPrefix '#' -LineCommentPrefix '##'
```

## Implementation Recommendations

### Priority 1 (Required)
1. ✅ Basic support for line statements with a simple prefix
2. ✅ Basic support for line comments
3. ✅ Support for optional colon at the end of a statement

### Priority 2 (Desirable)
4. ⚠️ Support for multi-line statements (with brackets)
5. ⚠️ Prefix anywhere on a line (after whitespace)

### Priority 3 (Optional)
6. ⭕ Configuration via a config file
7. ⭕ Auto-detection of prefixes from the template

## Conclusion

**Verdict: YES, it can be implemented**

The line statements and line comments functionality from Jinja2 is fully compatible with the Altar architecture and can be implemented with minimal changes to the Lexer class.

**Benefits of implementation:**
- ✅ Compatibility with Jinja2 templates
- ✅ Improved readability for certain types of templates
- ✅ Flexibility in syntax choice

**Effort estimate:**
- Basic implementation: ~4–6 hours
- Full implementation with tests: ~8–12 hours
- Documentation and examples: ~2–4 hours

**Total:** ~14–22 hours for a complete implementation
