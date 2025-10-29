# Enum defining behavior for undefined variables (Jinja2 compatibility)
enum UndefinedBehavior {
    Default          # Return empty string for undefined variables (Jinja2 default)
    Strict           # Throw exception when accessing undefined variables
    Debug            # Return placeholder string like {{ variable_name }}
    Chainable        # Allow chaining on undefined variables without errors
}

# Class representing template environment settings (Jinja2 compatibility)
class TemplateEnvironment {
    [UndefinedBehavior]$UndefinedBehavior = [UndefinedBehavior]::Default
    
    TemplateEnvironment() {
        $this.UndefinedBehavior = [UndefinedBehavior]::Default
    }
}

# Enum defining all possible token types used in the template lexer
# These token types represent the different elements that can be found in a template
enum TokenType {
    TEXT            # Regular text content in the template
    VARIABLE_START  # Start of a variable expression {{ 
    VARIABLE_END    # End of a variable expression }}
    BLOCK_START     # Start of a block expression {%
    BLOCK_END       # End of a block expression %}
    COMMENT_START   # Start of a comment {#
    COMMENT_END     # End of a comment #}
    IDENTIFIER      # Variable or function name
    STRING          # String literal
    NUMBER          # Numeric literal
    PUNCTUATION     # Punctuation characters like (), [], {}, etc.
    OPERATOR        # Operators like +, -, *, /, etc.
    KEYWORD         # Reserved keywords like if, for, else, etc.
    PIPE            # Pipe character | used before filters
    FILTER          # Template filters
    DOT             # Dot character . used for property access
    RAW_CONTENT     # Raw block content (preserved as-is)
    EOF             # End of file marker
}

# Class representing a token in the template language
# Tokens are the basic building blocks of the template syntax
class Token {
    [TokenType]$Type     # The type of token (from TokenType enum)
    [string]$Value       # The actual text value of the token
    [int]$Line           # Line number where the token appears (for error reporting)
    [int]$Column         # Column number where the token appears (for error reporting)
    [string]$Filename    # Source filename where the token was found
    
    # Constructor to initialize a token with all its properties
    Token([TokenType]$type, [string]$value, [int]$line, [int]$column, [string]$filename) {
        $this.Type = $type
        $this.Value = $value
        $this.Line = $line
        $this.Column = $column
        $this.Filename = $filename
    }
    
    # String representation of the token for debugging
    [string]ToString() {
        return "Token($($this.Type), '$($this.Value)', line=$($this.Line), col=$($this.Column))"
    }
}

# Class that maintains the state of the lexer during tokenization
# Tracks position in the text, line/column numbers, and lexer states
class LexerState {
    [string]$Text                                      # The full template text being processed
    [int]$Position                                     # Current position in the text
    [int]$Line                                         # Current line number (for error reporting)
    [int]$Column                                       # Current column number (for error reporting)
    [int]$StartLine                                    # Line number at the start of current token
    [int]$StartColumn                                  # Column number at the start of current token
    [string]$Filename                                  # Source filename
    [System.Collections.Generic.Stack[string]]$States  # Stack of lexer states (INITIAL, VARIABLE, BLOCK, COMMENT)
    
    # Constructor initializes the lexer state with the template text
    LexerState([string]$text, [string]$filename) {
        $this.Text = $text
        $this.Position = 0
        $this.Line = 1
        $this.Column = 1
        $this.StartLine = 1
        $this.StartColumn = 1
        $this.Filename = $filename
        $this.States = [System.Collections.Generic.Stack[string]]::new()
        $this.States.Push("INITIAL")  # Start in the INITIAL state
    }
    
    # Capture the current position as the start of a new token
    [void]CaptureStart() {
        $this.StartLine = $this.Line
        $this.StartColumn = $this.Column
    }
    
    # Check if we've reached the end of the template text
    [bool]IsEOF() {
        return $this.Position -ge $this.Text.Length
    }
    
    # Look at the current character without consuming it
    [char]Peek() {
        return $this.PeekOffset(0)
    }
    
    # Look ahead at a character at a specific offset without consuming it
    [char]PeekOffset([int]$offset) {
        $pos = $this.Position + $offset
        if ($pos -ge $this.Text.Length) {
            return [char]0  # Return null character if beyond text length
        }
        return $this.Text[$pos]
    }
    
    # Consume and return the current character, advancing position
    # Also updates line and column numbers for error reporting
    [char]Consume() {
        if ($this.IsEOF()) {
            return [char]0  # Return null character if at end of file
        }
        
        $char = $this.Text[$this.Position]
        $this.Position++
        
        # Update line and column tracking
        if ($char -eq "`n") {
            $this.Line++
            $this.Column = 1  # Reset column at line breaks
        }
        else {
            $this.Column++
        }
        
        return $char
    }
}

# Lexer class responsible for breaking template text into tokens
# This is the first stage of template processing (tokenization)
class Lexer {
    # Template syntax delimiters
    static [string]$VARIABLE_START = '{{'    # Start of variable expression
    static [string]$VARIABLE_END = '}}'      # End of variable expression
    static [string]$VARIABLE_START_TRIM = '{{-' # Start of variable with whitespace trimming
    static [string]$VARIABLE_END_TRIM = '-}}'   # End of variable with whitespace trimming
    static [string]$BLOCK_START = '{%'       # Start of block expression
    static [string]$BLOCK_END = '%}'         # End of block expression
    static [string]$BLOCK_START_TRIM = '{%-' # Start of block with whitespace trimming
    static [string]$BLOCK_END_TRIM = '-%}'   # End of block with whitespace trimming
    static [string]$COMMENT_START = '{#'     # Start of comment
    static [string]$COMMENT_END = '#}'       # End of comment
    static [string]$PIPE = '|'               # Pipe before filter
    
    # Line statement and comment prefixes (Jinja2 compatibility)
    static [string]$LINE_STATEMENT_PREFIX = $null  # e.g., '#' for line statements
    static [string]$LINE_COMMENT_PREFIX = $null    # e.g., '##' for line comments
    
    # Reserved keywords in the template language
    static [hashtable]$KEYWORDS = @{
        'if'      = $true   # Conditional blocks
        'for'     = $true   # Loop blocks
        'else'    = $true   # Alternative conditional branch
        'elif'    = $true   # Else-if conditional branch
        'endif'   = $true   # End of conditional block
        'endfor'  = $true   # End of loop block
        'in'      = $true   # Used in for loops and membership tests
        'is'      = $true   # Used for type/state tests
        'and'     = $true   # Logical AND operator
        'or'      = $true   # Logical OR operator
        'not'     = $true   # Logical NOT operator
        'true'    = $true   # Boolean literal
        'false'   = $true   # Boolean literal
        'null'    = $true   # Null literal
        'none'    = $true   # Null literal (alias)
        'extends' = $true   # Template inheritance
        'block'   = $true   # Template block definition
        'endblock'= $true   # End of template block
        'include' = $true   # Include another template
        'raw'     = $true   # Raw block (no processing)
        'endraw'  = $true   # End of raw block
        'super'   = $true   # Call parent block content
        'powershell' = $true  # PowerShell execution block
        'endpowershell' = $true  # End of PowerShell block
        'catch'   = $true   # Catch block for error handling
        'set'     = $true   # Variable assignment
        'defined' = $true   # Test: variable is defined
        'even'    = $true   # Test: number is even
        'odd'     = $true   # Test: number is odd
        'macro'   = $true   # Macro definition
        'endmacro'= $true   # End of macro definition
        'call'    = $true   # Call block with caller
        'endcall' = $true   # End of call block
        'import'  = $true   # Import macros from template
        'from'    = $true   # From clause for imports
    }
    
    # Main tokenization method that converts template text into a list of tokens
    # This is the entry point for the lexical analysis process
    [System.Collections.Generic.List[Token]]Tokenize([string]$text, [string]$filename) {
        # Initialize lexer state with the template text
        $state = [LexerState]::new($text, $filename)
        $tokens = [System.Collections.Generic.List[Token]]::new()
        
        # Process the template until we reach the end
        while (-not $state.IsEOF()) {
            # Get the current lexer state (INITIAL, VARIABLE, BLOCK, COMMENT, RAW_BLOCK)
            $currentState = $state.States.Peek()
            
            # Call the appropriate tokenization method based on the current state
            switch ($currentState) {
                "INITIAL" { $this.TokenizeInitial($state, $tokens) }  # Processing regular text
                "VARIABLE" { $this.TokenizeExpression($state, $tokens, "VARIABLE") }  # Inside {{ ... }}
                "BLOCK" { $this.TokenizeExpression($state, $tokens, "BLOCK") }  # Inside {% ... %}
                "COMMENT" { $this.TokenizeComment($state, $tokens) }  # Inside {# ... #}
                "RAW_BLOCK" { $this.TokenizeRawBlock($state, $tokens) }  # Inside {% raw %} ... {% endraw %}
                default { throw "Unknown lexer state: $currentState" }
            }
        }
        
        # Add an EOF token to mark the end of the template
        $tokens.Add([Token]::new([TokenType]::EOF, "", $state.Line, $state.Column, $filename))
        return $tokens
    }
    
    # Check if we're at the start of a line (only whitespace before current position on this line)
    [bool]IsAtLineStart([LexerState]$state) {
        # If we're at position 0, we're at the start
        if ($state.Position -eq 0) {
            return $true
        }
        
        # Check backwards from current position to find if we're at line start
        $pos = $state.Position - 1
        while ($pos -ge 0) {
            $c = $state.Text[$pos]
            if ($c -eq "`n") {
                return $true  # Found newline, we're at line start
            }
            if ($c -ne ' ' -and $c -ne "`t" -and $c -ne "`r") {
                return $false  # Found non-whitespace, not at line start
            }
            $pos--
        }
        return $true  # Reached start of file, we're at line start
    }
    
    # Check if current position matches line statement prefix
    [bool]CheckLineStatement([LexerState]$state) {
        # Line statement prefix must be set
        if ([string]::IsNullOrEmpty([Lexer]::LINE_STATEMENT_PREFIX)) {
            return $false
        }
        
        # Must be at line start (beginning of file or after whitespace following newline)
        if (-not $this.IsAtLineStart($state)) {
            return $false
        }
        
        # Skip leading whitespace to find the prefix
        $offset = 0
        while ($state.PeekOffset($offset) -eq ' ' -or $state.PeekOffset($offset) -eq "`t") {
            $offset++
        }
        
        # Check if prefix matches at the offset position
        $prefix = [Lexer]::LINE_STATEMENT_PREFIX
        for ($i = 0; $i -lt $prefix.Length; $i++) {
            if ($state.PeekOffset($offset + $i) -ne $prefix[$i]) {
                return $false
            }
        }
        
        # Make sure it's not a line comment (if line comment prefix is longer)
        if (![string]::IsNullOrEmpty([Lexer]::LINE_COMMENT_PREFIX)) {
            $commentPrefix = [Lexer]::LINE_COMMENT_PREFIX
            if ($commentPrefix.StartsWith($prefix) -and $commentPrefix.Length -gt $prefix.Length) {
                # Check if this is actually a comment
                $isComment = $true
                for ($i = 0; $i -lt $commentPrefix.Length; $i++) {
                    if ($state.PeekOffset($i) -ne $commentPrefix[$i]) {
                        $isComment = $false
                        break
                    }
                }
                if ($isComment) {
                    return $false  # This is a comment, not a statement
                }
            }
        }
        
        return $true
    }
    
    # Check if current position matches line comment prefix
    [bool]CheckLineComment([LexerState]$state) {
        # Line comment prefix must be set
        if ([string]::IsNullOrEmpty([Lexer]::LINE_COMMENT_PREFIX)) {
            return $false
        }
        
        # Check if prefix matches (can be anywhere on the line for inline comments)
        $prefix = [Lexer]::LINE_COMMENT_PREFIX
        for ($i = 0; $i -lt $prefix.Length; $i++) {
            if ($state.PeekOffset($i) -ne $prefix[$i]) {
                return $false
            }
        }
        
        return $true
    }
    
    # Tokenize a line statement (e.g., # for item in items)
    [void]TokenizeLineStatement([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $state.CaptureStart()
        
        # Skip leading whitespace before the prefix
        while (-not $state.IsEOF() -and ($state.Peek() -eq ' ' -or $state.Peek() -eq "`t")) {
            $state.Consume()
        }
        
        # Consume the prefix
        $prefix = [Lexer]::LINE_STATEMENT_PREFIX
        for ($i = 0; $i -lt $prefix.Length; $i++) {
            $state.Consume()
        }
        
        # Skip whitespace after prefix
        while (-not $state.IsEOF() -and ($state.Peek() -eq ' ' -or $state.Peek() -eq "`t")) {
            $state.Consume()
        }
        
        # Collect the statement content until end of line
        $statementContent = ""
        while (-not $state.IsEOF() -and $state.Peek() -ne "`n" -and $state.Peek() -ne "`r") {
            $statementContent += $state.Peek()
            $state.Consume()
        }
        
        # Remove optional trailing colon
        $statementContent = $statementContent.TrimEnd()
        if ($statementContent.EndsWith(':')) {
            $statementContent = $statementContent.Substring(0, $statementContent.Length - 1).TrimEnd()
        }
        
        # Consume newline if present
        if (-not $state.IsEOF() -and $state.Peek() -eq "`r") {
            $state.Consume()
        }
        if (-not $state.IsEOF() -and $state.Peek() -eq "`n") {
            $state.Consume()
        }
        
        # Create a temporary lexer to tokenize the statement content as a block expression
        # Add BLOCK_START token
        $tokens.Add([Token]::new([TokenType]::BLOCK_START, [Lexer]::BLOCK_START, $state.StartLine, $state.StartColumn, $state.Filename))
        
        # Tokenize the statement content
        if (![string]::IsNullOrWhiteSpace($statementContent)) {
            $tempLexer = [Lexer]::new()
            $tempState = [LexerState]::new($statementContent, $state.Filename)
            $tempState.Line = $state.StartLine
            $tempState.Column = $state.StartColumn + $prefix.Length
            
            # Tokenize as expression content
            while (-not $tempState.IsEOF()) {
                $tempLexer.TokenizeExpression($tempState, $tokens, "BLOCK")
            }
        }
        
        # Add BLOCK_END token
        $tokens.Add([Token]::new([TokenType]::BLOCK_END, [Lexer]::BLOCK_END, $state.Line, $state.Column, $state.Filename))
    }
    
    # Tokenize a line comment (e.g., ## this is a comment)
    [void]TokenizeLineComment([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        # Consume the prefix
        $prefix = [Lexer]::LINE_COMMENT_PREFIX
        for ($i = 0; $i -lt $prefix.Length; $i++) {
            $state.Consume()
        }
        
        # Skip everything until end of line
        while (-not $state.IsEOF() -and $state.Peek() -ne "`n" -and $state.Peek() -ne "`r") {
            $state.Consume()
        }
        
        # Consume newline if present
        if (-not $state.IsEOF() -and $state.Peek() -eq "`r") {
            $state.Consume()
        }
        if (-not $state.IsEOF() -and $state.Peek() -eq "`n") {
            $state.Consume()
        }
        
        # Don't add any tokens - comment is ignored
    }
    
    # Process template text in the INITIAL state (outside of any tags)
    # Handles regular text content and detects the start of variable, block, or comment tags
    [void]TokenizeInitial([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        # Check for line comment first (higher priority than line statement)
        if ($this.CheckLineComment($state)) {
            $this.TokenizeLineComment($state, $tokens)
            return
        }
        
        # Check for line statement
        if ($this.CheckLineStatement($state)) {
            $this.TokenizeLineStatement($state, $tokens)
            return
        }
        
        $char = $state.Peek()
        
        # Check for template tags starting with '{'
        if ($char -eq '{') {
            $nextChar = $state.PeekOffset(1)
            switch ($nextChar) {
                # Variable tag: {{ ... }} or {{- ... }}
                '{' {
                    # Check for whitespace trimming syntax: {{- ... }}
                    $hasTrimBefore = $false
                    if ($state.PeekOffset(2) -eq '-') {
                        $hasTrimBefore = $true
                        # Trim whitespace BEFORE adding the token
                        $this.TrimWhitespaceBefore($tokens)
                    }
                    
                    $state.CaptureStart()
                    $state.Consume()  # Consume '{'
                    $state.Consume()  # Consume '{'
                    
                    if ($hasTrimBefore) {
                        $state.Consume()  # Consume '-'
                        $tokens.Add([Token]::new([TokenType]::VARIABLE_START, [Lexer]::VARIABLE_START_TRIM, $state.StartLine, $state.StartColumn, $state.Filename))
                    } else {
                        $tokens.Add([Token]::new([TokenType]::VARIABLE_START, [Lexer]::VARIABLE_START, $state.StartLine, $state.StartColumn, $state.Filename))
                    }
                    
                    $state.States.Push("VARIABLE")  # Switch to VARIABLE state
                    return
                }
                # Block tag: {% ... %}
                '%' {
                    # Check for whitespace trimming syntax: {%- ... %}
                    $hasTrimBefore = $false
                    if ($state.PeekOffset(2) -eq '-') {
                        $hasTrimBefore = $true
                        # Trim whitespace BEFORE adding the token
                        $this.TrimWhitespaceBefore($tokens)
                    }
                    
                    $state.CaptureStart()
                    $state.Consume()  # Consume '{'
                    $state.Consume()  # Consume '%'
                    
                    if ($hasTrimBefore) {
                        $state.Consume()  # Consume '-'
                        $tokens.Add([Token]::new([TokenType]::BLOCK_START, [Lexer]::BLOCK_START_TRIM, $state.StartLine, $state.StartColumn, $state.Filename))
                    } else {
                        $tokens.Add([Token]::new([TokenType]::BLOCK_START, [Lexer]::BLOCK_START, $state.StartLine, $state.StartColumn, $state.Filename))
                    }
                    
                    $state.States.Push("BLOCK")  # Switch to BLOCK state
                    return
                }
                # Comment tag: {# ... #}
                '#' {
                    $state.CaptureStart()
                    $state.Consume()  # Consume '{'
                    $state.Consume()  # Consume '#'
                    $tokens.Add([Token]::new([TokenType]::COMMENT_START, [Lexer]::COMMENT_START, $state.StartLine, $state.StartColumn, $state.Filename))
                    $state.States.Push("COMMENT")  # Switch to COMMENT state
                    return
                }
            }
        }
        
        # Process regular text content (everything up to the next tag, line statement, or EOF)
        $textStart = $state.Position
        $state.CaptureStart()
        
        while (-not $state.IsEOF()) {
            # Check if we've hit a template tag
            if ($state.Peek() -eq '{') {
                break
            }
            
            # Check for inline line comment (anywhere on the line, not just at start)
            if ($this.CheckLineComment($state)) {
                # Stop collecting text here, let next iteration handle the comment
                # Trim trailing whitespace before the comment
                if ($state.Position -gt $textStart) {
                    $textContent = $state.Text.Substring($textStart, $state.Position - $textStart)
                    # Trim trailing spaces and tabs (but not newlines)
                    $textContent = $textContent -replace '[ \t]+$', ''
                    if ($textContent.Length -gt 0) {
                        $tokens.Add([Token]::new([TokenType]::TEXT, $textContent, $state.StartLine, $state.StartColumn, $state.Filename))
                    }
                }
                return
            }
            
            # Check if we've hit a newline - need to check for line statements on next line
            if ($state.Peek() -eq "`n") {
                $state.Consume()  # Consume the newline
                
                # After consuming newline, check if next position is a line statement or comment
                if ($this.CheckLineComment($state) -or $this.CheckLineStatement($state)) {
                    # Stop collecting text here, let next iteration handle the line statement/comment
                    break
                }
            }
            else {
                $state.Consume()
            }
        }
        
        # If we found any text content, create a TEXT token
        if ($state.Position -gt $textStart) {
            $textContent = $state.Text.Substring($textStart, $state.Position - $textStart)
            $tokens.Add([Token]::new([TokenType]::TEXT, $textContent, $state.StartLine, $state.StartColumn, $state.Filename))
        }
    }
    
    # Process template text inside variable {{ ... }} or block {% ... %} expressions
    # Handles expressions, operators, identifiers, literals, and closing tags
    [void]TokenizeExpression([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens, [string]$mode) {
        # Skip any whitespace at the beginning of the expression
        $this.SkipWhitespace($state)
        
        # Check for unexpected end of file
        if ($state.IsEOF()) {
            throw "Unclosed $mode expression"
        }
        
        # Check for closing tags
        $char = $state.Peek()
        
        # Handle variable closing tags: }} or -}}
        if ($mode -eq "VARIABLE") {
            # Check for whitespace trimming syntax: ... -}}
            if ($char -eq '-' -and $state.PeekOffset(1) -eq '}' -and $state.PeekOffset(2) -eq '}') {
                $state.CaptureStart()
                $state.Consume()  # Consume '-'
                $state.Consume()  # Consume '}'
                $state.Consume()  # Consume '}'
                $tokens.Add([Token]::new([TokenType]::VARIABLE_END, [Lexer]::VARIABLE_END_TRIM, $state.StartLine, $state.StartColumn, $state.Filename))
                $state.States.Pop()  # Return to previous state
                
                # Trim whitespace after the tag
                $this.TrimWhitespaceAfter($state)
                return
            }
            # Regular variable end: }}
            elseif ($char -eq '}' -and $state.PeekOffset(1) -eq '}') {
                $state.CaptureStart()
                $state.Consume()  # Consume '}'
                $state.Consume()  # Consume '}'
                $tokens.Add([Token]::new([TokenType]::VARIABLE_END, [Lexer]::VARIABLE_END, $state.StartLine, $state.StartColumn, $state.Filename))
                $state.States.Pop()  # Return to previous state
                return
            }
        }
        
        # Handle block closing tags: %} or -%}
        if ($mode -eq "BLOCK") {
            # Check for whitespace trimming syntax: ... -%}
            if ($char -eq '-' -and $state.PeekOffset(1) -eq '%' -and $state.PeekOffset(2) -eq '}') {
                $state.CaptureStart()
                $state.Consume() # Consume '-'
                $state.Consume() # Consume '%'
                $state.Consume() # Consume '}'
                $tokens.Add([Token]::new([TokenType]::BLOCK_END, [Lexer]::BLOCK_END_TRIM, $state.StartLine, $state.StartColumn, $state.Filename))
                $state.States.Pop()  # Return to previous state
                
                # Check if the last keyword was 'raw' - if so, switch to RAW_BLOCK state
                if ($tokens.Count -ge 2 -and 
                    $tokens[$tokens.Count - 2].Type -eq [TokenType]::KEYWORD -and 
                    $tokens[$tokens.Count - 2].Value -eq 'raw') {
                    $state.States.Push("RAW_BLOCK")
                }
                
                # Trim whitespace after the tag
                $this.TrimWhitespaceAfter($state)
                return
            }
            # Regular block end: %}
            elseif ($char -eq '%' -and $state.PeekOffset(1) -eq '}') {
                $state.CaptureStart()
                $state.Consume()  # Consume '%'
                $state.Consume()  # Consume '}'
                $tokens.Add([Token]::new([TokenType]::BLOCK_END, [Lexer]::BLOCK_END, $state.StartLine, $state.StartColumn, $state.Filename))
                $state.States.Pop()  # Return to previous state
                
                # Check if the last keyword was 'raw' - if so, switch to RAW_BLOCK state
                if ($tokens.Count -ge 2 -and 
                    $tokens[$tokens.Count - 2].Type -eq [TokenType]::KEYWORD -and 
                    $tokens[$tokens.Count - 2].Value -eq 'raw') {
                    $state.States.Push("RAW_BLOCK")
                }
                
                return
            }
        }
        
        # Process expression content based on the current character
        $char = $state.Peek()
        
        # Identifiers (variable names, function names, etc.)
        if ([char]::IsLetter($char) -or $char -eq '_') {
            $this.TokenizeIdentifier($state, $tokens)
        }
        # Numbers (integers, decimals)
        elseif ([char]::IsDigit($char)) {
            $this.TokenizeNumber($state, $tokens)
        }
        # String literals
        elseif ($char -eq '"' -or $char -eq "'") {
            $this.TokenizeString($state, $tokens)
        }
        # Punctuation characters
        elseif ($this.IsPunctuation($char)) {
            $this.TokenizePunctuation($state, $tokens)
        }
        # Operators
        elseif ($this.IsOperator($char)) {
            $this.TokenizeOperator($state, $tokens)
        }
        # Pipe character for filters
        elseif ($this.IsPipe($char)) {
            $state.CaptureStart()
            $state.Consume()
            $tokens.Add([Token]::new([TokenType]::PIPE, [Lexer]::PIPE, $state.StartLine, $state.StartColumn, $state.Filename))
        }
        # Unexpected character
        else {
            throw "Unexpected character '$char' at line $($state.Line), column $($state.Column)"
        }
    }
    
    # Process template text inside comment blocks {# ... #}
    # Comments are ignored in the final output but need to be properly parsed
    [void]TokenizeComment([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $state.CaptureStart()
        # Consume characters until we find the comment end marker #} or -#} or reach EOF
        while (-not $state.IsEOF()) {
            # Check for whitespace trimming syntax: ... -#}
            if ($state.Peek() -eq '-' -and $state.PeekOffset(1) -eq '#' -and $state.PeekOffset(2) -eq '}') {
                $state.Consume()  # Consume '-'
                $state.Consume()  # Consume '#'
                $state.Consume()  # Consume '}'
                $tokens.Add([Token]::new([TokenType]::COMMENT_END, '-#}', $state.StartLine, $state.StartColumn, $state.Filename))
                $state.States.Pop()  # Return to previous state
                
                # Trim whitespace after the comment tag
                $this.TrimWhitespaceAfter($state)
                return
            }
            # Regular comment end: #}
            elseif ($state.Peek() -eq '#' -and $state.PeekOffset(1) -eq '}') {
                $state.Consume()  # Consume '#'
                $state.Consume()  # Consume '}'
                $tokens.Add([Token]::new([TokenType]::COMMENT_END, [Lexer]::COMMENT_END, $state.StartLine, $state.StartColumn, $state.Filename))
                $state.States.Pop()  # Return to previous state
                return
            }
            $state.Consume()  # Skip comment content
        }

        # If we reach EOF without finding the comment end marker, throw an error
        throw "Unclosed comment"
    }
    
    # Process an identifier (variable name, function name, etc.)
    # Also detects keywords and creates the appropriate token type
    [void]TokenizeIdentifier([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $start = $state.Position
        $state.CaptureStart()
        # Consume characters until we find a non-identifier character
        while (-not $state.IsEOF() -and ($this.IsIdentifierChar($state.Peek()))) {
            $state.Consume()
        }
        
        # Extract the identifier text
        $identifier = $state.Text.Substring($start, $state.Position - $start)
        
        # Check if the identifier is a reserved keyword
        if ([Lexer]::KEYWORDS.ContainsKey($identifier)) {
            $tokens.Add([Token]::new([TokenType]::KEYWORD, $identifier, $state.StartLine, $state.StartColumn, $state.Filename))
            
            # Special handling for 'raw' keyword - switch to RAW_BLOCK state
            if ($identifier -eq 'raw' -and $state.States.Peek() -eq 'BLOCK') {
                # We're in a block and just tokenized 'raw' keyword
                # After the closing %} is consumed, we'll switch to RAW_BLOCK state
                # This is handled in TokenizeExpression when it processes BLOCK_END
            }
        }
        else {
            $tokens.Add([Token]::new([TokenType]::IDENTIFIER, $identifier, $state.StartLine, $state.StartColumn, $state.Filename))
        }
    }
    
    # Process a numeric literal (integer or decimal)
    # Handles both integer and floating-point numbers
    [void]TokenizeNumber([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $start = $state.Position
        $state.CaptureStart()
        $hasDot = $false  # Track if we've seen a decimal point
        
        while (-not $state.IsEOF()) {
            $char = $state.Peek()
            if ([char]::IsDigit($char)) {
                # Consume digits
                $state.Consume()
            }
            elseif ($char -eq '.' -and -not $hasDot) {
                # Allow one decimal point in a number
                $hasDot = $true
                $state.Consume()
            }
            else {
                # Not a digit or decimal point, end of number
                break
            }
        }
        
        # Extract the number text and create a token
        $number = $state.Text.Substring($start, $state.Position - $start)
        $tokens.Add([Token]::new([TokenType]::NUMBER, $number, $state.StartLine, $state.StartColumn, $state.Filename))
    }
    
    # Process a string literal (enclosed in single or double quotes)
    # Handles escape sequences within strings
    [void]TokenizeString([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $state.CaptureStart()
        $quoteChar = $state.Consume()  # Consume the opening quote character (' or ")
        $start = $state.Position
        $escaped = $false  # Track if the current character is escaped
        
        # Process characters until we find the closing quote
        while (-not $state.IsEOF()) {
            $char = $state.Consume()
            
            if ($escaped) {
                # Previous character was a backslash, so this character is escaped
                $escaped = $false
            }
            elseif ($char -eq '\') {
                # Backslash starts an escape sequence
                $escaped = $true
            }
            elseif ($char -eq $quoteChar) {
                # Found the closing quote
                break
            }
        }
        
        # Error if we reached EOF without finding the closing quote
        if ($state.IsEOF()) {
            throw "Unclosed string literal"
        }
        
        # Extract the string content (without the quotes)
        $stringContent = $state.Text.Substring($start, $state.Position - $start - 1)
        $tokens.Add([Token]::new([TokenType]::STRING, $stringContent, $state.StartLine, $state.StartColumn, $state.Filename))
    }
    
    # Process a punctuation character (parentheses, brackets, commas, etc.)
    [void]TokenizePunctuation([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $state.CaptureStart()
        $char = $state.Consume()  # Consume the punctuation character
        $tokens.Add([Token]::new([TokenType]::PUNCTUATION, $char.ToString(), $state.StartLine, $state.StartColumn, $state.Filename))
    }
    
    # Process an operator character (+, -, *, /, =, etc.)
    [void]TokenizeOperator([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $state.CaptureStart()
        $char = $state.Consume()  # Consume the first operator character
        
        # Check for two-character operators (==, !=, <=, >=)
        $nextChar = $state.Peek()
        if (($char -eq '=' -and $nextChar -eq '=') -or
            ($char -eq '!' -and $nextChar -eq '=') -or
            ($char -eq '<' -and $nextChar -eq '=') -or
            ($char -eq '>' -and $nextChar -eq '=')) {
            $state.Consume()  # Consume the second character
            $tokens.Add([Token]::new([TokenType]::OPERATOR, "$char$nextChar", $state.StartLine, $state.StartColumn, $state.Filename))
        } else {
            $tokens.Add([Token]::new([TokenType]::OPERATOR, $char.ToString(), $state.StartLine, $state.StartColumn, $state.Filename))
        }
    }
    
    # Skip whitespace characters (spaces, tabs, newlines)
    # Used to ignore whitespace in expressions
    [void]SkipWhitespace([LexerState]$state) {
        while (-not $state.IsEOF() -and [char]::IsWhiteSpace($state.Peek())) {
            $state.Consume()
        }
    }
    
    # Check if a character is valid in an identifier (letters, digits, underscore)
    [bool]IsIdentifierChar([char]$c) {
        return [char]::IsLetterOrDigit($c) -or $c -eq '_'
    }
    
    # Check if a character is a punctuation character
    [bool]IsPunctuation([char]$c) {
        return $c -in @('(', ')', '[', ']', '{', '}', ',', ':', '.')
    }
    
    # Check if a character is an operator
    [bool]IsOperator([char]$c) {
        return $c -in @('+', '-', '*', '/', '=', '!', '<', '>')
    }
    
    # Check if a character is a pipe (used for filters)
    [bool]IsPipe([char]$c) {
        return $c -eq '|'
    }
    
    # Trim whitespace before a tag when using the {{- or {%- syntax
    # This removes trailing whitespace from the previous text token
    [void]TrimWhitespaceBefore([System.Collections.Generic.List[Token]]$tokens) {
        # If there are no tokens or the last token is not TEXT, nothing to trim
        if ($tokens.Count -eq 0 -or $tokens[-1].Type -ne [TokenType]::TEXT) {
            return
        }
        
        # Get the last token, which should be a TEXT token
        $lastToken = $tokens[-1]
        $content = $lastToken.Value
        
        # Trim ALL trailing whitespace (spaces, tabs, and newlines) before the tag
        # This matches Jinja2 behavior where - removes all whitespace before the block
        # Pattern: match any whitespace characters at the end of the string
        $trimmedContent = $content -replace '[\s]+$', ''
        
        # If the content changed, update the token or remove it if it's empty
        if ($trimmedContent -ne $content) {
            if ($trimmedContent -eq '') {
                # Remove the token if it's now empty
                $tokens.RemoveAt($tokens.Count - 1)
            } else {
                # Replace the token with a new one containing the trimmed content
                $tokens[-1] = [Token]::new([TokenType]::TEXT, $trimmedContent, $lastToken.Line, $lastToken.Column, $lastToken.Filename)
            }
        }
    }
    
    # Trim whitespace after a tag when using the -%} syntax
    # This consumes whitespace characters after the tag
    [void]TrimWhitespaceAfter([LexerState]$state) {
        # Skip horizontal whitespace (spaces and tabs)
        while (-not $state.IsEOF() -and ($state.Peek() -eq ' ' -or $state.Peek() -eq "`t")) {
            $state.Consume()
        }
        
        # If we encounter a newline, consume it (including \r if present)
        if (-not $state.IsEOF() -and $state.Peek() -eq "`r") {
            $state.Consume()
        }
        if (-not $state.IsEOF() -and $state.Peek() -eq "`n") {
            $state.Consume()
        }
    }
    
    # Process raw block content - collect everything until {% endraw %} without tokenizing
    # This prevents the lexer from trying to tokenize special characters inside raw blocks
    [void]TokenizeRawBlock([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        # We're in RAW_BLOCK state, which means we just consumed {% raw %}
        # Now we need to find {% endraw %} and collect everything in between as RAW_CONTENT
        
        $startPos = $state.Position
        $state.CaptureStart()
        
        # Search for {% endraw %} in the raw text
        while (-not $state.IsEOF()) {
            # Check if we've found the start of {% endraw %}
            if ($state.Peek() -eq '{' -and $state.PeekOffset(1) -eq '%') {
                # Look ahead to see if this is {% endraw %} or {%- endraw %}
                $tempPos = $state.Position + 2
                
                # Skip optional '-' for {%- endraw %}
                if (($tempPos -lt $state.Text.Length) -and ($state.Text[$tempPos] -eq '-')) {
                    $tempPos++
                }
                
                # Skip whitespace
                while (($tempPos -lt $state.Text.Length) -and [char]::IsWhiteSpace($state.Text[$tempPos])) {
                    $tempPos++
                }
                
                # Check if we have 'endraw' keyword
                if (($tempPos + 6) -le $state.Text.Length) {
                    $keyword = $state.Text.Substring($tempPos, 6)
                    if ($keyword -eq 'endraw') {
                        # Found {% endraw %} - extract the raw content
                        $rawContent = $state.Text.Substring($startPos, $state.Position - $startPos)
                        
                        # Add RAW_CONTENT token
                        $tokens.Add([Token]::new([TokenType]::RAW_CONTENT, $rawContent, $state.StartLine, $state.StartColumn, $state.Filename))
                        
                        # Now tokenize the {% endraw %} tag normally
                        # Switch back to INITIAL state
                        $state.States.Pop()
                        
                        # The next TokenizeInitial call will handle the {% endraw %} tag
                        return
                    }
                }
            }
            
            # Not the endraw tag, consume the character
            $state.Consume()
        }
        
        # If we reach here, we didn't find {% endraw %}
        throw "Unclosed raw block - missing {% endraw %}"
    }
}

### AST (Abstract Syntax Tree) Classes
# Base class for all AST nodes
# The AST represents the hierarchical structure of the template after parsing
class ASTNode {
    [int]$Line         # Line number where the node appears (for error reporting)
    [int]$Column       # Column number where the node appears (for error reporting)
    [string]$Filename  # Source filename
    
    # Constructor initializes position information for error reporting
    ASTNode([int]$line, [int]$column, [string]$filename) {
        $this.Line = $line
        $this.Column = $column
        $this.Filename = $filename
    }
}

# Base class for all expression nodes in the AST
# Expressions are elements that can be evaluated to a value
class ExpressionNode : ASTNode {
    ExpressionNode([int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {}
}

# Represents a literal value in the template (string, number, boolean, null)
class LiteralNode : ExpressionNode {
    [object]$Value  # The actual literal value
    
    LiteralNode([object]$value, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Value = $value
    }
}

# Represents a variable reference in the template
class VariableNode : ExpressionNode {
    [string]$Name  # The name of the variable
    
    VariableNode([string]$name, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Name = $name
    }
}

# Represents property access expressions (e.g., user.name, item.price)
# Allows accessing properties or methods of objects in the template
class PropertyAccessNode : ExpressionNode {
    [ExpressionNode]$Object  # The object being accessed
    [string]$Property        # The name of the property to access
    
    PropertyAccessNode([ExpressionNode]$object, [string]$property, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Object = $object
        $this.Property = $property
    }
}

# Represents array/dictionary indexing expressions (e.g., array[0], dict['key'])
# Allows accessing elements by index or key in the template
class IndexAccessNode : ExpressionNode {
    [ExpressionNode]$Object  # The object being indexed
    [ExpressionNode]$Index   # The index expression
    
    IndexAccessNode([ExpressionNode]$object, [ExpressionNode]$index, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Object = $object
        $this.Index = $index
    }
}

# Represents binary operations in expressions (e.g., a + b, x > y)
class BinaryOpNode : ExpressionNode {
    [string]$Operator        # The operator (e.g., +, -, *, /, ==, !=, etc.)
    [ExpressionNode]$Left    # The left operand
    [ExpressionNode]$Right   # The right operand
    
    BinaryOpNode([string]$operator, [ExpressionNode]$left, [ExpressionNode]$right, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Operator = $operator
        $this.Left = $left
        $this.Right = $right
    }
}

# Represents filter applications in the template (e.g., {{ name | upper }}, {{ price | format("C") }})
class FilterNode : ExpressionNode {
    [ExpressionNode]$Expression      # The expression being filtered
    [string]$FilterName              # The name of the filter to apply
    [ExpressionNode[]]$Arguments     # Optional arguments for the filter
    
    FilterNode([ExpressionNode]$expression, [string]$filterName, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Expression = $expression
        $this.FilterName = $filterName
        $this.Arguments = @()  # Initialize empty array for filter arguments
    }
}

# Base class for all statement nodes in the AST
# Statements are top-level elements in the template that generate output or control flow
class StatementNode : ASTNode {
    StatementNode([int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {}
}

# Represents literal text content in the template
# This is the static text that appears outside of any tags
class TextNode : StatementNode {
    [string]$Content  # The text content
    
    TextNode([string]$content, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Content = $content
    }
}

# Represents a variable output expression in the template ({{ expression }})
# These nodes evaluate their expression and output the result
class OutputNode : StatementNode {
    [ExpressionNode]$Expression  # The expression to evaluate and output
    
    OutputNode([ExpressionNode]$expression, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Expression = $expression
    }
}

# Represents a conditional block in the template ({% if condition %} ... {% endif %})
# Can include elif and else branches for complex conditionals
class IfNode : StatementNode {
    [ExpressionNode]$Condition     # The condition to evaluate
    [StatementNode[]]$ThenBranch   # Statements to execute if condition is true
    [StatementNode[]]$ElseBranch   # Statements to execute if condition is false (and no elif matches)
    [IfNode]$ElifBranch            # Optional elif branch (which is itself an IfNode)
    
    IfNode([ExpressionNode]$condition, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Condition = $condition
        $this.ThenBranch = @()     # Initialize empty array for then branch
        $this.ElseBranch = @()     # Initialize empty array for else branch
    }
}

# Represents a loop block in the template ({% for item in items %} ... {% endfor %})
# Iterates over a collection and executes the body for each item
class ForNode : StatementNode {
    [string]$Variable             # The loop variable name
    [ExpressionNode]$Iterable     # The collection to iterate over
    [StatementNode[]]$Body        # Statements to execute for each iteration
    [StatementNode[]]$ElseBranch  # Statements to execute if iterable is empty
    
    ForNode([string]$variable, [ExpressionNode]$iterable, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Variable = $variable
        $this.Iterable = $iterable
        $this.Body = @()          # Initialize empty array for loop body
        $this.ElseBranch = @()    # Initialize empty array for else branch
    }
}

# Represents template inheritance ({% extends "base.html" %})
# Allows a template to inherit from a parent template
class ExtendsNode : StatementNode {
    [ExpressionNode]$Parent  # Expression that evaluates to the parent template name
    
    ExtendsNode([ExpressionNode]$parent, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Parent = $parent
    }
}

# Represents a named block in the template ({% block content %} ... {% endblock %})
# Used with template inheritance to define overridable sections
class BlockNode : StatementNode {
    [string]$Name           # The name of the block
    [StatementNode[]]$Body  # The content of the block
    [bool]$Scoped           # Jinja2 compatibility: scoped modifier (always true in Altar due to PowerShell scoping)
    
    BlockNode([string]$name, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Name = $name
        $this.Body = @()    # Initialize empty array for block content
        $this.Scoped = $false  # Default to false, set to true if 'scoped' modifier is present
    }
}

# Represents template inclusion ({% include "header.html" %})
# Allows including another template within the current template
class IncludeNode : StatementNode {
    [ExpressionNode]$Template  # Expression that evaluates to the template name to include
    [bool]$IgnoreMissing       # If true, don't throw error if template is not found
    
    IncludeNode([ExpressionNode]$template, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Template = $template
        $this.IgnoreMissing = $false
    }
}

# Represents a raw block in the template ({% raw %} ... {% endraw %})
# Content inside raw blocks is output as-is without any template processing
class RawNode : StatementNode {
    [string]$Content  # The raw content to output without processing
    
    RawNode([string]$content, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Content = $content
    }
}

# Represents a comment in the template ({# ... #})
# Comments are ignored in the output but need to be tracked during parsing
class CommentNode : StatementNode {
    CommentNode([int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {}
}

# Represents an array literal in the template (e.g., ['item1', 'item2'])
class ArrayLiteralNode : ExpressionNode {
    [ExpressionNode[]]$Elements  # The elements in the array
    
    ArrayLiteralNode([ExpressionNode[]]$elements, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Elements = $elements
    }
}

# Represents a dictionary/hashtable literal in the template (e.g., {'key': 'value', 'key2': 'value2'})
class DictLiteralNode : ExpressionNode {
    [System.Collections.Generic.List[System.Tuple[ExpressionNode, ExpressionNode]]]$Pairs  # Key-value pairs
    
    DictLiteralNode([int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Pairs = [System.Collections.Generic.List[System.Tuple[ExpressionNode, ExpressionNode]]]::new()
    }
}

# Represents a super() call in the template
# Used to include the parent block's content when overriding blocks
class SuperNode : ExpressionNode {
    SuperNode([int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {}
}

# Represents a self.blockname() call in the template (Jinja2 compatibility)
# Allows calling a block as a function from anywhere in the template
class SelfCallNode : ExpressionNode {
    [string]$BlockName  # The name of the block to call
    
    SelfCallNode([string]$blockName, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.BlockName = $blockName
    }
}

# Represents a conditional (ternary) expression in the template (e.g., 'yes' if foo else 'no')
# This is the inline if-else expression, not to be confused with the {% if %} block statement
class ConditionalExpressionNode : ExpressionNode {
    [ExpressionNode]$TrueValue    # Value to return if condition is true
    [ExpressionNode]$Condition    # Condition to evaluate
    [ExpressionNode]$FalseValue   # Value to return if condition is false
    
    ConditionalExpressionNode([ExpressionNode]$trueValue, [ExpressionNode]$condition, [ExpressionNode]$falseValue, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.TrueValue = $trueValue
        $this.Condition = $condition
        $this.FalseValue = $falseValue
    }
}

# Represents an 'is' test expression in the template (e.g., variable is defined, number is even)
# Used for type and state testing similar to Jinja2
class IsTestNode : ExpressionNode {
    [ExpressionNode]$Expression     # The expression to test
    [string]$TestName               # The name of the test (defined, none, even, odd, etc.)
    [bool]$Negated                  # Whether the test is negated (is not)
    [ExpressionNode[]]$Arguments    # Optional arguments for tests like divisibleby(n) or sameas(value)
    
    IsTestNode([ExpressionNode]$expression, [string]$testName, [bool]$negated, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Expression = $expression
        $this.TestName = $testName
        $this.Negated = $negated
        $this.Arguments = @()
    }
}

# Represents a PowerShell execution block in the template ({% powershell %} ... {% endpowershell %})
# Executes PowerShell code and outputs the result, with optional else and catch blocks
class PowerShellBlockNode : StatementNode {
    [string]$Code              # The PowerShell code to execute
    [StatementNode[]]$ElseBranch   # Statements to execute if result is null/empty
    [StatementNode[]]$CatchBranch  # Statements to execute if an error occurs
    
    PowerShellBlockNode([string]$code, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Code = $code
        $this.ElseBranch = @()
        $this.CatchBranch = @()
    }
}

# Represents a variable assignment statement ({% set variable = value %})
# Allows setting variables within the template
class SetNode : StatementNode {
    [string]$VariableName      # The name of the variable to set
    [ExpressionNode]$Value     # The value to assign to the variable
    
    SetNode([string]$variableName, [ExpressionNode]$value, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.VariableName = $variableName
        $this.Value = $value
    }
}

# Represents a macro definition ({% macro name(args) %} ... {% endmacro %})
# Macros are reusable template fragments with parameters
class MacroNode : StatementNode {
    [string]$Name                                      # The name of the macro
    [System.Collections.Generic.List[string]]$Parameters  # Parameter names
    [hashtable]$Defaults                               # Default values for parameters
    [StatementNode[]]$Body                             # The macro body
    
    MacroNode([string]$name, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Name = $name
        $this.Parameters = [System.Collections.Generic.List[string]]::new()
        $this.Defaults = @{}
        $this.Body = @()
    }
}

# Represents a macro call expression (e.g., {{ macroname(args) }})
# Calls a previously defined macro with arguments
class MacroCallNode : ExpressionNode {
    [string]$MacroName                                 # The name of the macro to call
    [System.Collections.Generic.List[ExpressionNode]]$Arguments  # Positional arguments
    [hashtable]$NamedArguments                         # Named arguments (key-value pairs)
    
    MacroCallNode([string]$macroName, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.MacroName = $macroName
        $this.Arguments = [System.Collections.Generic.List[ExpressionNode]]::new()
        $this.NamedArguments = @{}
    }
}

# Represents a call block ({% call macroname() %} ... {% endcall %})
# Allows passing a block of content to a macro via caller()
class CallNode : StatementNode {
    [MacroCallNode]$MacroCall                          # The macro call expression
    [StatementNode[]]$Body                             # The caller block content
    [System.Collections.Generic.List[string]]$Parameters  # Parameters for caller()
    
    CallNode([MacroCallNode]$macroCall, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.MacroCall = $macroCall
        $this.Body = @()
        $this.Parameters = [System.Collections.Generic.List[string]]::new()
    }
}

# Represents an import statement ({% import 'template.html' as forms %})
# Imports macros from another template
class ImportNode : StatementNode {
    [ExpressionNode]$Template                          # Template to import from
    [string]$Alias                                     # Alias for the imported macros
    
    ImportNode([ExpressionNode]$template, [string]$alias, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Template = $template
        $this.Alias = $alias
    }
}

# Represents a from-import statement ({% from 'template.html' import macro1, macro2 %})
# Imports specific macros from another template
class FromImportNode : StatementNode {
    [ExpressionNode]$Template                          # Template to import from
    [System.Collections.Generic.List[string]]$MacroNames  # Names of macros to import
    [hashtable]$Aliases                                # Aliases for imported macros (optional)
    
    FromImportNode([ExpressionNode]$template, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Template = $template
        $this.MacroNames = [System.Collections.Generic.List[string]]::new()
        $this.Aliases = @{}
    }
}

# Root node representing an entire template
# Contains all statements and manages template inheritance
class TemplateNode : ASTNode {
    [StatementNode[]]$Body    # All top-level statements in the template
    [ExtendsNode]$Extends     # Reference to parent template (if this template extends another)
    [hashtable]$Blocks        # Named blocks defined in this template (for inheritance)
    
    TemplateNode([int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Body = @()      # Initialize empty array for template content
        $this.Extends = $null # No parent template by default
        $this.Blocks = @{}    # Initialize empty hashtable for blocks
    }
}

### Parser Classes
# Parser class that converts tokens into an Abstract Syntax Tree (AST)
# This is the second stage of template processing (parsing)
class Parser {
    [System.Collections.Generic.List[Token]]$Tokens
    [int]$Position
    [string]$Filename
    [string]$SourceText  # Store the original template text
    
    Parser([System.Collections.Generic.List[Token]]$tokens, [string]$filename) {
        $this.Tokens = $tokens
        $this.Position = 0
        $this.Filename = $filename
        $this.SourceText = ""
    }
    
    # Get the current token without advancing the position
    [Token]Current() {
        if ($this.Position -ge $this.Tokens.Count) {
            return $null  # Return null if we're at the end of the token stream
        }
        return $this.Tokens[$this.Position]
    }
    
    # Peek at the current token (alias for Current)
    [Token]Peek() {
        return $this.PeekOffset(0)
    }
    
    # Look ahead at a token at a specific offset without consuming it
    [Token]PeekOffset([int]$offset) {
        $pos = $this.Position + $offset
        if ($pos -ge $this.Tokens.Count) {
            return $null  # Return null if the offset is beyond the token stream
        }
        return $this.Tokens[$pos]
    }
    
    # Consume and return the current token, advancing the position
    [Token]Consume() {
        $token = $this.Current()
        if ($null -ne $token) {
            $this.Position++  # Advance to the next token
        }
        return $token
    }
    
    # Check if the current token matches the specified type
    [bool]Match([TokenType]$type) {
        return $this.MatchTypeValue($type, $null)
    }
    
    # Check if the current token matches the specified type and value
    [bool]MatchTypeValue([TokenType]$type, [object]$value) {
        $token = $this.Current()
        if ($null -eq $token) {
            return $false  # No token to match
        }
        
        # Check if the token type matches
        if ($token.Type -ne $type) {
            return $false
        }
        
        # Check if the token value matches (if a value was specified)
        if ($null -ne $value -and $token.Value -ne $value) {
            return $false
        }
        
        return $true
    }
    
    # Expect a token of the specified type, consuming it
    [Token]Expect([TokenType]$type) {
        return $this.ExpectWithValue($type, $null, $null)
    }
    
    # Expect a token of the specified type and value, consuming it
    [Token]Expect([TokenType]$type, [string]$value) {
        return $this.ExpectWithValue($type, $value, $null)
    }
    
    # Expect a token of the specified type and value with a custom error message
    [Token]Expect([TokenType]$type, [string]$value, [string]$message) {
        return $this.ExpectWithValue($type, $value, $message)
    }
    
    # Implementation of the Expect methods
    # Consumes a token and throws an error if it doesn't match the expected type and value
    [Token]ExpectWithValue([TokenType]$type, [string]$value, [string]$message) {
        $token = $this.Consume()
        
        # Check if we've reached the end of the token stream
        if ($null -eq $token) {
            throw "Unexpected end of input. Expected: $type"
        }
        
        # Check if the token type matches
        if ($token.Type -ne $type) {
            throw "Unexpected token $($token.Type). Expected: $type. $message"
        }
        
        # Check if the token value matches (if a value was specified)
        if (![string]::IsNullOrEmpty($value) -and $token.Value -ne $value) {
            throw "Unexpected token value '$($token.Value)'. Expected: '$value'. $message"
        }
        
        return $token
    }
    
    # Parse the entire template and build the AST
    # This is the entry point for the parsing process
    [TemplateNode]ParseTemplate() {
        # Create the root template node
        $template = [TemplateNode]::new(1, 1, $this.Filename)
        
        # Parse statements until we reach the end of the template
        while (-not $this.Match([TokenType]::EOF)) {
            $statement = $this.ParseStatement()
            if ($null -ne $statement) {
                # Check if this is an extends statement
                if ($statement -is [ExtendsNode]) {
                    $template.Extends = $statement
                }
                # Check if this is a block statement and collect it
                elseif ($statement -is [BlockNode]) {
                    $template.Blocks[$statement.Name] = $statement
                }
                
                $template.Body += $statement
            }
        }
        
        return $template
    }
    
    # Parse a single statement in the template
    # Statements include text, variable outputs, blocks, and comments
    [StatementNode]ParseStatement() {
        $token = $this.Current()
        if ($null -eq $token) {
            return $null
        }
        
        # Handle different token types
        if ($token.Type -eq [TokenType]::TEXT) {
            # Regular text content
            $textToken = $this.Consume()
            return [TextNode]::new($textToken.Value, $textToken.Line, $textToken.Column, $textToken.Filename)
        }
        elseif ($token.Type -eq [TokenType]::VARIABLE_START) {
            # Variable output expression {{ ... }}
            return $this.ParseOutput()
        }
        elseif ($token.Type -eq [TokenType]::BLOCK_START) {
            # Block expression {% ... %}
            
            # Special handling for block end keywords (else, elif, endif, endfor, endblock)
            # These are handled by their parent block parsers, not here
            if (($this.Position + 1) -lt $this.Tokens.Count) {
                $nextToken = $this.PeekOffset(1)
                if ($nextToken.Type -eq [TokenType]::KEYWORD -and 
                    $nextToken.Value -in @('else', 'elif', 'endif', 'endfor', 'endblock')) {
                    # Don't process these tokens here - they're handled by their respective parent parsers
                    # Just return null to signal that we've reached the end of the current block
                    return $null
                }
            }
            
            # Parse the block
            $result = $this.ParseBlock()
            return $result
        }
        elseif ($token.Type -eq [TokenType]::COMMENT_START) {
            # Comment {# ... #} - return CommentNode instead of null
            return $this.ParseComment()
        }
        elseif ($token.Type -eq [TokenType]::BLOCK_END) {
            # Skip BLOCK_END as it's handled in other methods
            $this.Consume()
            return $null
        }
        elseif ($token.Type -eq [TokenType]::EOF) {
            # Skip EOF as it's handled in ParseTemplate method
            return $null
        }
        else {
            throw "Unexpected token in template: $($token.Type)"
        }
    }
    
    # Parse a variable output expression {{ ... }}
    # Creates an OutputNode that will evaluate and output the expression
    [OutputNode]ParseOutput() {
        $startToken = $this.Expect([TokenType]::VARIABLE_START)  # Consume the {{ token
        $expression = $this.ParseExpression()                    # Parse the expression inside
        $this.Expect([TokenType]::VARIABLE_END)                  # Consume the }} token
        
        # Create an OutputNode with the parsed expression
        return [OutputNode]::new($expression, $startToken.Line, $startToken.Column, $startToken.Filename)
    }
    
    [StatementNode]ParseBlock() {
        $startToken = $this.Expect([TokenType]::BLOCK_START)
        $keyword = $this.Expect([TokenType]::KEYWORD)
        
        switch ($keyword.Value.ToLower()) {
            "if" { return $this.ParseIf($startToken) }
            "elif" { return $null } # Processing in ParseIf
            "else" { return $null } # Processing in ParseIf
            "endif" { return $null } # Just ending if block
            "for" { return $this.ParseFor($startToken) }
            "endfor" { return $null } # Just ending for block
            "block" { return $this.ParseBlockDef($startToken) }
            "include" { return $this.ParseInclude($startToken) }
            "extends" { return $this.ParseExtends($startToken) }
            "endblock" { return $null } # Just ending block
            "raw" { return $this.ParseRaw($startToken) }
            "endraw" { return $null } # Just ending raw block
            "powershell" { return $this.ParsePowerShell($startToken) }
            "endpowershell" { return $null } # Just ending powershell block
            "catch" { return $null } # Handled in ParsePowerShell
            "set" { return $this.ParseSet($startToken) }
            "macro" { return $this.ParseMacro($startToken) }
            "endmacro" { return $null } # Just ending macro block
            "call" { return $this.ParseCall($startToken) }
            "endcall" { return $null } # Just ending call block
            "import" { return $this.ParseImport($startToken) }
            "from" { return $this.ParseFromImport($startToken) }
            default { throw "Unknown block keyword: $($keyword.Value)" }
        }
        return $null # only for PSScriptAnalyzer because it cannot understand derfault statement in switch
    }
    
    [ExtendsNode]ParseExtends([Token]$startToken) {
        $parentTemplate = $this.ParseExpression()
        $this.Expect([TokenType]::BLOCK_END)
        
        return [ExtendsNode]::new($parentTemplate, $startToken.Line, $startToken.Column, $startToken.Filename)
    }
    
    [BlockNode]ParseBlockDef([Token]$startToken) {
        $blockName = $this.Expect([TokenType]::IDENTIFIER, $null).Value
        
        # Check for optional 'scoped' modifier (Jinja2 compatibility)
        # Note: In Altar, blocks always have access to outer scope variables due to PowerShell's scoping rules.
        # The 'scoped' modifier is accepted for Jinja2 template compatibility but doesn't change behavior.
        $isScoped = $false
        if ($this.Match([TokenType]::IDENTIFIER) -and $this.Current().Value -eq 'scoped') {
            $this.Consume()  # Consume 'scoped'
            $isScoped = $true
        }
        
        $this.Expect([TokenType]::BLOCK_END)
        
        $blockNode = [BlockNode]::new($blockName, $startToken.Line, $startToken.Column, $startToken.Filename)
        $blockNode.Scoped = $isScoped
        
        # Parse block body
        while ($true) {
            # Check for endblock tag
            if (($this.Position + 1) -lt $this.Tokens.Count) {
                $currentToken = $this.Current()
                $nextToken = $this.PeekOffset(1)
                
                # Check if we've reached the endblock tag
                if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
                    $nextToken.Type -eq [TokenType]::KEYWORD -and 
                    $nextToken.Value -eq 'endblock') {
                    break
                }
                
                # Check if we've reached EOF
                if ($currentToken.Type -eq [TokenType]::EOF) {
                    throw "Unexpected end of template. Expected: endblock"
                }
            } else {
                throw "Unexpected end of template. Expected: endblock"
            }
            
            $statement = $this.ParseStatement()
            if ($null -ne $statement) {
                $blockNode.Body += $statement
            } else {
                # If ParseStatement returns null, advance position to avoid infinite loop
                if ($this.Position -lt $this.Tokens.Count) {
                    $this.Position++
                } else {
                    throw "Unexpected end of template. Expected: endblock"
                }
            }
        }
        
        # Consume endblock
        $this.Consume() # BLOCK_START
        $this.Consume() # endblock
        $this.Expect([TokenType]::BLOCK_END)
        
        return $blockNode
    }
    
    [IncludeNode]ParseInclude([Token]$startToken) {
        # Check if this is an array literal [...]
        $templateExpr = $null
        if ($this.MatchTypeValue([TokenType]::PUNCTUATION, "[")) {
            $templateExpr = $this.ParseArrayLiteral()
        } else {
            $templateExpr = $this.ParseExpression()
        }
        
        # Check for 'ignore missing' option
        $ignoreMissing = $false
        $currentToken = $this.Current()
        
        if ($null -ne $currentToken -and $currentToken.Type -eq [TokenType]::IDENTIFIER -and $currentToken.Value -eq 'ignore') {
            $this.Consume() # Consume 'ignore'
            
            # Expect 'missing' keyword
            $nextToken = $this.Current()
            if ($null -ne $nextToken -and $nextToken.Type -eq [TokenType]::IDENTIFIER -and $nextToken.Value -eq 'missing') {
                $this.Consume() # Consume 'missing'
                $ignoreMissing = $true
            } else {
                throw "Expected 'missing' after 'ignore' at line $($startToken.Line), column $($startToken.Column)"
            }
        }
        
        $this.Expect([TokenType]::BLOCK_END)
        
        $includeNode = [IncludeNode]::new($templateExpr, $startToken.Line, $startToken.Column, $startToken.Filename)
        $includeNode.IgnoreMissing = $ignoreMissing
        return $includeNode
    }
    
    # Parse an array literal [item1, item2, ...]
    [ArrayLiteralNode]ParseArrayLiteral() {
        $startToken = $this.Expect([TokenType]::PUNCTUATION, "[")
        $elements = [System.Collections.Generic.List[ExpressionNode]]::new()
        
        # Parse array elements
        while (-not $this.MatchTypeValue([TokenType]::PUNCTUATION, "]")) {
            $element = $this.ParseExpression()
            [void]$elements.Add($element)
            
            # Check for comma (multiple elements)
            if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                $this.Consume() # Consume ','
            } else {
                # No comma, expect closing bracket
                break
            }
        }
        
        $this.Expect([TokenType]::PUNCTUATION, "]")
        
        # Create an ArrayLiteralNode
        return [ArrayLiteralNode]::new($elements.ToArray(), $startToken.Line, $startToken.Column, $startToken.Filename)
    }
    
    [RawNode]ParseRaw([Token]$startToken) {
        # Consume the closing %} of the {% raw %} tag
        $this.Expect([TokenType]::BLOCK_END)
        
        # The lexer should have created a RAW_CONTENT token
        # Consume it to get the raw content
        $rawContentToken = $this.Expect([TokenType]::RAW_CONTENT)
        $rawContent = $rawContentToken.Value
        
        # Now consume the {% endraw %} tag tokens
        $this.Expect([TokenType]::BLOCK_START)
        $this.Expect([TokenType]::KEYWORD, "endraw")
        $this.Expect([TokenType]::BLOCK_END)
        
        return [RawNode]::new($rawContent, $startToken.Line, $startToken.Column, $startToken.Filename)
    }
    
    [PowerShellBlockNode]ParsePowerShell([Token]$startToken) {
        # Consume the closing %} of the {% powershell %} tag
        $this.Expect([TokenType]::BLOCK_END)
        
        # Collect PowerShell code until we find {% else %}, {% catch %}, or {% endpowershell %}
        $psCode = ""
        
        while ($true) {
            $currentToken = $this.Current()
            
            # Check if we've reached EOF
            if ($null -eq $currentToken -or $currentToken.Type -eq [TokenType]::EOF) {
                throw "Unexpected end of template. Expected: endpowershell"
            }
            
            # Check if we've found {% else %}, {% catch %}, or {% endpowershell %}
            if ($currentToken.Type -eq [TokenType]::BLOCK_START) {
                $nextToken = $this.PeekOffset(1)
                if ($null -ne $nextToken -and $nextToken.Type -eq [TokenType]::KEYWORD) {
                    if ($nextToken.Value -in @('else', 'catch', 'endpowershell')) {
                        break
                    }
                }
            }
            
            # Collect the content - reconstruct the original text
            if ($currentToken.Type -eq [TokenType]::TEXT) {
                $psCode += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::VARIABLE_START) {
                $psCode += [Lexer]::VARIABLE_START
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::VARIABLE_END) {
                $psCode += [Lexer]::VARIABLE_END
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::BLOCK_START) {
                $psCode += [Lexer]::BLOCK_START
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::BLOCK_END) {
                $psCode += [Lexer]::BLOCK_END
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::COMMENT_START) {
                $psCode += [Lexer]::COMMENT_START
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::COMMENT_END) {
                $psCode += [Lexer]::COMMENT_END
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::IDENTIFIER) {
                $psCode += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::KEYWORD) {
                $psCode += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::STRING) {
                $psCode += '"' + $currentToken.Value + '"'
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::NUMBER) {
                $psCode += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::OPERATOR) {
                $psCode += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::PUNCTUATION) {
                $psCode += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::PIPE) {
                $psCode += [Lexer]::PIPE
                $this.Consume()
            }
            else {
                $this.Consume()
            }
        }
        
        # Create the PowerShell block node
        $psBlockNode = [PowerShellBlockNode]::new($psCode, $startToken.Line, $startToken.Column, $startToken.Filename)
        
        # Check for {% else %} block
        $currentToken = $this.Current()
        $nextToken = $this.PeekOffset(1)
        
        if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
            $nextToken.Type -eq [TokenType]::KEYWORD -and 
            $nextToken.Value -eq 'else') {
            
            $this.Consume() # BLOCK_START
            $this.Consume() # else
            $this.Expect([TokenType]::BLOCK_END)
            
            # Parse else branch until we find {% catch %} or {% endpowershell %}
            while ($true) {
                $currentToken = $this.Current()
                
                if ($null -eq $currentToken -or $currentToken.Type -eq [TokenType]::EOF) {
                    throw "Unexpected end of template. Expected: endpowershell"
                }
                
                # Check for {% catch %} or {% endpowershell %}
                if ($currentToken.Type -eq [TokenType]::BLOCK_START) {
                    $nextToken = $this.PeekOffset(1)
                    if ($null -ne $nextToken -and $nextToken.Type -eq [TokenType]::KEYWORD -and 
                        $nextToken.Value -in @('catch', 'endpowershell')) {
                        break
                    }
                }
                
                $statement = $this.ParseStatement()
                if ($null -ne $statement) {
                    $psBlockNode.ElseBranch += $statement
                } else {
                    if ($this.Position -lt $this.Tokens.Count) {
                        $this.Position++
                    } else {
                        throw "Unexpected end of template. Expected: endpowershell"
                    }
                }
            }
        }
        
        # Check for {% catch %} block
        $currentToken = $this.Current()
        $nextToken = $this.PeekOffset(1)
        
        if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
            $nextToken.Type -eq [TokenType]::KEYWORD -and 
            $nextToken.Value -eq 'catch') {
            
            $this.Consume() # BLOCK_START
            $this.Consume() # catch
            $this.Expect([TokenType]::BLOCK_END)
            
            # Parse catch branch until we find {% endpowershell %}
            while ($true) {
                $currentToken = $this.Current()
                
                if ($null -eq $currentToken -or $currentToken.Type -eq [TokenType]::EOF) {
                    throw "Unexpected end of template. Expected: endpowershell"
                }
                
                # Check for {% endpowershell %}
                if ($currentToken.Type -eq [TokenType]::BLOCK_START) {
                    $nextToken = $this.PeekOffset(1)
                    if ($null -ne $nextToken -and $nextToken.Type -eq [TokenType]::KEYWORD -and 
                        $nextToken.Value -eq 'endpowershell') {
                        break
                    }
                }
                
                $statement = $this.ParseStatement()
                if ($null -ne $statement) {
                    $psBlockNode.CatchBranch += $statement
                } else {
                    if ($this.Position -lt $this.Tokens.Count) {
                        $this.Position++
                    } else {
                        throw "Unexpected end of template. Expected: endpowershell"
                    }
                }
            }
        }
        
        # Consume {% endpowershell %}
        $this.Consume() # BLOCK_START
        $this.Consume() # endpowershell
        $this.Expect([TokenType]::BLOCK_END)
        
        return $psBlockNode
    }
    
    [IfNode]ParseIf([Token]$startToken) {
        Write-Host "ParseIf: Starting to parse if block"
        $condition = $this.ParseExpression()
        $this.Expect([TokenType]::BLOCK_END)
        
        Write-Host "ParseIf: Created IfNode with condition"
        $ifNode = [IfNode]::new($condition, $startToken.Line, $startToken.Column, $startToken.Filename)
        
        # Parse then branch
        Write-Host "ParseIf: Starting to parse then branch"
        while ($true) {
            # Check for else/elif/endif tag
            if (($this.Position + 1) -lt $this.Tokens.Count) {
                $currentToken = $this.Current()
                $nextToken = $this.PeekOffset(1)
                
                Write-Host "ParseIf: Current token: $($currentToken.Type), Value: '$($currentToken.Value)'"
                Write-Host "ParseIf: Next token: $($nextToken.Type), Value: '$($nextToken.Value)'"
                
                # Check if we've reached the else/elif/endif tag
                if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
                    $nextToken.Type -eq [TokenType]::KEYWORD -and 
                    $nextToken.Value -in @('else', 'elif', 'endif')) {
                    Write-Host "ParseIf: Found else/elif/endif tag: $($nextToken.Value)"
                    
                    # Handle the tag based on its type
                    if ($nextToken.Value -eq 'else') {
                        # Handle else tag
                        Write-Host "ParseIf: Processing else tag"
                        $this.Consume() # BLOCK_START
                        $this.Consume() # else
                        $this.Expect([TokenType]::BLOCK_END)
                        Write-Host "ParseIf: Consumed else tag"
                        
                        # Parse else branch
                        Write-Host "ParseIf: Starting to parse else branch"
                        while ($true) {
                            # Check for endif or elif tag (elif should not appear in else branch, but we check to prevent infinite loop)
                            if (($this.Position + 1) -lt $this.Tokens.Count) {
                                $currentToken = $this.Current()
                                $nextToken = $this.PeekOffset(1)
                                
                                Write-Host "ParseIf: (else branch) Current token: $($currentToken.Type), Value: '$($currentToken.Value)'"
                                Write-Host "ParseIf: (else branch) Next token: $($nextToken.Type), Value: '$($nextToken.Value)'"
                                
                                # Check if we've reached the endif or elif tag
                                if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
                                    $nextToken.Type -eq [TokenType]::KEYWORD -and 
                                    $nextToken.Value -in @('endif', 'elif')) {
                                    Write-Host "ParseIf: (else branch) Found $($nextToken.Value) tag"
                                    break
                                }
                                
                                # Check if we've reached EOF
                                if ($currentToken.Type -eq [TokenType]::EOF) {
                                    Write-Host "ParseIf: (else branch) Reached EOF without finding endif"
                                    throw "Unexpected end of template. Expected: endif"
                                }
                            } else {
                                Write-Host "ParseIf: (else branch) Reached end of tokens without finding endif"
                                throw "Unexpected end of template. Expected: endif"
                            }
                            
                            $statement = $this.ParseStatement()
                            if ($null -ne $statement) {
                                $ifNode.ElseBranch += $statement
                            }
                        }
                        
                        # Consume endif after parsing else branch
                        Write-Host "ParseIf: Consuming endif tag after else branch"
                        $this.Consume() # BLOCK_START
                        $this.Consume() # endif
                        $this.Expect([TokenType]::BLOCK_END)
                        Write-Host "ParseIf: Consumed endif tag after else branch"
                        return $ifNode
                    }
                    elseif ($nextToken.Value -eq 'elif') {
                        # Handle elif tag
                        Write-Host "ParseIf: Processing elif tag"
                        $this.Consume() # BLOCK_START
                        $this.Consume() # elif
                        $ifNode.ElifBranch = $this.ParseElif($startToken)
                        return $ifNode
                    }
                    elseif ($nextToken.Value -eq 'endif') {
                        # Handle endif tag
                        Write-Host "ParseIf: Processing endif tag"
                        $this.Consume() # BLOCK_START
                        $this.Consume() # endif
                        $this.Expect([TokenType]::BLOCK_END)
                        Write-Host "ParseIf: Consumed endif tag"
                        return $ifNode
                    }
                    
                    break
                }
                
                # Check if we've reached EOF
                if ($currentToken.Type -eq [TokenType]::EOF) {
                    throw "Unexpected end of template. Expected: endif"
                }
            } else {
                throw "Unexpected end of template. Expected: endif"
            }
            
            $statement = $this.ParseStatement()
            if ($null -ne $statement) {
                $ifNode.ThenBranch += $statement
            }
        }
        
        # If we get here, something went wrong
        Write-Host "ParseIf: ERROR - Unexpected end of if block"
        throw "Unexpected end of if block"
    }
    
    [IfNode]ParseElif([Token]$startToken) {
        Write-Host "ParseElif: Starting to parse elif block"
        $condition = $this.ParseExpression()
        $this.Expect([TokenType]::BLOCK_END)
        
        Write-Host "ParseElif: Created IfNode with condition"
        $elifNode = [IfNode]::new($condition, $startToken.Line, $startToken.Column, $startToken.Filename)
        
        # Parse elif branch
        Write-Host "ParseElif: Starting to parse elif branch"
        while ($true) {
            # Check for else/elif/endif tag
            if (($this.Position + 1) -lt $this.Tokens.Count) {
                $currentToken = $this.Current()
                $nextToken = $this.PeekOffset(1)
                
                Write-Host "ParseElif: Current token: $($currentToken.Type), Value: '$($currentToken.Value)'"
                Write-Host "ParseElif: Next token: $($nextToken.Type), Value: '$($nextToken.Value)'"
                
                # Check if we've reached the else/elif/endif tag
                if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
                    $nextToken.Type -eq [TokenType]::KEYWORD -and 
                    $nextToken.Value -in @('else', 'elif', 'endif')) {
                    Write-Host "ParseElif: Found else/elif/endif tag: $($nextToken.Value)"
                    break
                }
                
                # Check if we've reached EOF
                if ($currentToken.Type -eq [TokenType]::EOF) {
                    Write-Host "ParseElif: Reached EOF without finding else/elif/endif"
                    throw "Unexpected end of template. Expected: endif"
                }
            } else {
                Write-Host "ParseElif: Reached end of tokens without finding else/elif/endif"
                throw "Unexpected end of template. Expected: endif"
            }
            
            $statement = $this.ParseStatement()
            if ($null -ne $statement) {
                Write-Host "ParseElif: Adding statement to ThenBranch"
                $elifNode.ThenBranch += $statement
            }
        }
        
        # Handle nested else/elif
        $currentToken = $this.Current()
        $nextToken = $this.PeekOffset(1)
        
        if ($currentToken.Type -eq [TokenType]::BLOCK_START -and $nextToken.Type -eq [TokenType]::KEYWORD -and $nextToken.Value -eq 'elif') {
            Write-Host "ParseElif: Found nested elif tag"
            $this.Consume() # BLOCK_START
            $this.Consume() # elif
            $elifNode.ElifBranch = $this.ParseElif($startToken)
            return $elifNode
        } elseif ($currentToken.Type -eq [TokenType]::BLOCK_START -and $nextToken.Type -eq [TokenType]::KEYWORD -and $nextToken.Value -eq 'else') {
            Write-Host "ParseElif: Found else tag"
            $this.Consume() # BLOCK_START
            $this.Consume() # else
            $this.Expect([TokenType]::BLOCK_END)
            Write-Host "ParseElif: Consumed else tag"
            
            # Parse else branch
            Write-Host "ParseElif: Starting to parse else branch"
            while ($true) {
                # Check for endif tag
                if (($this.Position + 1) -lt $this.Tokens.Count) {
                    $currentToken = $this.Current()
                    $nextToken = $this.PeekOffset(1)
                    
                    Write-Host "ParseElif: (else branch) Current token: $($currentToken.Type), Value: '$($currentToken.Value)'"
                    Write-Host "ParseElif: (else branch) Next token: $($nextToken.Type), Value: '$($nextToken.Value)'"
                    
                    # Check if we've reached the endif tag
                    if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
                        $nextToken.Type -eq [TokenType]::KEYWORD -and 
                        $nextToken.Value -eq 'endif') {
                        Write-Host "ParseElif: (else branch) Found endif tag"
                        break
                    }
                    
                    # Check if we've reached EOF
                    if ($currentToken.Type -eq [TokenType]::EOF) {
                        Write-Host "ParseElif: (else branch) Reached EOF without finding endif"
                        throw "Unexpected end of template. Expected: endif"
                    }
                } else {
                    Write-Host "ParseElif: (else branch) Reached end of tokens without finding endif"
                    throw "Unexpected end of template. Expected: endif"
                }
                
                $statement = $this.ParseStatement()
                if ($null -ne $statement) {
                    Write-Host "ParseElif: (else branch) Adding statement to ElseBranch"
                    $elifNode.ElseBranch += $statement
                }
            }
            
            # Consume endif after parsing else branch
            Write-Host "ParseElif: Consuming endif tag after else branch"
            $this.Consume() # BLOCK_START
            $this.Consume() # endif
            $this.Expect([TokenType]::BLOCK_END)
            Write-Host "ParseElif: Consumed endif tag after else branch"
            return $elifNode
        } elseif ($currentToken.Type -eq [TokenType]::BLOCK_START -and $nextToken.Type -eq [TokenType]::KEYWORD -and $nextToken.Value -eq 'endif') {
            Write-Host "ParseElif: Found endif tag"
            $this.Consume() # BLOCK_START
            $this.Consume() # endif
            $this.Expect([TokenType]::BLOCK_END)
            Write-Host "ParseElif: Consumed endif tag"
        } else {
            Write-Host "ParseElif: ERROR - Expected endif tag but found something else"
            Write-Host "ParseElif: Current position: $($this.Position), Tokens count: $($this.Tokens.Count)"
            if ($this.Position -lt $this.Tokens.Count) {
                Write-Host "ParseElif: Current token: $($this.Current().Type), Value: '$($this.Current().Value)'"
                if (($this.Position + 1) -lt $this.Tokens.Count) {
                    Write-Host "ParseElif: Next token: $($this.PeekOffset(1).Type), Value: '$($this.PeekOffset(1).Value)'"
                }
            }
            throw "Expected endif tag"
        }
        
        return $elifNode
    }
    
    [ForNode]ParseFor([Token]$startToken) {
        Write-Verbose "ParseFor called"
        $variable = $this.Expect([TokenType]::IDENTIFIER).Value
        Write-Verbose "Variable: $variable"
        
        $this.Expect([TokenType]::KEYWORD, "in")
        Write-Verbose "Found 'in' keyword"
        
        $iterable = $this.ParseExpression()
        Write-Verbose "Parsed iterable expression"
        
        $this.Expect([TokenType]::BLOCK_END)
        Write-Verbose "Found block end"
        
        $forNode = [ForNode]::new($variable, $iterable, $startToken.Line, $startToken.Column, $startToken.Filename)
        Write-Verbose "Created ForNode"
        
        # Parse for body
        Write-Verbose "Starting to parse for body"
        
        while ($true) {
            Write-Verbose "In while loop, position: $($this.Position)"
            
            # Check for else/endfor tag
            if (($this.Position + 1) -lt $this.Tokens.Count) {
                $currentToken = $this.Current()
                $nextToken = $this.PeekOffset(1)
                
                Write-Verbose "Current token: $($currentToken.Type), Value: '$($currentToken.Value)'"
                if ($null -ne $nextToken) {
                    Write-Verbose "Next token: $($nextToken.Type), Value: '$($nextToken.Value)'"
                } else {
                    Write-Verbose "Next token: null"
                }
                
                # Check if we've reached the else or endfor tag
                if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
                    $nextToken.Type -eq [TokenType]::KEYWORD -and 
                    $nextToken.Value -in @('else', 'endfor')) {
                    Write-Verbose "Found else/endfor tag: $($nextToken.Value)"
                    break
                }
                
                # Check if we've reached EOF
                if ($currentToken.Type -eq [TokenType]::EOF) {
                    Write-Verbose "Reached EOF without finding endfor"
                    throw "Unexpected end of template. Expected: endfor"
                }
            } else {
                Write-Verbose "Reached end of tokens without finding endfor"
                throw "Unexpected end of template. Expected: endfor"
            }
            
            $statement = $this.ParseStatement()
            if ($null -ne $statement) {
                Write-Verbose "Parsed statement: $($statement.GetType().Name)"
                $forNode.Body += $statement
                Write-Verbose "Added statement to body"
            }
        }
        
        Write-Verbose "Exited while loop"
        
        # Check for {% else %} block
        $currentToken = $this.Current()
        $nextToken = $this.PeekOffset(1)
        
        if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
            $nextToken.Type -eq [TokenType]::KEYWORD -and 
            $nextToken.Value -eq 'else') {
            
            Write-Verbose "Found else tag, parsing else branch"
            $this.Consume() # BLOCK_START
            $this.Consume() # else
            $this.Expect([TokenType]::BLOCK_END)
            
            # Parse else branch until we find {% endfor %}
            while ($true) {
                $currentToken = $this.Current()
                
                if ($null -eq $currentToken -or $currentToken.Type -eq [TokenType]::EOF) {
                    throw "Unexpected end of template. Expected: endfor"
                }
                
                # Check for {% endfor %}
                if ($currentToken.Type -eq [TokenType]::BLOCK_START) {
                    $nextToken = $this.PeekOffset(1)
                    if ($null -ne $nextToken -and $nextToken.Type -eq [TokenType]::KEYWORD -and 
                        $nextToken.Value -eq 'endfor') {
                        Write-Verbose "Found endfor tag in else branch"
                        break
                    }
                }
                
                $statement = $this.ParseStatement()
                if ($null -ne $statement) {
                    $forNode.ElseBranch += $statement
                } else {
                    if ($this.Position -lt $this.Tokens.Count) {
                        $this.Position++
                    } else {
                        throw "Unexpected end of template. Expected: endfor"
                    }
                }
            }
        }
        
        # Consume endfor
        if ($this.Match([TokenType]::BLOCK_START) -and $this.PeekOffset(1).Value -eq 'endfor') {
            $this.Consume() # BLOCK_START
            $this.Consume() # endfor
            $this.Expect([TokenType]::BLOCK_END)
        }
        
        return $forNode
    }
    
    # Parse a set statement {% set variable = value %}
    [SetNode]ParseSet([Token]$startToken) {
        # Expect variable name
        $variableName = $this.Expect([TokenType]::IDENTIFIER).Value
        
        # Expect '=' operator
        $this.Expect([TokenType]::OPERATOR, "=")
        
        # Parse the value expression
        $value = $this.ParseExpression()
        
        # Expect closing %}
        $this.Expect([TokenType]::BLOCK_END)
        
        return [SetNode]::new($variableName, $value, $startToken.Line, $startToken.Column, $startToken.Filename)
    }
    
    # Parse a macro definition {% macro name(param1, param2=default) %} ... {% endmacro %}
    [MacroNode]ParseMacro([Token]$startToken) {
        # Expect macro name
        $macroName = $this.Expect([TokenType]::IDENTIFIER).Value
        
        # Create macro node
        $macroNode = [MacroNode]::new($macroName, $startToken.Line, $startToken.Column, $startToken.Filename)
        
        # Expect opening parenthesis
        $this.Expect([TokenType]::PUNCTUATION, "(")
        
        # Parse parameters
        while (-not $this.MatchTypeValue([TokenType]::PUNCTUATION, ")")) {
            # Get parameter name
            $paramName = $this.Expect([TokenType]::IDENTIFIER).Value
            [void]$macroNode.Parameters.Add($paramName)
            
            # Check for default value
            if ($this.MatchTypeValue([TokenType]::OPERATOR, "=")) {
                $this.Consume()  # Consume '='
                $defaultValue = $this.ParsePrimary()  # Parse default value (literal only)
                $macroNode.Defaults[$paramName] = $defaultValue
            }
            
            # Check for comma (more parameters)
            if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                $this.Consume()  # Consume ','
            } else {
                break
            }
        }
        
        # Expect closing parenthesis
        $this.Expect([TokenType]::PUNCTUATION, ")")
        
        # Expect closing %}
        $this.Expect([TokenType]::BLOCK_END)
        
        # Parse macro body until {% endmacro %}
        while ($true) {
            $currentToken = $this.Current()
            
            if ($null -eq $currentToken -or $currentToken.Type -eq [TokenType]::EOF) {
                throw "Unexpected end of template. Expected: endmacro"
            }
            
            # Check for {% endmacro %}
            if ($currentToken.Type -eq [TokenType]::BLOCK_START) {
                $nextToken = $this.PeekOffset(1)
                if ($null -ne $nextToken -and $nextToken.Type -eq [TokenType]::KEYWORD -and 
                    $nextToken.Value -eq 'endmacro') {
                    break
                }
            }
            
            $statement = $this.ParseStatement()
            if ($null -ne $statement) {
                $macroNode.Body += $statement
            } else {
                if ($this.Position -lt $this.Tokens.Count) {
                    $this.Position++
                } else {
                    throw "Unexpected end of template. Expected: endmacro"
                }
            }
        }
        
        # Consume {% endmacro %}
        $this.Consume()  # BLOCK_START
        $this.Consume()  # endmacro
        $this.Expect([TokenType]::BLOCK_END)
        
        return $macroNode
    }
    
    # Parse a call block {% call macroname() %} or {% call(param1, param2) macroname() %} ... {% endcall %}
    [CallNode]ParseCall([Token]$startToken) {
        # Check for parameters: {% call(param1, param2) ... %}
        if ($this.MatchTypeValue([TokenType]::PUNCTUATION, "(")) {
            $this.Consume()  # Consume '('
            
            # Create call node first (we'll set MacroCall later)
            $callNode = [CallNode]::new($null, $startToken.Line, $startToken.Column, $startToken.Filename)
            
            # Parse parameter names
            while (-not $this.MatchTypeValue([TokenType]::PUNCTUATION, ")")) {
                $param = $this.Expect([TokenType]::IDENTIFIER).Value
                [void]$callNode.Parameters.Add($param)
                
                # Check for comma (more parameters)
                if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                    $this.Consume()  # Consume ','
                } else {
                    break
                }
            }
            
            $this.Expect([TokenType]::PUNCTUATION, ")")  # Consume ')'
            
            # Now parse the macro call expression
            $callNode.MacroCall = $this.ParseMacroCallExpression()
        } else {
            # No parameters, parse macro call directly
            $macroCall = $this.ParseMacroCallExpression()
            $callNode = [CallNode]::new($macroCall, $startToken.Line, $startToken.Column, $startToken.Filename)
        }
        
        # Expect closing %}
        $this.Expect([TokenType]::BLOCK_END)
        
        # Parse call body until {% endcall %}
        while ($true) {
            $currentToken = $this.Current()
            
            if ($null -eq $currentToken -or $currentToken.Type -eq [TokenType]::EOF) {
                throw "Unexpected end of template. Expected: endcall"
            }
            
            # Check for {% endcall %}
            if ($currentToken.Type -eq [TokenType]::BLOCK_START) {
                $nextToken = $this.PeekOffset(1)
                if ($null -ne $nextToken -and $nextToken.Type -eq [TokenType]::KEYWORD -and 
                    $nextToken.Value -eq 'endcall') {
                    break
                }
            }
            
            $statement = $this.ParseStatement()
            if ($null -ne $statement) {
                $callNode.Body += $statement
            } else {
                if ($this.Position -lt $this.Tokens.Count) {
                    $this.Position++
                } else {
                    throw "Unexpected end of template. Expected: endcall"
                }
            }
        }
        
        # Consume {% endcall %}
        $this.Consume()  # BLOCK_START
        $this.Consume()  # endcall
        $this.Expect([TokenType]::BLOCK_END)
        
        return $callNode
    }
    
    # Parse an import statement {% import 'template.html' as forms %}
    [ImportNode]ParseImport([Token]$startToken) {
        # Parse template expression
        $template = $this.ParseExpression()
        
        # Expect 'as' keyword
        if (-not $this.MatchTypeValue([TokenType]::IDENTIFIER, "as")) {
            throw "Expected 'as' after template name in import statement"
        }
        $this.Consume()  # Consume 'as'
        
        # Expect alias name
        $alias = $this.Expect([TokenType]::IDENTIFIER).Value
        
        # Expect closing %}
        $this.Expect([TokenType]::BLOCK_END)
        
        return [ImportNode]::new($template, $alias, $startToken.Line, $startToken.Column, $startToken.Filename)
    }
    
    # Parse a from-import statement {% from 'template.html' import macro1, macro2 as m2 %}
    [FromImportNode]ParseFromImport([Token]$startToken) {
        # Parse template expression
        $template = $this.ParseExpression()
        
        # Expect 'import' keyword
        if (-not $this.MatchTypeValue([TokenType]::KEYWORD, "import")) {
            throw "Expected 'import' after template name in from statement"
        }
        $this.Consume()  # Consume 'import'
        
        # Create from-import node
        $fromImportNode = [FromImportNode]::new($template, $startToken.Line, $startToken.Column, $startToken.Filename)
        
        # Parse macro names
        while ($true) {
            # Get macro name
            $macroName = $this.Expect([TokenType]::IDENTIFIER).Value
            [void]$fromImportNode.MacroNames.Add($macroName)
            
            # Check for 'as' alias
            if ($this.MatchTypeValue([TokenType]::IDENTIFIER, "as")) {
                $this.Consume()  # Consume 'as'
                $aliasName = $this.Expect([TokenType]::IDENTIFIER).Value
                $fromImportNode.Aliases[$macroName] = $aliasName
            }
            
            # Check for comma (more macros)
            if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                $this.Consume()  # Consume ','
            } else {
                break
            }
        }
        
        # Expect closing %}
        $this.Expect([TokenType]::BLOCK_END)
        
        return $fromImportNode
    }
    
    # Helper method to parse a macro call expression (used in both {{ }} and {% call %})
    [MacroCallNode]ParseMacroCallExpression() {
        # Expect macro name
        $macroName = $this.Expect([TokenType]::IDENTIFIER).Value
        
        # Create macro call node
        $macroCall = [MacroCallNode]::new($macroName, $this.Current().Line, $this.Current().Column, $this.Current().Filename)
        
        # Expect opening parenthesis
        $this.Expect([TokenType]::PUNCTUATION, "(")
        
        # Parse arguments
        while (-not $this.MatchTypeValue([TokenType]::PUNCTUATION, ")")) {
            # Check if this is a named argument (name=value)
            if ($this.Match([TokenType]::IDENTIFIER)) {
                $lookahead = $this.PeekOffset(1)
                if ($null -ne $lookahead -and $lookahead.Type -eq [TokenType]::OPERATOR -and $lookahead.Value -eq '=') {
                    # Named argument
                    $argName = $this.Consume().Value
                    $this.Consume()  # Consume '='
                    $argValue = $this.ParseExpression()
                    $macroCall.NamedArguments[$argName] = $argValue
                } else {
                    # Positional argument
                    $arg = $this.ParseExpression()
                    [void]$macroCall.Arguments.Add($arg)
                }
            } else {
                # Positional argument
                $arg = $this.ParseExpression()
                [void]$macroCall.Arguments.Add($arg)
            }
            
            # Check for comma (more arguments)
            if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                $this.Consume()  # Consume ','
            } else {
                break
            }
        }
        
        # Expect closing parenthesis
        $this.Expect([TokenType]::PUNCTUATION, ")")
        
        return $macroCall
    }
    
    # Parse a comment block {# ... #}
    # Comments are ignored in the output but we return a CommentNode to track them
    [CommentNode]ParseComment() {
        $startToken = $this.Expect([TokenType]::COMMENT_START)  # Consume the {# token
        $this.Expect([TokenType]::COMMENT_END)    # Consume the #} token
        # Return a CommentNode so parsing loops know the comment was processed
        return [CommentNode]::new($startToken.Line, $startToken.Column, $startToken.Filename)
    }
    
    # Parse an expression (entry point for expression parsing)
    # Expressions can be variables, literals, operators, function calls, etc.
    [ExpressionNode]ParseExpression() {
        # Start with the lowest precedence operator (conditional/ternary)
        return $this.ParseConditional()
    }
    
    # Parse conditional (ternary) expressions (e.g., 'yes' if foo else 'no')
    # This has the lowest precedence in the expression hierarchy
    [ExpressionNode]ParseConditional() {
        # First, parse the true value (which could be any expression with filters)
        $trueValue = $this.ParseFilter()
        
        # Check if this is a conditional expression by looking for 'if' keyword
        if ($this.MatchTypeValue([TokenType]::KEYWORD, "if")) {
            $ifToken = $this.Consume()  # Consume 'if'
            
            # Parse the condition (without filters, as filters don't make sense in conditions)
            $condition = $this.ParseLogicalOr()
            
            # Expect 'else' keyword
            if (-not $this.MatchTypeValue([TokenType]::KEYWORD, "else")) {
                throw "Expected 'else' in conditional expression at line $($ifToken.Line), column $($ifToken.Column)"
            }
            $this.Consume()  # Consume 'else'
            
            # Parse the false value (which can also be a conditional expression for nesting)
            $falseValue = $this.ParseConditional()
            
            # Create and return a conditional expression node
            return [ConditionalExpressionNode]::new($trueValue, $condition, $falseValue, $ifToken.Line, $ifToken.Column, $ifToken.Filename)
        }
        
        # If no 'if' keyword found, just return the expression we parsed
        return $trueValue
    }
    
    # Parse filter expressions (e.g., name | upper | trim)
    # Filters have higher precedence than conditional but lower than logical operators
    [ExpressionNode]ParseFilter() {
        # Start with logical OR (which includes all higher precedence operators)
        $expr = $this.ParseLogicalOr()
        
        # Check for filters (e.g., name | upper)
        while ($this.Match([TokenType]::PIPE)) {
            $pipeToken = $this.Consume()  # Consume the pipe
            $filterNameToken = $this.Expect([TokenType]::IDENTIFIER, $null)  # Expect filter name
            # Create a filter node
            $filterNode = [FilterNode]::new($expr, $filterNameToken.Value, $pipeToken.Line, $pipeToken.Column, $pipeToken.Filename)
            
            # Check for filter arguments (e.g., date | format("yyyy-MM-dd"))
            if ($this.MatchTypeValue([TokenType]::PUNCTUATION, "(")) {
                $this.Consume() # Consume '('
                
                # Parse arguments
                while (-not $this.MatchTypeValue([TokenType]::PUNCTUATION, ")")) {
                    $arg = $this.ParseConditional()  # Parse argument expression (can include conditionals)
                    $filterNode.Arguments += $arg   # Add to arguments list
                    
                    # Check for comma (multiple arguments)
                    if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                        $this.Consume() # Consume ','
                    } else {
                        break
                    }
                }
                
                $this.Expect([TokenType]::PUNCTUATION, ")", $null)  # Expect closing parenthesis
            }
            
            $expr = $filterNode  # The filter node becomes the new expression
        }
        
        return $expr
    }
    
    # Parse logical OR expressions (e.g., a or b)
    # This has the lowest precedence in the expression hierarchy
    [ExpressionNode]ParseLogicalOr() {
        $left = $this.ParseLogicalAnd()  # Parse the left operand (higher precedence)
        
        # Look for OR operators and build a binary operation tree
        while ($this.MatchTypeValue([TokenType]::KEYWORD, "or")) {
            $operator = $this.Consume()  # Consume the 'or' operator
            $right = $this.ParseLogicalAnd()  # Parse the right operand
            # Create a binary operation node with the left and right operands
            $left = [BinaryOpNode]::new($operator.Value, $left, $right, $operator.Line, $operator.Column, $operator.Filename)
        }
        
        return $left
    }
    
    # Parse logical AND expressions (e.g., a and b)
    # Higher precedence than OR but lower than comparison operators
    [ExpressionNode]ParseLogicalAnd() {
        $left = $this.ParseComparison()  # Parse the left operand (higher precedence)
        
        # Look for AND operators and build a binary operation tree
        while ($this.MatchTypeValue([TokenType]::KEYWORD, "and")) {
            $operator = $this.Consume()  # Consume the 'and' operator
            $right = $this.ParseComparison()  # Parse the right operand
            # Create a binary operation node with the left and right operands
            $left = [BinaryOpNode]::new($operator.Value, $left, $right, $operator.Line, $operator.Column, $operator.Filename)
        }
        
        return $left
    }
    
    # Parse comparison expressions (e.g., a == b, x > y, 'item' in list)
    # Higher precedence than logical operators but lower than additive operators
    [ExpressionNode]ParseComparison() {
        $left = $this.ParseAdditive()  # Parse the left operand (higher precedence)
        
        # List of comparison operators
        $comparisonOps = @('==', '!=', '<', '>', '<=', '>=')
        
        # Look for comparison operators and build a binary operation tree
        while ($this.Match([TokenType]::OPERATOR) -and $this.Current().Value -in $comparisonOps) {
            $operator = $this.Consume()  # Consume the comparison operator
            $right = $this.ParseAdditive()  # Parse the right operand
            # Create a binary operation node with the left and right operands
            $left = [BinaryOpNode]::new($operator.Value, $left, $right, $operator.Line, $operator.Column, $operator.Filename)
        }
        
        # Check for 'in' operator (e.g., 'item' in list)
        if ($this.MatchTypeValue([TokenType]::KEYWORD, "in")) {
            $operator = $this.Consume()  # Consume the 'in' keyword
            $right = $this.ParseAdditive()  # Parse the right operand (the collection)
            # Create a binary operation node with the left and right operands
            $left = [BinaryOpNode]::new($operator.Value, $left, $right, $operator.Line, $operator.Column, $operator.Filename)
        }
        
        # Check for 'is' operator (e.g., variable is defined, number is even)
        if ($this.MatchTypeValue([TokenType]::KEYWORD, "is")) {
            $isToken = $this.Consume()  # Consume the 'is' keyword
            
            # Check for 'not' negation (e.g., variable is not defined)
            $negated = $false
            if ($this.MatchTypeValue([TokenType]::KEYWORD, "not")) {
                $this.Consume()  # Consume 'not'
                $negated = $true
            }
            
            # Expect a test name - can be either a keyword or identifier
            $testNameToken = $this.Current()
            if ($testNameToken.Type -eq [TokenType]::KEYWORD) {
                $this.Consume()
                $testName = $testNameToken.Value
            } elseif ($testNameToken.Type -eq [TokenType]::IDENTIFIER) {
                $this.Consume()
                $testName = $testNameToken.Value
            } else {
                throw "Expected test name after 'is' at line $($testNameToken.Line), column $($testNameToken.Column)"
            }
            
            # Validate test name
            $validTests = @('defined', 'undefined', 'none', 'null', 'even', 'odd', 'divisibleby', 'iterable', 
                           'number', 'string', 'mapping', 'sequence', 'sameas', 'lower', 'upper', 
                           'callable', 'equalto', 'escaped')
            if ($testName -notin $validTests) {
                throw "Unknown test name '$testName' at line $($testNameToken.Line), column $($testNameToken.Column)"
            }
            
            # Create an IsTestNode
            $isTestNode = [IsTestNode]::new($left, $testName, $negated, $isToken.Line, $isToken.Column, $isToken.Filename)
            
            # Check if this test requires arguments (divisibleby, sameas, equalto)
            if ($testName -in @('divisibleby', 'sameas', 'equalto')) {
                # Expect opening parenthesis
                $this.Expect([TokenType]::PUNCTUATION, "(")
                
                # Parse the argument
                $argument = $this.ParseAdditive()
                $isTestNode.Arguments += $argument
                
                # Expect closing parenthesis
                $this.Expect([TokenType]::PUNCTUATION, ")")
            }
            
            $left = $isTestNode
        }
        
        return $left
    }
    
    # Parse additive expressions (e.g., a + b, x - y)
    # Higher precedence than comparison operators but lower than multiplicative operators
    [ExpressionNode]ParseAdditive() {
        $left = $this.ParseMultiplicative()  # Parse the left operand (higher precedence)
        
        # List of additive operators
        $additiveOps = @('+', '-')
        
        # Look for additive operators and build a binary operation tree
        while ($this.Match([TokenType]::OPERATOR) -and $this.Current().Value -in $additiveOps) {
            $operator = $this.Consume()  # Consume the additive operator
            $right = $this.ParseMultiplicative()  # Parse the right operand
            # Create a binary operation node with the left and right operands
            $left = [BinaryOpNode]::new($operator.Value, $left, $right, $operator.Line, $operator.Column, $operator.Filename)
        }
        
        return $left
    }
    
    # Parse multiplicative expressions (e.g., a * b, x / y, z % w)
    # Higher precedence than additive operators but lower than primary expressions
    [ExpressionNode]ParseMultiplicative() {
        $left = $this.ParsePrimary()  # Parse the left operand (higher precedence)
        
        # List of multiplicative operators
        $multiplicativeOps = @('*', '/', '%')
        
        # Look for multiplicative operators and build a binary operation tree
        while ($this.Match([TokenType]::OPERATOR) -and $this.Current().Value -in $multiplicativeOps) {
            $operator = $this.Consume()  # Consume the multiplicative operator
            $right = $this.ParsePrimary()  # Parse the right operand
            # Create a binary operation node with the left and right operands
            $left = [BinaryOpNode]::new($operator.Value, $left, $right, $operator.Line, $operator.Column, $operator.Filename)
        }
        
        return $left
    }
    
    # Parse primary expressions (variables, literals, parenthesized expressions)
    # These have the highest precedence in the expression hierarchy
    [ExpressionNode]ParsePrimary() {
        $token = $this.Consume()  # Consume the token
        if ($null -eq $token) {
            throw "Unexpected end of input in expression"
        }
        
        [ExpressionNode]$expr = $null
        
        # Create the appropriate node based on the token type
        switch ($token.Type) {
            ([TokenType]::IDENTIFIER) {
                # Check for 'self' keyword for self.blockname() calls (Jinja2 compatibility)
                if ($token.Value -eq 'self') {
                    # Expect dot
                    $this.Expect([TokenType]::PUNCTUATION, ".")
                    # Get block name
                    $blockNameToken = $this.Expect([TokenType]::IDENTIFIER)
                    # Expect ()
                    $this.Expect([TokenType]::PUNCTUATION, "(")
                    $this.Expect([TokenType]::PUNCTUATION, ")")
                    
                    $expr = [SelfCallNode]::new($blockNameToken.Value, $token.Line, $token.Column, $token.Filename)
                }
                # Check if this is a macro call (identifier followed by '(')
                elseif ($this.MatchTypeValue([TokenType]::PUNCTUATION, "(")) {
                    # This is a macro call - backtrack and parse it
                    $this.Position--  # Go back to the identifier
                    $expr = $this.ParseMacroCallExpression()
                } else {
                    # Variable reference (e.g., user, item, etc.)
                    $expr = [VariableNode]::new($token.Value, $token.Line, $token.Column, $token.Filename)
                }
            }
            ([TokenType]::NUMBER) {
                # Numeric literal (integer or decimal)
                if ($token.Value -match '\.') {
                    $value = [double]$token.Value  # Decimal number
                } else {
                    $value = [int]$token.Value     # Integer number
                }
                $expr = [LiteralNode]::new($value, $token.Line, $token.Column, $token.Filename)
            }
            ([TokenType]::STRING) {
                # String literal
                $expr = [LiteralNode]::new($token.Value, $token.Line, $token.Column, $token.Filename)
            }
            ([TokenType]::KEYWORD) {
                # Boolean or null literals, or super() call
                switch ($token.Value.ToLower()) {
                    "true" { $expr = [LiteralNode]::new($true, $token.Line, $token.Column, $token.Filename) }
                    "false" { $expr = [LiteralNode]::new($false, $token.Line, $token.Column, $token.Filename) }
                    "null" { $expr = [LiteralNode]::new($null, $token.Line, $token.Column, $token.Filename) }
                    "none" { $expr = [LiteralNode]::new($null, $token.Line, $token.Column, $token.Filename) }
                    "super" {
                        # Expect parentheses after super
                        $this.Expect([TokenType]::PUNCTUATION, "(", $null)
                        $this.Expect([TokenType]::PUNCTUATION, ")", $null)
                        $expr = [SuperNode]::new($token.Line, $token.Column, $token.Filename)
                    }
                    default { throw "Unexpected keyword in expression: $($token.Value)" }
                }
            }
            ([TokenType]::PUNCTUATION) {
                # Parenthesized expression (e.g., (a + b)), array literal (e.g., [1, 2, 3]), or dict literal (e.g., {'key': 'value'})
                if ($token.Value -eq '(') {
                    $expr = $this.ParseExpression()  # Parse the expression inside the parentheses
                    $this.Expect([TokenType]::PUNCTUATION, ')', $null)  # Expect closing parenthesis
                }
                elseif ($token.Value -eq '[') {
                    # Array literal - parse elements
                    $elements = [System.Collections.Generic.List[ExpressionNode]]::new()
                    
                    # Parse array elements
                    while (-not $this.MatchTypeValue([TokenType]::PUNCTUATION, "]")) {
                        $element = $this.ParseExpression()
                        [void]$elements.Add($element)
                        
                        # Check for comma (multiple elements)
                        if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                            $this.Consume() # Consume ','
                        } else {
                            # No comma, expect closing bracket
                            break
                        }
                    }
                    
                    $this.Expect([TokenType]::PUNCTUATION, "]")
                    $expr = [ArrayLiteralNode]::new($elements.ToArray(), $token.Line, $token.Column, $token.Filename)
                }
                elseif ($token.Value -eq '{') {
                    # Dictionary literal - parse key-value pairs
                    $dictNode = [DictLiteralNode]::new($token.Line, $token.Column, $token.Filename)
                    
                    # Parse dictionary pairs
                    while (-not $this.MatchTypeValue([TokenType]::PUNCTUATION, "}")) {
                        # Parse key (must be a string or identifier)
                        $key = $this.ParseExpression()
                        
                        # Expect colon
                        $this.Expect([TokenType]::PUNCTUATION, ":")
                        
                        # Parse value
                        $value = $this.ParseExpression()
                        
                        # Add key-value pair using void to suppress output
                        [void]$dictNode.Pairs.Add([System.Tuple]::Create($key, $value))
                        
                        # Check for comma (multiple pairs)
                        if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                            $this.Consume() # Consume ','
                        } else {
                            # No comma, expect closing brace
                            break
                        }
                    }
                    
                    $this.Expect([TokenType]::PUNCTUATION, "}")
                    $expr = $dictNode
                }
            }
            default {
                throw "Unexpected token in expression: $($token.Type)"
            }
        }
        
        # Check for property access (e.g., user.name) or array indexing (e.g., array[0])
        while ($true) {
            if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ".")) {
                $dotToken = $this.Consume()  # Consume the dot
                $propertyToken = $this.Expect([TokenType]::IDENTIFIER)  # Expect property name
                # Create a property access node
                $expr = [PropertyAccessNode]::new($expr, $propertyToken.Value, $dotToken.Line, $dotToken.Column, $dotToken.Filename)
            }
            elseif ($this.MatchTypeValue([TokenType]::PUNCTUATION, "[")) {
                $bracketToken = $this.Consume()  # Consume the opening bracket
                $indexExpr = $this.ParseExpression()  # Parse the index expression
                $this.Expect([TokenType]::PUNCTUATION, "]")  # Expect closing bracket
                # Create an index access node
                $expr = [IndexAccessNode]::new($expr, $indexExpr, $bracketToken.Line, $bracketToken.Column, $bracketToken.Filename)
            }
            else {
                break
            }
        }
        
        return $expr
    }
}

### Compiler
# PowerShell compiler that transforms the AST into executable PowerShell code
# This is the third stage of template processing (compilation)
class PowershellCompiler {
    [System.Text.StringBuilder]$Code
    [int]$IndentLevel
    [hashtable]$Context
    [hashtable]$ParentBlocks  # Stores parent block content for super() calls
    [string]$CurrentBlock     # Name of the block currently being compiled
    [UndefinedBehavior]$UndefinedBehavior  # Behavior for undefined variables (Jinja2 compatibility)
    
    PowershellCompiler() {
        $this.Code = [System.Text.StringBuilder]::new()
        $this.IndentLevel = 0
        $this.Context = @{}
        $this.ParentBlocks = @{}
        $this.CurrentBlock = $null
        $this.UndefinedBehavior = [UndefinedBehavior]::Default
    }
    
    # Compile the AST into executable PowerShell code
    # This transforms the template structure into code that can render the template
    [string]Compile([TemplateNode]$template) {
        return $this.Compile($template, $false)
    }
    
    # Compile with option to skip block rendering (for inheritance)
    [string]Compile([TemplateNode]$template, [bool]$isChildTemplate) {
        # Reset the code builder and indentation
        $this.Code.Clear()
        $this.IndentLevel = 0
        
        # Generate the function header
        $this.AppendLine('param($Context, $TemplateDir = "")')  # Context parameter contains template variables, template directory for includes
        $this.AppendLine('$output = [System.Text.StringBuilder]::new()')  # Output buffer
        $this.AppendLine()
        
        # Make context variables available in the current scope
        $this.AppendLine('# Make context variables available in current scope')
        $this.AppendLine('foreach ($__key__ in $Context.Keys) {')
        $this.IndentLevel++
        $this.AppendLine('Set-Variable -Name $__key__ -Value $Context[$__key__]')
        $this.IndentLevel--
        $this.AppendLine('}')
        $this.AppendLine()
        
        # Initialize recursion depth tracking for self.blockname() calls
        $this.AppendLine('# Initialize recursion depth tracking for self.blockname() calls')
        $this.AppendLine('$__SELF_DEPTH__ = @{}')
        $this.AppendLine()
        
        # Collect ALL blocks from the entire AST (including nested blocks in loops, etc.)
        $allBlocks = $this.CollectAllBlocks($template)
        
        # Compile all blocks as functions BEFORE the main template body
        # This allows self.blockname() to call blocks from anywhere in the template
        if ($allBlocks.Count -gt 0) {
            $this.AppendLine('# Compile blocks as functions for self.blockname() support')
            foreach ($block in $allBlocks) {
                $this.CompileBlockAsFunction($block)
            }
        }
        
        # Process each node in the template body
        foreach ($node in $template.Body) {
            $this.Visit($node)
        }
        
        # Return the rendered output (trim trailing newline)
        $this.AppendLine()
        $this.AppendLine('return $output.ToString().TrimEnd("`r", "`n")')
        
        return $this.Code.ToString()
    }
    
    # Recursively collect all BlockNode instances from the AST
    [System.Collections.Generic.List[BlockNode]]CollectAllBlocks([TemplateNode]$template) {
        $blocks = [System.Collections.Generic.List[BlockNode]]::new()
        $this.CollectBlocksFromStatements($template.Body, $blocks)
        return $blocks
    }
    
    # Helper method to recursively collect blocks from statements
    [void]CollectBlocksFromStatements([StatementNode[]]$statements, [System.Collections.Generic.List[BlockNode]]$blocks) {
        foreach ($statement in $statements) {
            if ($statement -is [BlockNode]) {
                $blocks.Add([BlockNode]$statement)
            }
            elseif ($statement -is [ForNode]) {
                $forNode = [ForNode]$statement
                $this.CollectBlocksFromStatements($forNode.Body, $blocks)
                $this.CollectBlocksFromStatements($forNode.ElseBranch, $blocks)
            }
            elseif ($statement -is [IfNode]) {
                $ifNode = [IfNode]$statement
                $this.CollectBlocksFromStatements($ifNode.ThenBranch, $blocks)
                $this.CollectBlocksFromStatements($ifNode.ElseBranch, $blocks)
                if ($null -ne $ifNode.ElifBranch) {
                    $this.CollectBlocksFromStatements($ifNode.ElifBranch.ThenBranch, $blocks)
                    $this.CollectBlocksFromStatements($ifNode.ElifBranch.ElseBranch, $blocks)
                }
            }
        }
    }
    
    # Compile a block as a callable function for self.blockname() support (Jinja2 compatibility)
    # Each block becomes a function that can be called from anywhere in the template
    [void]CompileBlockAsFunction([BlockNode]$block) {
        $this.CompileBlockAsFunction($block, $false)
    }
    
    # Compile a block as a callable function with option to compile as parent block
    [void]CompileBlockAsFunction([BlockNode]$block, [bool]$isParentBlock) {
        $functionName = if ($isParentBlock) { "__PARENT_BLOCK_$($block.Name)__" } else { "__BLOCK_$($block.Name)__" }
        
        $this.AppendLine("# Block function: $($block.Name)$(if ($isParentBlock) { ' (parent)' })")
        
        # For scoped blocks, we need to accept all current scope variables as parameters
        # This allows blocks inside loops to access loop variables
        if ($block.Scoped) {
            $this.AppendLine("function script:$functionName {")
            $this.IndentLevel++
            $this.AppendLine("param([hashtable]`$__scope_vars__ = @{})")
            $this.AppendLine()
            $this.AppendLine("# Import scope variables")
            $this.AppendLine("foreach (`$__var_name__ in `$__scope_vars__.Keys) {")
            $this.IndentLevel++
            $this.AppendLine("Set-Variable -Name `$__var_name__ -Value `$__scope_vars__[`$__var_name__]")
            $this.IndentLevel--
            $this.AppendLine("}")
            $this.AppendLine()
        } else {
            $this.AppendLine("function script:$functionName {")
            $this.IndentLevel++
        }
        
        # Check recursion depth to prevent infinite loops (only for non-parent blocks)
        if (-not $isParentBlock) {
            $this.AppendLine("# Check recursion depth")
            $this.AppendLine("if (-not `$__SELF_DEPTH__.ContainsKey('$($block.Name)')) {")
            $this.IndentLevel++
            $this.AppendLine("`$__SELF_DEPTH__['$($block.Name)'] = 0")
            $this.IndentLevel--
            $this.AppendLine("}")
            
            $this.AppendLine("if (`$__SELF_DEPTH__['$($block.Name)'] -ge [TemplateEngine]::MaxSelfRecursionDepth) {")
            $this.IndentLevel++
            $this.AppendLine("throw `"Maximum self recursion depth exceeded for block '$($block.Name)'`"")
            $this.IndentLevel--
            $this.AppendLine("}")
            
            $this.AppendLine("`$__SELF_DEPTH__['$($block.Name)']++")
            $this.AppendLine()
        }
        
        # Create output buffer for block
        $this.AppendLine("`$__block_output__ = [System.Text.StringBuilder]::new()")
        
        # Compile block body with a separate compiler instance to avoid mixing code
        $blockCompiler = [PowershellCompiler]::new()
        $blockCompiler.CurrentBlock = $block.Name
        $blockCompiler.ParentBlocks = $this.ParentBlocks
        # IMPORTANT: Start with IndentLevel = 0 to avoid adding extra indentation
        $blockCompiler.IndentLevel = 0
        
        foreach ($statement in $block.Body) {
            $blockCompiler.Visit($statement)
        }
        
        $blockCode = $blockCompiler.Code.ToString()
        
        # Replace $output with $__block_output__
        $blockCode = $blockCode.Replace('$output.Append', '$__block_output__.Append')
        
        # Add the modified code WITHOUT additional indentation
        # We add it directly to preserve the original formatting
        $this.Code.Append($blockCode)
        
        # Decrement recursion depth (only for non-parent blocks)
        if (-not $isParentBlock) {
            $this.AppendLine()
            $this.AppendLine("`$__SELF_DEPTH__['$($block.Name)']--")
        }
        
        # Return block output (trim only trailing spaces/tabs, preserve newlines)
        $this.AppendLine("`$__block_result__ = `$__block_output__.ToString()")
        $this.AppendLine("`$__block_result__ = `$__block_result__ -replace '[ \t]+`$', ''")
        $this.AppendLine("return `$__block_result__")
        
        $this.IndentLevel--
        $this.AppendLine("}")
        $this.AppendLine()
    }
    
    # Visit an AST node and generate the corresponding PowerShell code
    # This is the main dispatcher for the code generation process
    [void]Visit([ASTNode]$node) {
        # Call the appropriate visitor method based on the node type
        switch ($node.GetType().Name) {
            "TextNode" { $this.VisitText([TextNode]$node) }           # Static text content
            "OutputNode" { $this.VisitOutput([OutputNode]$node) }     # Variable output {{ ... }}
            "IfNode" { $this.VisitIf([IfNode]$node) }                 # Conditional block {% if ... %}
            "ForNode" { $this.VisitFor([ForNode]$node) }              # Loop block {% for ... %}
            "BlockNode" { $this.VisitBlock([BlockNode]$node) }        # Named block {% block ... %}
            "ExtendsNode" { $this.VisitExtends([ExtendsNode]$node) }  # Template inheritance {% extends ... %}
            "IncludeNode" { $this.VisitInclude([IncludeNode]$node) }  # Template inclusion {% include ... %}
            "RawNode" { $this.VisitRaw([RawNode]$node) }              # Raw block {% raw ... %}
            "PowerShellBlockNode" { $this.VisitPowerShellBlock([PowerShellBlockNode]$node) }  # PowerShell execution block {% powershell ... %}
            "SetNode" { $this.VisitSet([SetNode]$node) }              # Variable assignment {% set ... %}
            "MacroNode" { $this.VisitMacro([MacroNode]$node) }        # Macro definition {% macro ... %}
            "CallNode" { $this.VisitCall([CallNode]$node) }           # Call block {% call ... %}
            "ImportNode" { $this.VisitImport([ImportNode]$node) }     # Import statement {% import ... %}
            "FromImportNode" { $this.VisitFromImport([FromImportNode]$node) }  # From-import statement {% from ... import ... %}
            "CommentNode" { return }  # Comments are ignored during compilation
            default { throw "Unknown node type: $($node.GetType().Name)" }
        }
    }
    
    [void]VisitBlock([BlockNode]$node) {
        # Blocks are now compiled as functions in Compile() method
        # They are always rendered by calling their function
        
        $this.AppendLine("# Block: $($node.Name)")
        
        # For scoped blocks, pass current scope variables
        if ($node.Scoped) {
            $this.AppendLine("# Collect current scope variables for scoped block")
            $this.AppendLine("`$__current_scope__ = @{}")
            $this.AppendLine("Get-Variable | Where-Object { `$_.Name -notmatch '^(__.*__|output|Context|TemplateDir|LoopItems|LoopLength|LoopIndex0)$' } | ForEach-Object {")
            $this.IndentLevel++
            $this.AppendLine("`$__current_scope__[`$_.Name] = `$_.Value")
            $this.IndentLevel--
            $this.AppendLine("}")
            $this.AppendLine("`$output.Append((& __BLOCK_$($node.Name)__ -__scope_vars__ `$__current_scope__)) | Out-Null")
        } else {
            $this.AppendLine("`$output.Append((& __BLOCK_$($node.Name)__)) | Out-Null")
        }
    }
    
    # Helper method to check if a statement contains super() calls
    [bool]ContainsSuper([StatementNode]$statement) {
        if ($statement -is [OutputNode]) {
            return $this.ExpressionContainsSuper(([OutputNode]$statement).Expression)
        }
        return $false
    }
    
    # Helper method to check if an expression contains super() calls
    [bool]ExpressionContainsSuper([ExpressionNode]$expr) {
        if ($expr -is [SuperNode]) {
            return $true
        }
        if ($expr -is [FilterNode]) {
            return $this.ExpressionContainsSuper(([FilterNode]$expr).Expression)
        }
        if ($expr -is [BinaryOpNode]) {
            $binOp = [BinaryOpNode]$expr
            return $this.ExpressionContainsSuper($binOp.Left) -or $this.ExpressionContainsSuper($binOp.Right)
        }
        if ($expr -is [PropertyAccessNode]) {
            return $this.ExpressionContainsSuper(([PropertyAccessNode]$expr).Object)
        }
        return $false
    }
    
    [void]VisitExtends([ExtendsNode]$node) {
        # TODO:
        # In a real implementation, this would load the parent template and apply inheritance
        # For now, we'll just add a comment
        $parentTemplate = $this.VisitExpression($node.Parent)
        $this.AppendLine("# Extends template: $parentTemplate")
    }
    
    [void]VisitInclude([IncludeNode]$node) {
        # Get the template name from the expression
        $templateExpr = $node.Template
        $ignoreMissing = $node.IgnoreMissing
        
        # Check if this is an array of template paths (fallback support)
        if ($templateExpr -is [ArrayLiteralNode]) {
            $arrayNode = [ArrayLiteralNode]$templateExpr
            
            # Generate code to try each template in order
            $this.AppendLine("# Include template with fallback (array of paths)")
            $this.AppendLine("`$__include_found__ = `$false")
            
            for ($i = 0; $i -lt $arrayNode.Elements.Count; $i++) {
                $element = $arrayNode.Elements[$i]
                
                # Each element must be a string literal
                if ($element -isnot [LiteralNode]) {
                    throw "Include template names in array must be string literals at line $($node.Line), column $($node.Column)"
                }
                
                $templateName = $element.Value
                
                if ($i -eq 0) {
                    $this.AppendLine("# Try template: $templateName")
                } else {
                    $this.AppendLine("# Fallback to template: $templateName")
                }
                
                $this.AppendLine("`$IncludeTemplateName = '$($templateName -replace "'", "''")'")
                
                # Resolve the template path
                $this.AppendLine("if ([string]::IsNullOrEmpty(`$TemplateDir)) {")
                $this.IndentLevel++
                $this.AppendLine("`$IncludePath = `$IncludeTemplateName")
                $this.IndentLevel--
                $this.AppendLine("} else {")
                $this.IndentLevel++
                $this.AppendLine("`$IncludePath = Join-Path -Path `$TemplateDir -ChildPath `$IncludeTemplateName")
                $this.IndentLevel--
                $this.AppendLine("}")
                
                # Check if file exists
                $this.AppendLine("if (Test-Path -Path `$IncludePath) {")
                $this.IndentLevel++
                
                # Load and render the template
                $this.AppendLine("`$IncludeContent = [System.IO.File]::ReadAllText(`$IncludePath)")
                $this.AppendLine("`$IncludeEngine = [TemplateEngine]::new()")
                $this.AppendLine("`$IncludeEngine.TemplateDir = `$TemplateDir")
                $this.AppendLine("`$IncludeResult = `$IncludeEngine.Render(`$IncludeContent, `$Context)")
                $this.AppendLine("`$output.Append(`$IncludeResult) | Out-Null")
                $this.AppendLine("`$__include_found__ = `$true")
                
                $this.IndentLevel--
                $this.AppendLine("}")
                
                # If this is not the last element, add an if check to skip remaining templates
                if ($i -lt $arrayNode.Elements.Count - 1) {
                    $this.AppendLine("if (-not `$__include_found__) {")
                    $this.IndentLevel++
                }
            }
            
            # Close all the nested if blocks
            for ($i = 0; $i -lt $arrayNode.Elements.Count - 1; $i++) {
                $this.IndentLevel--
                $this.AppendLine("}")
            }
            
            # If no template was found and ignore missing is not set, throw an error
            if (-not $ignoreMissing) {
                $this.AppendLine("if (-not `$__include_found__) {")
                $this.IndentLevel++
                $this.AppendLine("throw `"None of the include templates were found`"")
                $this.IndentLevel--
                $this.AppendLine("}")
            }
        }
        else {
            # Single template path (original behavior)
            if ($templateExpr -isnot [LiteralNode]) {
                throw "Include template name must be a string literal at line $($node.Line), column $($node.Column)"
            }
            
            $templateName = $templateExpr.Value
            
            # Generate code to include the template
            if ($ignoreMissing) {
                $this.AppendLine("# Include template: $templateName (ignore missing)")
            } else {
                $this.AppendLine("# Include template: $templateName")
            }
            $this.AppendLine("`$IncludeTemplateName = '$($templateName -replace "'", "''")'")
            
            # Resolve the template path relative to the template directory
            $this.AppendLine("if ([string]::IsNullOrEmpty(`$TemplateDir)) {")
            $this.IndentLevel++
            $this.AppendLine("`$IncludePath = `$IncludeTemplateName")
            $this.IndentLevel--
            $this.AppendLine("} else {")
            $this.IndentLevel++
            $this.AppendLine("`$IncludePath = Join-Path -Path `$TemplateDir -ChildPath `$IncludeTemplateName")
            $this.IndentLevel--
            $this.AppendLine("}")
            
            # Check if the file exists
            $this.AppendLine("if (-not (Test-Path -Path `$IncludePath)) {")
            $this.IndentLevel++
            
            if ($ignoreMissing) {
                # If ignore missing is enabled, just skip the include silently
                $this.AppendLine("# Template not found, but ignore missing is enabled")
            } else {
                # Otherwise, throw an error
                $this.AppendLine("throw `"Include template not found: `$IncludePath`"")
            }
            
            $this.IndentLevel--
            $this.AppendLine("} else {")
            $this.IndentLevel++
            
            # Load and render the included template
            $this.AppendLine("`$IncludeContent = [System.IO.File]::ReadAllText(`$IncludePath)")
            $this.AppendLine("`$IncludeEngine = [TemplateEngine]::new()")
            $this.AppendLine("`$IncludeEngine.TemplateDir = `$TemplateDir")
            $this.AppendLine("`$IncludeResult = `$IncludeEngine.Render(`$IncludeContent, `$Context)")
            $this.AppendLine("`$output.Append(`$IncludeResult) | Out-Null")
            
            $this.IndentLevel--
            $this.AppendLine("}")
        }
    }
    
    [void]VisitRaw([RawNode]$node) {
        $escapedContent = $node.Content -replace "'", "''"
        $this.AppendLine("`$output.Append('$escapedContent') | Out-Null")
    }
    
    [void]VisitPowerShellBlock([PowerShellBlockNode]$node) {
        # Generate try-catch block for PowerShell execution
        $this.AppendLine("try {")
        $this.IndentLevel++
        
        # Execute the PowerShell code and capture the result
        $escapedCode = $node.Code -replace "'", "''"
        $trimmedCode = $node.Code.Trim()
        
        # Check if code is empty before executing
        $this.AppendLine("if ([string]::IsNullOrWhiteSpace('$escapedCode')) {")
        $this.IndentLevel++
        $this.AppendLine("`$__ps_result__ = `$null")
        $this.IndentLevel--
        $this.AppendLine("} else {")
        $this.IndentLevel++
        $this.AppendLine("`$__ps_result__ = Invoke-Expression '$escapedCode'")
        $this.IndentLevel--
        $this.AppendLine("}")
        
        # Check if result is null or empty
        $this.AppendLine("if (`$null -eq `$__ps_result__ -or (`$__ps_result__ -is [string] -and [string]::IsNullOrWhiteSpace(`$__ps_result__))) {")
        $this.IndentLevel++
        
        # If result is null/empty and we have an else branch, execute it
        if ($node.ElseBranch.Count -gt 0) {
            foreach ($statement in $node.ElseBranch) {
                $this.Visit($statement)
            }
        }
        
        $this.IndentLevel--
        $this.AppendLine("} else {")
        $this.IndentLevel++
        
        # Output the result if it's not null/empty
        $this.AppendLine("`$output.Append(`$__ps_result__.ToString()) | Out-Null")
        
        $this.IndentLevel--
        $this.AppendLine("}")
        
        $this.IndentLevel--
        $this.AppendLine("} catch {")
        $this.IndentLevel++
        
        # If an error occurs and we have a catch branch, execute it
        if ($node.CatchBranch.Count -gt 0) {
            foreach ($statement in $node.CatchBranch) {
                $this.Visit($statement)
            }
        } else {
            # If no catch branch, re-throw the error
            $this.AppendLine("throw")
        }
        
        $this.IndentLevel--
        $this.AppendLine("}")
    }
    
    [void]VisitText([TextNode]$node) {
        $escapedContent = $node.Content -replace "'", "''"
        $this.AppendLine("`$output.Append('$escapedContent') | Out-Null")
    }
    
    [void]VisitOutput([OutputNode]$node) {
        $expression = $this.VisitExpression($node.Expression)
        
        # Generate code based on UndefinedBehavior setting and expression type
        if ($node.Expression -is [VariableNode]) {
            $this.VisitOutputVariable($node, $expression)
        }
        elseif ($node.Expression -is [PropertyAccessNode]) {
            $this.VisitOutputProperty($node, $expression)
        }
        else {
            # For other expressions (literals, filters, etc.), just output if not null
            $this.VisitOutputGeneric($expression)
        }
    }
    
    # Handle output of simple variables with undefined behavior support
    [void]VisitOutputVariable([OutputNode]$node, [string]$expression) {
        $varName = ([VariableNode]$node.Expression).Name
        
        switch ($this.UndefinedBehavior) {
            ([UndefinedBehavior]::Default) {
                # Jinja2 default: output empty string for undefined, empty string for null
                $this.AppendLine("`$__var_exists__ = `$null -ne (Get-Variable -Name '$varName' -ErrorAction SilentlyContinue)")
                $this.AppendLine("if (`$__var_exists__) {")
                $this.IndentLevel++
                $this.AppendLine("`$__value__ = $expression")
                $this.AppendLine("if (`$null -ne `$__value__) {")
                $this.IndentLevel++
                $this.OutputValue()
                $this.IndentLevel--
                $this.AppendLine("}")
                $this.AppendLine("# If null, output empty string (do nothing)")
                $this.IndentLevel--
                $this.AppendLine("}")
                $this.AppendLine("# If undefined, output empty string (do nothing)")
            }
            ([UndefinedBehavior]::Strict) {
                # Throw exception for undefined variables
                $this.AppendLine("`$__var_exists__ = `$null -ne (Get-Variable -Name '$varName' -ErrorAction SilentlyContinue)")
                $this.AppendLine("if (-not `$__var_exists__) {")
                $this.IndentLevel++
                $this.AppendLine("throw `"UndefinedError: '$varName' is undefined`"")
                $this.IndentLevel--
                $this.AppendLine("}")
                $this.AppendLine("`$__value__ = $expression")
                $this.AppendLine("if (`$null -ne `$__value__) {")
                $this.IndentLevel++
                $this.OutputValue()
                $this.IndentLevel--
                $this.AppendLine("}")
            }
            ([UndefinedBehavior]::Debug) {
                # Output placeholder for undefined variables
                $this.AppendLine("`$__var_exists__ = `$null -ne (Get-Variable -Name '$varName' -ErrorAction SilentlyContinue)")
                $this.AppendLine("if (`$__var_exists__) {")
                $this.IndentLevel++
                $this.AppendLine("`$__value__ = $expression")
                $this.AppendLine("if (`$null -ne `$__value__) {")
                $this.IndentLevel++
                $this.OutputValue()
                $this.IndentLevel--
                $this.AppendLine("}")
                $this.IndentLevel--
                $this.AppendLine("} else {")
                $this.IndentLevel++
                $this.AppendLine("`$output.Append('{{ $varName }}') | Out-Null")
                $this.IndentLevel--
                $this.AppendLine("}")
            }
            ([UndefinedBehavior]::Chainable) {
                # Allow chaining - output empty for undefined/null
                $this.AppendLine("`$__var_exists__ = `$null -ne (Get-Variable -Name '$varName' -ErrorAction SilentlyContinue)")
                $this.AppendLine("if (`$__var_exists__) {")
                $this.IndentLevel++
                $this.AppendLine("`$__value__ = $expression")
                $this.AppendLine("if (`$null -ne `$__value__) {")
                $this.IndentLevel++
                $this.OutputValue()
                $this.IndentLevel--
                $this.AppendLine("}")
                $this.IndentLevel--
                $this.AppendLine("}")
            }
        }
    }
    
    # Handle output of property access with undefined behavior support
    [void]VisitOutputProperty([OutputNode]$node, [string]$expression) {
        $propAccess = [PropertyAccessNode]$node.Expression
        $fullExpr = $this.GetPropertyAccessString($propAccess)
        
        # Get the base variable name
        $baseVar = $propAccess.Object
        while ($baseVar -is [PropertyAccessNode]) {
            $baseVar = ([PropertyAccessNode]$baseVar).Object
        }
        
        if ($baseVar -is [VariableNode]) {
            $baseVarName = ([VariableNode]$baseVar).Name
            
            switch ($this.UndefinedBehavior) {
                ([UndefinedBehavior]::Default) {
                    # Jinja2 default: output empty string for undefined base or undefined property
                    $this.AppendLine("`$__var_exists__ = `$null -ne (Get-Variable -Name '$baseVarName' -ErrorAction SilentlyContinue)")
                    $this.AppendLine("if (`$__var_exists__) {")
                    $this.IndentLevel++
                    $this.AppendLine("`$__value__ = $expression")
                    $this.AppendLine("if (`$null -ne `$__value__) {")
                    $this.IndentLevel++
                    $this.OutputValue()
                    $this.IndentLevel--
                    $this.AppendLine("}")
                    $this.IndentLevel--
                    $this.AppendLine("}")
                }
                ([UndefinedBehavior]::Strict) {
                    # Throw exception for undefined base variable or undefined property
                    $this.AppendLine("`$__var_exists__ = `$null -ne (Get-Variable -Name '$baseVarName' -ErrorAction SilentlyContinue)")
                    $this.AppendLine("if (-not `$__var_exists__) {")
                    $this.IndentLevel++
                    $this.AppendLine("throw `"UndefinedError: '$baseVarName' is undefined`"")
                    $this.IndentLevel--
                    $this.AppendLine("}")
                    $this.AppendLine("`$__value__ = $expression")
                    $this.AppendLine("if (`$null -eq `$__value__) {")
                    $this.IndentLevel++
                    $this.AppendLine("throw `"UndefinedError: property '$fullExpr' is undefined or null`"")
                    $this.IndentLevel--
                    $this.AppendLine("}")
                    $this.OutputValue()
                }
                ([UndefinedBehavior]::Debug) {
                    # Output placeholder for undefined base or undefined property
                    $this.AppendLine("`$__var_exists__ = `$null -ne (Get-Variable -Name '$baseVarName' -ErrorAction SilentlyContinue)")
                    $this.AppendLine("if (`$__var_exists__) {")
                    $this.IndentLevel++
                    $this.AppendLine("`$__value__ = $expression")
                    $this.AppendLine("if (`$null -ne `$__value__) {")
                    $this.IndentLevel++
                    $this.OutputValue()
                    $this.IndentLevel--
                    $this.AppendLine("} else {")
                    $this.IndentLevel++
                    $this.AppendLine("`$output.Append('{{ $fullExpr }}') | Out-Null")
                    $this.IndentLevel--
                    $this.AppendLine("}")
                    $this.IndentLevel--
                    $this.AppendLine("} else {")
                    $this.IndentLevel++
                    $this.AppendLine("`$output.Append('{{ $fullExpr }}') | Out-Null")
                    $this.IndentLevel--
                    $this.AppendLine("}")
                }
                ([UndefinedBehavior]::Chainable) {
                    # Allow chaining - output empty for undefined/null
                    $this.AppendLine("`$__var_exists__ = `$null -ne (Get-Variable -Name '$baseVarName' -ErrorAction SilentlyContinue)")
                    $this.AppendLine("if (`$__var_exists__) {")
                    $this.IndentLevel++
                    $this.AppendLine("`$__value__ = $expression")
                    $this.AppendLine("if (`$null -ne `$__value__) {")
                    $this.IndentLevel++
                    $this.OutputValue()
                    $this.IndentLevel--
                    $this.AppendLine("}")
                    $this.IndentLevel--
                    $this.AppendLine("}")
                }
            }
        } else {
            # Base is not a simple variable, just check for null
            $this.VisitOutputGeneric($expression)
        }
    }
    
    # Handle output of generic expressions (literals, filters, etc.)
    [void]VisitOutputGeneric([string]$expression) {
        $this.AppendLine("`$__value__ = $expression")
        $this.AppendLine("if (`$null -ne `$__value__) {")
        $this.IndentLevel++
        $this.OutputValue()
        $this.IndentLevel--
        $this.AppendLine("}")
    }
    
    # Helper method to output a value with proper formatting
    [void]OutputValue() {
        # Use invariant culture for numbers to ensure dot as decimal separator
        $this.AppendLine("if (`$__value__ -is [double] -or `$__value__ -is [decimal] -or `$__value__ -is [float]) {")
        $this.IndentLevel++
        $this.AppendLine("`$output.Append(`$__value__.ToString([System.Globalization.CultureInfo]::InvariantCulture)) | Out-Null")
        $this.IndentLevel--
        $this.AppendLine("} else {")
        $this.IndentLevel++
        $this.AppendLine("`$output.Append(`$__value__.ToString()) | Out-Null")
        $this.IndentLevel--
        $this.AppendLine("}")
    }
    
    # Helper method to get the string representation of a property access expression
    [string]GetPropertyAccessString([PropertyAccessNode]$node) {
        if ($node.Object -is [VariableNode]) {
            $varName = ([VariableNode]$node.Object).Name
            return "$varName.$($node.Property)"
        }
        elseif ($node.Object -is [PropertyAccessNode]) {
            $parentExpr = $this.GetPropertyAccessString([PropertyAccessNode]$node.Object)
            return "$parentExpr.$($node.Property)"
        }
        else {
            return "expression.$($node.Property)"
        }
    }
    
    [void]VisitIf([IfNode]$node) {
        $condition = $this.VisitExpression($node.Condition)
        $this.AppendLine("if ($condition) {")
        $this.IndentLevel++
        
        foreach ($statement in $node.ThenBranch) {
            $this.Visit($statement)
        }
        
        $this.IndentLevel--
        
        # Handle elif branches
        $currentNode = $node
        
        while ($null -ne $currentNode.ElifBranch) {
            $elifCondition = $this.VisitExpression($currentNode.ElifBranch.Condition)
            $this.AppendLine("} elseif ($elifCondition) {")
            $this.IndentLevel++
            
            foreach ($statement in $currentNode.ElifBranch.ThenBranch) {
                $this.Visit($statement)
            }
            
            $this.IndentLevel--
            
            # Move to the next elif branch if it exists
            $currentNode = $currentNode.ElifBranch
        }
        
        # Handle else branch - check the last node in the elif chain
        if ($currentNode.ElseBranch.Count -gt 0) {
            $this.AppendLine("} else {")
            $this.IndentLevel++
            
            foreach ($statement in $currentNode.ElseBranch) {
                $this.Visit($statement)
            }
            
            $this.IndentLevel--
        }
        
        # Close the if statement
        $this.AppendLine("}")
    }
    
    [void]VisitFor([ForNode]$node) {
        $iterable = $this.VisitExpression($node.Iterable)
        
        # If there's an else branch, we need to check if the iterable is empty
        if ($node.ElseBranch.Count -gt 0) {
            # Store the iterable in a variable to check if it's empty
            $this.AppendLine("`$LoopIterable = $iterable")
            $this.AppendLine("if (`$LoopIterable -and (`$LoopIterable -is [array] -and `$LoopIterable.Count -gt 0) -or (`$LoopIterable -isnot [array])) {")
            $this.IndentLevel++
            
            # Convert to array if needed and get length
            $this.AppendLine("`$LoopItems = @(`$LoopIterable)")
            $this.AppendLine("`$LoopLength = `$LoopItems.Count")
            $this.AppendLine("`$LoopIndex0 = 0")
            
            # Generate the foreach loop
            $this.AppendLine("foreach (`$$($node.Variable) in `$LoopItems) {")
            $this.IndentLevel++
            
            # Create loop variable with all properties
            $this.AppendLine("# Create loop variable")
            $this.AppendLine("`$loop = [PSCustomObject]@{")
            $this.IndentLevel++
            $this.AppendLine("index = `$LoopIndex0 + 1")
            $this.AppendLine("index0 = `$LoopIndex0")
            $this.AppendLine("first = (`$LoopIndex0 -eq 0)")
            $this.AppendLine("last = (`$LoopIndex0 -eq (`$LoopLength - 1))")
            $this.AppendLine("length = `$LoopLength")
            $this.IndentLevel--
            $this.AppendLine("}")
            
            foreach ($statement in $node.Body) {
                $this.Visit($statement)
            }
            
            # Increment loop counter
            $this.AppendLine("`$LoopIndex0++")
            
            $this.IndentLevel--
            $this.AppendLine("}")
            
            $this.IndentLevel--
            $this.AppendLine("} else {")
            $this.IndentLevel++
            
            # Generate the else branch
            foreach ($statement in $node.ElseBranch) {
                $this.Visit($statement)
            }
            
            $this.IndentLevel--
            $this.AppendLine("}")
        } else {
            # No else branch, but still need loop variable support
            # Convert to array if needed and get length
            $this.AppendLine("`$LoopItems = @($iterable)")
            $this.AppendLine("`$LoopLength = `$LoopItems.Count")
            $this.AppendLine("`$LoopIndex0 = 0")
            
            # Generate the foreach loop
            $this.AppendLine("foreach (`$$($node.Variable) in `$LoopItems) {")
            $this.IndentLevel++
            
            # Create loop variable with all properties
            $this.AppendLine("# Create loop variable")
            $this.AppendLine("`$loop = [PSCustomObject]@{")
            $this.IndentLevel++
            $this.AppendLine("index = `$LoopIndex0 + 1")
            $this.AppendLine("index0 = `$LoopIndex0")
            $this.AppendLine("first = (`$LoopIndex0 -eq 0)")
            $this.AppendLine("last = (`$LoopIndex0 -eq (`$LoopLength - 1))")
            $this.AppendLine("length = `$LoopLength")
            $this.IndentLevel--
            $this.AppendLine("}")
            
            foreach ($statement in $node.Body) {
                $this.Visit($statement)
            }
            
            # Increment loop counter
            $this.AppendLine("`$LoopIndex0++")
            
            $this.IndentLevel--
            $this.AppendLine("}")
        }
    }
    
    [void]VisitSet([SetNode]$node) {
        # Generate variable assignment
        $value = $this.VisitExpression($node.Value)
        $this.AppendLine("`$$($node.VariableName) = $value")
        
        # Also update the context so the variable is available in included templates
        $this.AppendLine("`$Context['$($node.VariableName)'] = `$$($node.VariableName)")
    }
    
    [void]VisitMacro([MacroNode]$node) {
        # Generate a PowerShell function for the macro
        $this.AppendLine("# Macro: $($node.Name)")
        
        # Build parameter list
        $paramList = [System.Collections.Generic.List[string]]::new()
        foreach ($param in $node.Parameters) {
            if ($node.Defaults.ContainsKey($param)) {
                # Parameter with default value
                $defaultValue = $this.VisitExpression($node.Defaults[$param])
                $paramList.Add("`$$param = $defaultValue")
            } else {
                # Required parameter
                $paramList.Add("`$$param")
            }
        }
        
        # Create function definition
        $this.AppendLine("function __MACRO_$($node.Name)__ {")
        $this.IndentLevel++
        
        if ($paramList.Count -gt 0) {
            $this.AppendLine("param(")
            $this.IndentLevel++
            for ($i = 0; $i -lt $paramList.Count; $i++) {
                if ($i -lt $paramList.Count - 1) {
                    $this.AppendLine("$($paramList[$i]),")
                } else {
                    $this.AppendLine($paramList[$i])
                }
            }
            $this.IndentLevel--
            $this.AppendLine(")")
        }
        
        # Create output buffer for macro
        $this.AppendLine("`$__macro_output__ = [System.Text.StringBuilder]::new()")
        
        # Compile macro body
        foreach ($statement in $node.Body) {
            # Temporarily replace $output with $__macro_output__
            $savedCode = $this.Code
            $this.Code = [System.Text.StringBuilder]::new()
            
            $this.Visit($statement)
            
            $macroCode = $this.Code.ToString()
            $this.Code = $savedCode
            
            # Replace $output with $__macro_output__
            $macroCode = $macroCode.Replace('$output.Append', '$__macro_output__.Append')
            
            # Add the modified code
            $lines = $macroCode -split "`r?`n"
            foreach ($line in $lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $this.AppendLine($line.TrimEnd())
                }
            }
        }
        
        # Return macro output (trim trailing newline for cleaner output)
        $this.AppendLine("return `$__macro_output__.ToString().TrimEnd(""`r"", ""`n"")")
        
        $this.IndentLevel--
        $this.AppendLine("}")
        $this.AppendLine()
    }
    
    [void]VisitCall([CallNode]$node) {
        # Generate code for call block with caller() support
        $macroCall = $node.MacroCall
        
        # First, compile the caller block into a function
        # IMPORTANT: Function name must be __MACRO_caller__ to match macro expectations
        $this.AppendLine("# Call block with caller()")
        
        # Generate caller function with parameters if specified
        if ($node.Parameters.Count -gt 0) {
            $paramList = $node.Parameters -join ', $'
            $this.AppendLine("function __MACRO_caller__ {")
            $this.IndentLevel++
            $this.AppendLine("param(`$$paramList)")
        } else {
            $this.AppendLine("function __MACRO_caller__ {")
            $this.IndentLevel++
        }
        
        $this.AppendLine("`$__caller_output__ = [System.Text.StringBuilder]::new()")
        
        # Compile caller body
        foreach ($statement in $node.Body) {
            # Temporarily replace $output with $__caller_output__
            $savedCode = $this.Code
            $this.Code = [System.Text.StringBuilder]::new()
            
            $this.Visit($statement)
            
            $callerCode = $this.Code.ToString()
            $this.Code = $savedCode
            
            # Replace $output with $__caller_output__
            $callerCode = $callerCode.Replace('$output.Append', '$__caller_output__.Append')
            
            # Add the modified code
            $lines = $callerCode -split "`r?`n"
            foreach ($line in $lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $this.AppendLine($line.TrimEnd())
                }
            }
        }
        
        $this.AppendLine("`$__caller_result__ = `$__caller_output__.ToString()")
        $this.AppendLine("# Remove all whitespace and newlines, then trim")
        $this.AppendLine("`$__caller_result__ = `$__caller_result__ -replace '[\r\n\s]+', ' '")
        $this.AppendLine("`$__caller_result__ = `$__caller_result__ -replace '\s+<', '<'")
        $this.AppendLine("`$__caller_result__ = `$__caller_result__ -replace '>\s+', '>'")
        $this.AppendLine("`$__caller_result__ = `$__caller_result__.Trim()")
        $this.AppendLine("return `$__caller_result__")
        
        $this.IndentLevel--
        $this.AppendLine("}")
        
        # Build macro call
        $macroCallExpr = $this.VisitExpression($macroCall)
        $this.AppendLine("`$__call_result__ = $macroCallExpr")
        $this.AppendLine("`$output.Append(`$__call_result__) | Out-Null")
        
        # Clean up caller function
        $this.AppendLine("Remove-Item function:__MACRO_caller__")
    }
    
    [void]VisitImport([ImportNode]$node) {
        # Import macros from another template
        $templateExpr = $this.VisitExpression($node.Template)
        $alias = $node.Alias
        
        $this.AppendLine("# Import macros from template as $alias")
        $this.AppendLine("`$ImportTemplateName = $templateExpr")
        
        # Resolve template path
        $this.AppendLine("if ([string]::IsNullOrEmpty(`$TemplateDir)) {")
        $this.IndentLevel++
        $this.AppendLine("`$ImportPath = `$ImportTemplateName")
        $this.IndentLevel--
        $this.AppendLine("} else {")
        $this.IndentLevel++
        $this.AppendLine("`$ImportPath = Join-Path -Path `$TemplateDir -ChildPath `$ImportTemplateName")
        $this.IndentLevel--
        $this.AppendLine("}")
        
        # Load and compile the template to extract macros
        $this.AppendLine("`$ImportContent = [System.IO.File]::ReadAllText(`$ImportPath)")
        $this.AppendLine("`$ImportEngine = [TemplateEngine]::new()")
        $this.AppendLine("`$ImportAst = `$ImportEngine.Parse(`$ImportContent, `$ImportTemplateName)")
        
        # Create a namespace object to hold the macros
        $this.AppendLine("`$$alias = [PSCustomObject]@{}")
        
        # TODO: Extract and add macro functions to the namespace
        # This would require compiling the imported template and extracting macro definitions
    }
    
    [void]VisitFromImport([FromImportNode]$node) {
        # Import specific macros from another template
        $templateExpr = $this.VisitExpression($node.Template)
        
        $this.AppendLine("# Import macros from template")
        $this.AppendLine("`$ImportTemplateName = $templateExpr")
        
        # Resolve template path
        $this.AppendLine("if ([string]::IsNullOrEmpty(`$TemplateDir)) {")
        $this.IndentLevel++
        $this.AppendLine("`$ImportPath = `$ImportTemplateName")
        $this.IndentLevel--
        $this.AppendLine("} else {")
        $this.IndentLevel++
        $this.AppendLine("`$ImportPath = Join-Path -Path `$TemplateDir -ChildPath `$ImportTemplateName")
        $this.IndentLevel--
        $this.AppendLine("}")
        
        # Load and compile the template to extract macros
        $this.AppendLine("`$ImportContent = [System.IO.File]::ReadAllText(`$ImportPath)")
        $this.AppendLine("`$ImportEngine = [TemplateEngine]::new()")
        $this.AppendLine("`$ImportAst = `$ImportEngine.Parse(`$ImportContent, `$ImportTemplateName)")
        
        # TODO: Extract specific macros and make them available
        # This would require compiling the imported template and extracting specific macro definitions
    }
    
    [string]VisitExpression([ExpressionNode]$node) {
        switch ($node.GetType().Name) {
            "LiteralNode" {
                $literal = [LiteralNode]$node
                if ($null -eq $literal.Value) {
                    return '$null'
                } elseif ($literal.Value -is [string]) {
                    return "'$($literal.Value -replace "'", "''")'"
                } elseif ($literal.Value -is [bool]) {
                    return '${0}' -f $literal.Value.ToString().ToLower()
                } else {
                    return $literal.Value.ToString()
                }
            }
            "VariableNode" {
                $variable = [VariableNode]$node
                # Simply use the variable name directly
                # PowerShell will look it up in the current scope first (loop variables)
                # then in parent scopes (context variables)
                return "`$$($variable.Name)"
            }
            "PropertyAccessNode" {
                $propAccess = [PropertyAccessNode]$node
                $object = $this.VisitExpression($propAccess.Object)
                $property = $propAccess.Property
                return "($object).'$property'"
            }
            "IndexAccessNode" {
                $indexAccess = [IndexAccessNode]$node
                $object = $this.VisitExpression($indexAccess.Object)
                $index = $this.VisitExpression($indexAccess.Index)
                return "($object)[$index]"
            }
            "BinaryOpNode" {
                $binaryOp = [BinaryOpNode]$node
                $left = $this.VisitExpression($binaryOp.Left)
                $right = $this.VisitExpression($binaryOp.Right)
                
                $operator = $binaryOp.Operator
                if ($operator -eq '==') { $operator = '-eq' }
                elseif ($operator -eq '!=') { $operator = '-ne' }
                elseif ($operator -eq '<') { $operator = '-lt' }
                elseif ($operator -eq '>') { $operator = '-gt' }
                elseif ($operator -eq '<=') { $operator = '-le' }
                elseif ($operator -eq '>=') { $operator = '-ge' }
                elseif ($operator -eq 'and') { $operator = '-and' }
                elseif ($operator -eq 'or') { $operator = '-or' }
                elseif ($operator -eq 'in') { $operator = '-in' }
                
                return "($left $operator $right)"
            }
            "FilterNode" {
                $filterNode = [FilterNode]$node
                $expr = $this.VisitExpression($filterNode.Expression)
                $filterName = $filterNode.FilterName
                
                # Capitalize first letter of filter name to match method names
                $filterName = $filterName.Substring(0, 1).ToUpper() + $filterName.Substring(1).ToLower()
                
                # Build arguments string if any
                $argsStr = ""
                if ($filterNode.Arguments.Count -gt 0) {
                    $arguments = @()
                    foreach ($arg in $filterNode.Arguments) {
                        $arguments += $this.VisitExpression($arg)
                    }
                    $argsStr = ", " + ($arguments -join ", ")
                }
                
                # Apply the filter
                return "[AltarFilters]::$filterName($expr$argsStr)"
            }
            "ArrayLiteralNode" {
                # Handle array literal - convert to PowerShell array
                $arrayNode = [ArrayLiteralNode]$node
                $elements = @()
                foreach ($element in $arrayNode.Elements) {
                    $elements += $this.VisitExpression($element)
                }
                return "@(" + ($elements -join ", ") + ")"
            }
            "DictLiteralNode" {
                # Handle dictionary literal - convert to PowerShell hashtable
                $dictNode = [DictLiteralNode]$node
                $pairs = [System.Collections.Generic.List[string]]::new()
                
                foreach ($pair in $dictNode.Pairs) {
                    $key = $this.VisitExpression($pair.Item1)
                    $value = $this.VisitExpression($pair.Item2)
                    $pairs.Add("$key = $value")
                }
                
                return "@{" + ($pairs -join "; ") + "}"
            }
            "SuperNode" {
                # Handle super() call - call parent block function
                if ($null -eq $this.CurrentBlock) {
                    throw "super() can only be used inside a block"
                }
                
                if (-not $this.ParentBlocks.ContainsKey($this.CurrentBlock)) {
                    throw "No parent block found for '$($this.CurrentBlock)'"
                }
                
                # Call the parent block function
                return "(& __PARENT_BLOCK_$($this.CurrentBlock)__)"
            }
            "SelfCallNode" {
                # Handle self.blockname() call - call block as a function (Jinja2 compatibility)
                $selfCall = [SelfCallNode]$node
                # Call the block function using call operator to ensure it's invoked as a function
                return "(& __BLOCK_$($selfCall.BlockName)__)"
            }
            "MacroCallNode" {
                # Handle macro call expression
                $macroCall = [MacroCallNode]$node
                
                # Build argument list
                $args = [System.Collections.Generic.List[string]]::new()
                
                # Add positional arguments
                foreach ($arg in $macroCall.Arguments) {
                    $args.Add($this.VisitExpression($arg))
                }
                
                # Add named arguments
                foreach ($key in $macroCall.NamedArguments.Keys) {
                    $value = $this.VisitExpression($macroCall.NamedArguments[$key])
                    $args.Add("-$key $value")
                }
                
                # Generate function call - wrap in parentheses for filter compatibility
                if ($args.Count -gt 0) {
                    return "(__MACRO_$($macroCall.MacroName)__ $($args -join ' '))"
                } else {
                    return "(__MACRO_$($macroCall.MacroName)__)"
                }
            }
            "ConditionalExpressionNode" {
                # Handle conditional (ternary) expression: 'yes' if foo else 'no'
                $condExpr = [ConditionalExpressionNode]$node
                $condition = $this.VisitExpression($condExpr.Condition)
                $trueValue = $this.VisitExpression($condExpr.TrueValue)
                $falseValue = $this.VisitExpression($condExpr.FalseValue)
                
                # Generate PowerShell ternary operator (PowerShell 7+) or fallback to if-else expression
                # PowerShell 7+ supports: condition ? trueValue : falseValue
                # For compatibility, we use: @{$true=trueValue; $false=falseValue}[condition]
                return "(@{`$true=$trueValue; `$false=$falseValue}[$condition])"
            }
            "IsTestNode" {
                # Handle 'is' test expression: variable is defined, number is even, etc.
                $isTest = [IsTestNode]$node
                $expr = $this.VisitExpression($isTest.Expression)
                $testName = $isTest.TestName
                $negated = $isTest.Negated
                
                # Generate PowerShell code based on the test type
                $testCode = switch ($testName) {
                    'defined' {
                        # Check if variable is defined (not null)
                        "(`$null -ne $expr)"
                    }
                    'none' {
                        # Check if value is null
                        "(`$null -eq $expr)"
                    }
                    'null' {
                        # Check if value is null (alias for 'none')
                        "(`$null -eq $expr)"
                    }
                    'even' {
                        # Check if number is even
                        "(($expr) % 2 -eq 0)"
                    }
                    'odd' {
                        # Check if number is odd
                        "(($expr) % 2 -ne 0)"
                    }
                    'divisibleby' {
                        # Check if number is divisible by n
                        if ($isTest.Arguments.Count -eq 0) {
                            throw "Test 'divisibleby' requires an argument"
                        }
                        $arg = $this.VisitExpression($isTest.Arguments[0])
                        "(($expr) % ($arg) -eq 0)"
                    }
                    'iterable' {
                        # Check if value is iterable (array or implements IEnumerable)
                        "($expr -is [array] -or ($expr -is [System.Collections.IEnumerable] -and $expr -isnot [string]))"
                    }
                    'number' {
                        # Check if value is a number
                        "($expr -is [int] -or $expr -is [long] -or $expr -is [double] -or $expr -is [decimal] -or $expr -is [float] -or $expr -is [byte] -or $expr -is [int16] -or $expr -is [int64])"
                    }
                    'string' {
                        # Check if value is a string
                        "($expr -is [string])"
                    }
                    'mapping' {
                        # Check if value is a mapping (hashtable or dictionary)
                        "($expr -is [hashtable] -or $expr -is [System.Collections.IDictionary])"
                    }
                    'sequence' {
                        # Check if value is a sequence (array or string)
                        "($expr -is [array] -or $expr -is [string])"
                    }
                    'sameas' {
                        # Check if values are the same object (reference equality)
                        if ($isTest.Arguments.Count -eq 0) {
                            throw "Test 'sameas' requires an argument"
                        }
                        $arg = $this.VisitExpression($isTest.Arguments[0])
                        "([object]::ReferenceEquals($expr, $arg))"
                    }
                    'lower' {
                        # Check if string is lowercase
                        "($expr -is [string] -and $expr -ceq $expr.ToLower())"
                    }
                    'upper' {
                        # Check if string is uppercase
                        "($expr -is [string] -and $expr -ceq $expr.ToUpper())"
                    }
                    'undefined' {
                        # Check if variable is undefined (null) - opposite of 'defined'
                        "(`$null -eq $expr)"
                    }
                    'callable' {
                        # Check if value is callable (scriptblock or function)
                        "($expr -is [scriptblock] -or $expr -is [System.Management.Automation.FunctionInfo] -or $expr -is [System.Management.Automation.CommandInfo])"
                    }
                    'equalto' {
                        # Check if value equals another value
                        if ($isTest.Arguments.Count -eq 0) {
                            throw "Test 'equalto' requires an argument"
                        }
                        $arg = $this.VisitExpression($isTest.Arguments[0])
                        "(($expr) -eq ($arg))"
                    }
                    'escaped' {
                        # Check if string is HTML-escaped
                        # A string is considered escaped if it contains HTML entities
                        "($expr -is [string] -and ($expr -match '&(amp|lt|gt|quot|#39);'))"
                    }
                    default {
                        throw "Unknown test: $testName"
                    }
                }
                
                # Apply negation if needed
                if ($negated) {
                    return "(-not $testCode)"
                } else {
                    return $testCode
                }
            }
            default {
                throw "Unknown expression type: $($node.GetType().Name)"
            }
        }
        return $null # only for PSScriptAnalyzer because it cannot understand derfault statement in switch
    }
    
    [void]AppendLine() {
        $this.Code.AppendLine()
    }
    
    [void]AppendLine([string]$line) {
        $indent = "    " * $this.IndentLevel
        $this.Code.AppendLine($indent + $line)
    }
}

### Template Engine
# Main template engine class that orchestrates the entire template processing pipeline
# Handles tokenization, parsing, compilation, and rendering of templates
class TemplateEngine {
    static [hashtable]$Cache = @{}
    static [int]$MaxSelfRecursionDepth = 1  # Maximum recursion depth for self.blockname() calls (Jinja2 compatibility)
    [string]$TemplateDir  # Directory where templates are located
    [TemplateEnvironment]$Environment  # Template environment settings (Jinja2 compatibility)
    
    TemplateEngine() {
        $this.TemplateDir = ""
        $this.Environment = [TemplateEnvironment]::new()
    }
    
    # Render a template with the given context variables
    # This is the main public method for template rendering
    [string]Render([string]$template, [hashtable]$context) {
        # Create cache key that includes template hash, prefix settings, AND undefined behavior
        # This ensures that changing any of these settings invalidates the cache
        $prefixKey = "$([Lexer]::LINE_STATEMENT_PREFIX)|$([Lexer]::LINE_COMMENT_PREFIX)"
        $undefinedKey = $this.Environment.UndefinedBehavior.ToString()
        $cacheKey = "$($template.GetHashCode())|$prefixKey|$undefinedKey"
        
        # Check if the template is already compiled and cached
        if (-not [TemplateEngine]::Cache.ContainsKey($cacheKey)) {
            # Compile the template and store in cache
            $compiled = $this.Compile($template, "template")
            [TemplateEngine]::Cache[$cacheKey] = $compiled
        }
        
        # Execute the compiled template with the provided context and template directory
        $scriptBlock = [TemplateEngine]::Cache[$cacheKey]
        return & $scriptBlock $context $this.TemplateDir
    }
    
    # Render a template from a file path
    [string]RenderFile([string]$path, [hashtable]$context) {
        # Store the template directory for resolving relative paths
        $this.TemplateDir = Split-Path -Path $path -Parent
        
        # Read the template file
        $templateContent = [System.IO.File]::ReadAllText($path)
        $filename = Split-Path -Path $path -Leaf
        
        # Parse the template to check for inheritance
        $ast = $this.Parse($templateContent, $filename)
        
        # If the template extends another template, handle inheritance
        if ($null -ne $ast.Extends) {
            return $this.RenderWithInheritance($ast, $context)
        }
        
        # Otherwise, render normally
        return $this.Render($templateContent, $context)
    }
    
    # Parse a template string into an AST
    [TemplateNode]Parse([string]$template, [string]$filename) {
        $lexer = [Lexer]::new()
        $tokens = $lexer.Tokenize($template, $filename)
        $parser = [Parser]::new($tokens, $filename)
        $parser.SourceText = $template  # Store the original template text
        return $parser.ParseTemplate()
    }
    
    # Handle template inheritance by merging parent and child templates
    [string]RenderWithInheritance([TemplateNode]$childAst, [hashtable]$context) {
        # Get the parent template name
        $parentExpr = $childAst.Extends.Parent
        if ($parentExpr -isnot [LiteralNode]) {
            throw "Parent template name must be a string literal"
        }
        
        $parentTemplateName = $parentExpr.Value
        $parentPath = Join-Path -Path $this.TemplateDir -ChildPath $parentTemplateName
        
        # Load and parse the parent template
        $parentContent = [System.IO.File]::ReadAllText($parentPath)
        $parentAst = $this.Parse($parentContent, $parentTemplateName)
        
        # Merge blocks: child blocks override parent blocks
        $mergedAst = $this.MergeTemplates($parentAst, $childAst)
        
        # Compile and render the merged template
        $compiler = [PowershellCompiler]::new()
        $compiler.UndefinedBehavior = $this.Environment.UndefinedBehavior
        
        # Pass parent blocks to compiler for super() support
        foreach ($blockName in $parentAst.Blocks.Keys) {
            $compiler.ParentBlocks[$blockName] = $parentAst.Blocks[$blockName]
        }
        
        $powershellCode = $compiler.Compile($mergedAst, $true)
        
        # Now we need to prepend parent block functions to the compiled code
        # This allows super() to call parent block functions
        $parentFunctionsCode = [System.Text.StringBuilder]::new()
        
        foreach ($blockName in $parentAst.Blocks.Keys) {
            # Only compile parent blocks that are overridden in child
            if ($childAst.Blocks.ContainsKey($blockName)) {
                $parentBlock = $parentAst.Blocks[$blockName]
                
                # Create a temporary compiler for parent block
                $parentBlockCompiler = [PowershellCompiler]::new()
                $parentBlockCompiler.CompileBlockAsFunction($parentBlock, $true)
                
                # Add the parent block function code
                $parentFunctionsCode.Append($parentBlockCompiler.Code.ToString())
            }
        }
        
        # Combine parent functions with main code
        # Insert parent functions after the param() and variable initialization but before block functions
        $lines = $powershellCode -split "`r?`n"
        $insertIndex = 0
        
        # Find where to insert (after $__SELF_DEPTH__ initialization)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '\$__SELF_DEPTH__\s*=\s*@\{\}') {
                $insertIndex = $i + 2  # After the line and the blank line
                break
            }
        }
        
        # Insert parent block functions
        if ($parentFunctionsCode.Length -gt 0) {
            $beforeLines = $lines[0..($insertIndex - 1)]
            $afterLines = $lines[$insertIndex..($lines.Count - 1)]
            
            $finalCode = ($beforeLines -join "`n") + "`n" + 
                        "# Parent block functions for super() support`n" +
                        $parentFunctionsCode.ToString() + 
                        ($afterLines -join "`n")
            
            $powershellCode = $finalCode
        }
        
        $scriptBlock = [scriptblock]::Create($powershellCode)
        
        return & $scriptBlock $context $this.TemplateDir
    }
    
    # Merge parent and child templates
    [TemplateNode]MergeTemplates([TemplateNode]$parent, [TemplateNode]$child) {
        # Create a new template node for the merged result
        $merged = [TemplateNode]::new($parent.Line, $parent.Column, $parent.Filename)
        
        # Start with the parent's body
        $merged.Body = $parent.Body.Clone()
        $merged.Blocks = $parent.Blocks.Clone()
        
        # Override parent blocks with child blocks
        foreach ($blockName in $child.Blocks.Keys) {
            $merged.Blocks[$blockName] = $child.Blocks[$blockName]
        }
        
        # Replace BlockNode instances in the body with the overridden versions
        for ($i = 0; $i -lt $merged.Body.Count; $i++) {
            if ($merged.Body[$i] -is [BlockNode]) {
                $blockNode = [BlockNode]$merged.Body[$i]
                if ($merged.Blocks.ContainsKey($blockNode.Name)) {
                    $merged.Body[$i] = $merged.Blocks[$blockNode.Name]
                }
            }
        }
        
        return $merged
    }
    
    # Compile a template string into an executable PowerShell script block
    # This orchestrates the entire compilation pipeline: tokenize → parse → compile
    [scriptblock]Compile([string]$template, [string]$filename) {
        try {
            # Step 1: Tokenization - Convert template text into tokens
            Write-Host "Tokenizing template..."
            $lexer = [Lexer]::new()
            $tokens = $lexer.Tokenize($template, $filename)
            
            # Step 2: Parsing - Convert tokens into an Abstract Syntax Tree (AST)
            Write-Host "Parsing tokens..."
            $parser = [Parser]::new($tokens, $filename)
            $parser.SourceText = $template  # Store the original template text
            $ast = $parser.ParseTemplate()
            
            # Step 3: Compilation - Convert AST into PowerShell code
            Write-Host "Compiling AST to PowerShell code..."
            $compiler = [PowershellCompiler]::new()
            $compiler.UndefinedBehavior = $this.Environment.UndefinedBehavior
            $powershellCode = $compiler.Compile($ast)
            
            # Step 4: Create an executable script block from the PowerShell code
            Write-Host "Generating scriptblock..."
            return [scriptblock]::Create($powershellCode)
            
        } catch {
            # Convert any errors to template-specific errors with location information
            $errorRecord = $_
            throw [TemplateError]::new(
                $errorRecord.Exception.Message,
                $errorRecord.InvocationInfo.ScriptLineNumber,
                $errorRecord.InvocationInfo.OffsetInLine,
                $filename
            )
        }
    }
}

# Custom exception class for template-related errors
# Provides detailed error information including line and column numbers
class TemplateError : Exception {
    [int]$Line
    [int]$Column
    [string]$Filename
    
    TemplateError([string]$message, [int]$line, [int]$column, [string]$filename) : base($message) {
        $this.Line = $line
        $this.Column = $column
        $this.Filename = $filename
    }
    
    [string]ToString() {
        return "TemplateError at $($this.Filename):$($this.Line):$($this.Column) - $($this.Message)"
    }
}

### Filter System
# Static class containing all built-in filters for the template engine
# Filters transform values in the template (e.g., uppercase, lowercase, formatting)
class AltarFilters {
    
    # ==================== STRING FILTERS ====================
    
    # Capitalize the first character and lowercase the rest
    static [string]Capitalize([string]$value) {
        if ([string]::IsNullOrEmpty($value)) {
            return ""
        }
        return [char]::ToUpper($value[0]) + $value.Substring(1).ToLower()
    }
    
    # Convert to uppercase
    static [string]Upper([string]$value) {
        return $value.ToUpper()
    }
    
    # Convert to lowercase
    static [string]Lower([string]$value) {
        return $value.ToLower()
    }
    
    # Convert to title case (capitalize each word)
    static [string]Title([string]$value) {
        $textInfo = (Get-Culture).TextInfo
        return $textInfo.ToTitleCase($value.ToLower())
    }
    
    # Trim whitespace from both ends
    static [string]Trim([string]$value) {
        return $value.Trim()
    }
    
    # Replace old substring with new substring
    static [string]Replace([string]$value, [string]$old, [string]$new) {
        return $value.Replace($old, $new)
    }
    
    # Replace old substring with new substring (with count limit)
    static [string]Replace([string]$value, [string]$old, [string]$new, [int]$count) {
        if ($count -le 0) {
            return $value.Replace($old, $new)
        }
        
        $result = $value
        $replacements = 0
        $startIndex = 0
        
        while ($replacements -lt $count) {
            $index = $result.IndexOf($old, $startIndex)
            if ($index -eq -1) {
                break
            }
            
            $result = $result.Substring(0, $index) + $new + $result.Substring($index + $old.Length)
            $startIndex = $index + $new.Length
            $replacements++
        }
        
        return $result
    }
    
    # Center string in a field of given width
    static [string]Center([string]$value, [int]$width) {
        if ($value.Length -ge $width) {
            return $value
        }
        $totalPadding = $width - $value.Length
        $leftPadding = [Math]::Floor($totalPadding / 2)
        $rightPadding = $totalPadding - $leftPadding
        return (' ' * $leftPadding) + $value + (' ' * $rightPadding)
    }
    
    # Left-justify string in a field of given width
    static [string]Ljust([string]$value, [int]$width) {
        return $value.PadRight($width)
    }
    
    # Right-justify string in a field of given width
    static [string]Rjust([string]$value, [int]$width) {
        return $value.PadLeft($width)
    }
    
    # Reverse a string
    static [string]Reverse([string]$value) {
        $charArray = $value.ToCharArray()
        [Array]::Reverse($charArray)
        return -join $charArray
    }
    
    # Indent each line by a given number of spaces
    static [string]Indent([string]$value, [int]$width = 4, [bool]$indentFirstLine = $false) {
        $lines = $value -split "`r?`n"
        $indent = ' ' * $width
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -eq 0 -and -not $indentFirstLine) {
                continue
            }
            $lines[$i] = $indent + $lines[$i]
        }
        
        return $lines -join "`n"
    }
    
    # Strip HTML tags from string
    static [string]Striptags([string]$value) {
        return $value -replace '<[^>]+>', ''
    }
    
    # Truncate string to given length
    static [string]Truncate([string]$value) {
        return [AltarFilters]::Truncate($value, 255, $false, '...')
    }
    
    static [string]Truncate([string]$value, [int]$length) {
        return [AltarFilters]::Truncate($value, $length, $false, '...')
    }
    
    static [string]Truncate([string]$value, [int]$length, [bool]$killwords) {
        return [AltarFilters]::Truncate($value, $length, $killwords, '...')
    }
    
    static [string]Truncate([string]$value, [int]$length, [bool]$killwords, [string]$end) {
        if ($value.Length -le $length) {
            return $value
        }
        
        if ($killwords) {
            return $value.Substring(0, $length - $end.Length) + $end
        }
        
        # Find last space before length
        $truncated = $value.Substring(0, $length - $end.Length)
        $lastSpace = $truncated.LastIndexOf(' ')
        
        if ($lastSpace -gt 0) {
            $truncated = $truncated.Substring(0, $lastSpace)
        }
        
        return $truncated + $end
    }
    
    # Count words in string
    static [int]Wordcount([string]$value) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            return 0
        }
        return ($value -split '\s+').Count
    }
    
    # Wrap text to specified width
    static [string]Wordwrap([string]$value, [int]$width = 79, [bool]$breakLongWords = $true) {
        $words = $value -split '\s+'
        $lines = [System.Collections.Generic.List[string]]::new()
        $currentLine = ""
        
        foreach ($word in $words) {
            if ($currentLine.Length -eq 0) {
                $currentLine = $word
            }
            elseif (($currentLine.Length + 1 + $word.Length) -le $width) {
                $currentLine += " " + $word
            }
            else {
                $lines.Add($currentLine)
                $currentLine = $word
            }
            
            # Handle words longer than width
            if ($breakLongWords -and $currentLine.Length -gt $width) {
                while ($currentLine.Length -gt $width) {
                    $lines.Add($currentLine.Substring(0, $width))
                    $currentLine = $currentLine.Substring($width)
                }
            }
        }
        
        if ($currentLine.Length -gt 0) {
            $lines.Add($currentLine)
        }
        
        return $lines -join "`n"
    }
    
    # ==================== ESCAPE FILTERS ====================
    
    # HTML escape (also aliased as 'escape')
    static [string]HtmlEscape([string]$value) {
        return $value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;").Replace("'", "&#39;")
    }
    
    # Alias for HtmlEscape
    static [string]Escape([string]$value) {
        return [AltarFilters]::HtmlEscape($value)
    }
    
    # Force escape even if already marked safe
    static [string]Forceescape([string]$value) {
        return [AltarFilters]::HtmlEscape($value)
    }
    
    # URL encode
    static [string]UrlEncode([string]$value) {
        return [System.Uri]::EscapeDataString($value)
    }
    
    # ==================== LIST/SEQUENCE FILTERS ====================
    
    # Get first element
    static [object]First([object]$value) {
        if ($value -is [array] -and $value.Count -gt 0) {
            return $value[0]
        }
        if ($value -is [string] -and $value.Length -gt 0) {
            return $value[0]
        }
        return $null
    }
    
    # Get last element
    static [object]Last([object]$value) {
        if ($value -is [array] -and $value.Count -gt 0) {
            return $value[-1]
        }
        if ($value -is [string] -and $value.Length -gt 0) {
            return $value[-1]
        }
        return $null
    }
    
    # Join array elements with delimiter
    static [string]Join([object]$value, [string]$delimiter = "") {
        if ($value -is [array]) {
            return $value -join $delimiter
        }
        return $value.ToString()
    }
    
    # Get length of sequence
    static [int]Length([object]$value) {
        if ($value -is [array]) {
            return $value.Count
        }
        if ($value -is [string]) {
            return $value.Length
        }
        if ($value -is [hashtable]) {
            return $value.Count
        }
        return 0
    }
    
    # Reverse a sequence
    static [object]Reverse([object]$value) {
        if ($value -is [array]) {
            $reversed = $value.Clone()
            [Array]::Reverse($reversed)
            return $reversed
        }
        if ($value -is [string]) {
            $charArray = $value.ToCharArray()
            [Array]::Reverse($charArray)
            return -join $charArray
        }
        return $value
    }
    
    # Sort a sequence
    static [object]Sort([object]$value) {
        return [AltarFilters]::Sort($value, $false, $null)
    }
    
    static [object]Sort([object]$value, [bool]$reverse) {
        return [AltarFilters]::Sort($value, $reverse, $null)
    }
    
    static [object]Sort([object]$value, [bool]$reverse, [string]$attribute) {
        if ($value -isnot [array]) {
            return $value
        }
        
        if ([string]::IsNullOrEmpty($attribute)) {
            if ($reverse) {
                return $value | Sort-Object -Descending
            }
            return $value | Sort-Object
        }
        else {
            if ($reverse) {
                return $value | Sort-Object -Property $attribute -Descending
            }
            return $value | Sort-Object -Property $attribute
        }
    }
    
    # Get unique elements
    static [object]Unique([object]$value) {
        if ($value -is [array]) {
            return $value | Select-Object -Unique
        }
        return $value
    }
    
    # Batch items into groups
    static [object]Batch([object]$value, [int]$linecount, [object]$fillWith = $null) {
        if ($value -isnot [array]) {
            return $value
        }
        
        $batches = [System.Collections.Generic.List[object]]::new()
        for ($i = 0; $i -lt $value.Count; $i += $linecount) {
            $batch = [System.Collections.Generic.List[object]]::new()
            
            for ($j = 0; $j -lt $linecount; $j++) {
                $index = $i + $j
                if ($index -lt $value.Count) {
                    $batch.Add($value[$index])
                }
                elseif ($null -ne $fillWith) {
                    $batch.Add($fillWith)
                }
            }
            
            $batches.Add($batch.ToArray())
        }
        
        return $batches.ToArray()
    }
    
    # Slice a sequence
    static [object]Slice([object]$value, [int]$slices, [object]$fillWith = $null) {
        if ($value -isnot [array]) {
            return $value
        }
        
        $itemsPerSlice = [Math]::Ceiling($value.Count / $slices)
        return [AltarFilters]::Batch($value, $itemsPerSlice, $fillWith)
    }
    
    # Sum numeric values
    static [object]Sum([object]$value) {
        return [AltarFilters]::Sum($value, $null, 0)
    }
    
    static [object]Sum([object]$value, [string]$attribute) {
        return [AltarFilters]::Sum($value, $attribute, 0)
    }
    
    static [object]Sum([object]$value, [string]$attribute, [object]$start) {
        if ($value -isnot [array]) {
            return $start
        }
        
        $sum = $start
        
        if ([string]::IsNullOrEmpty($attribute)) {
            foreach ($item in $value) {
                if ($item -is [int] -or $item -is [double] -or $item -is [decimal]) {
                    $sum += $item
                }
            }
        }
        else {
            foreach ($item in $value) {
                if ($item -is [hashtable] -and $item.ContainsKey($attribute)) {
                    $sum += $item[$attribute]
                }
                elseif ($null -ne $item.$attribute) {
                    $sum += $item.$attribute
                }
            }
        }
        
        return $sum
    }
    
    # Get minimum value
    static [object]Min([object]$value) {
        if ($value -is [array] -and $value.Count -gt 0) {
            return ($value | Measure-Object -Minimum).Minimum
        }
        return $value
    }
    
    # Get maximum value
    static [object]Max([object]$value) {
        if ($value -is [array] -and $value.Count -gt 0) {
            return ($value | Measure-Object -Maximum).Maximum
        }
        return $value
    }
    
    # Get random element
    static [object]Random([object]$value) {
        if ($value -is [array] -and $value.Count -gt 0) {
            return $value | Get-Random
        }
        return $value
    }
    
    # Select items where attribute is true
    static [object]Select([object]$value, [string]$attribute = $null) {
        if ($value -isnot [array]) {
            return $value
        }
        
        if ([string]::IsNullOrEmpty($attribute)) {
            return $value | Where-Object { $_ }
        }
        
        return $value | Where-Object { $_.$attribute }
    }
    
    # Reject items where attribute is true
    static [object]Reject([object]$value, [string]$attribute = $null) {
        if ($value -isnot [array]) {
            return $value
        }
        
        if ([string]::IsNullOrEmpty($attribute)) {
            return $value | Where-Object { -not $_ }
        }
        
        return $value | Where-Object { -not $_.$attribute }
    }
    
    # Select items where attribute equals test value
    static [object]Selectattr([object]$value, [string]$attribute, [string]$test = "==", [object]$testValue = $true) {
        if ($value -isnot [array]) {
            return $value
        }
        
        $result = switch ($test) {
            "==" { $value | Where-Object { $_.$attribute -eq $testValue } }
            "!=" { $value | Where-Object { $_.$attribute -ne $testValue } }
            ">" { $value | Where-Object { $_.$attribute -gt $testValue } }
            "<" { $value | Where-Object { $_.$attribute -lt $testValue } }
            ">=" { $value | Where-Object { $_.$attribute -ge $testValue } }
            "<=" { $value | Where-Object { $_.$attribute -le $testValue } }
            default { $value | Where-Object { $_.$attribute -eq $testValue } }
        }
        return $result
    }
    
    # Reject items where attribute equals test value
    static [object]Rejectattr([object]$value, [string]$attribute, [string]$test = "==", [object]$testValue = $true) {
        if ($value -isnot [array]) {
            return $value
        }
        
        $result = switch ($test) {
            "==" { $value | Where-Object { $_.$attribute -ne $testValue } }
            "!=" { $value | Where-Object { $_.$attribute -eq $testValue } }
            ">" { $value | Where-Object { $_.$attribute -le $testValue } }
            "<" { $value | Where-Object { $_.$attribute -ge $testValue } }
            ">=" { $value | Where-Object { $_.$attribute -lt $testValue } }
            "<=" { $value | Where-Object { $_.$attribute -gt $testValue } }
            default { $value | Where-Object { $_.$attribute -ne $testValue } }
        }
        return $result
    }
    
    # Map attribute from items
    static [object]Map([object]$value, [string]$attribute) {
        if ($value -isnot [array]) {
            return $value
        }
        
        return $value | ForEach-Object { $_.$attribute }
    }
    
    # Group items by attribute
    static [object]Groupby([object]$value, [string]$attribute) {
        if ($value -isnot [array]) {
            return $value
        }
        
        return $value | Group-Object -Property $attribute
    }
    
    # ==================== NUMBER FILTERS ====================
    
    # Absolute value
    static [object]Abs([object]$value) {
        if ($value -is [int] -or $value -is [double] -or $value -is [decimal]) {
            return [Math]::Abs($value)
        }
        return $value
    }
    
    # Convert to integer
    static [int]Int([object]$value) {
        return [AltarFilters]::Int($value, 0)
    }
    
    static [int]Int([object]$value, [int]$default) {
        try {
            return [int]$value
        }
        catch {
            return $default
        }
    }
    
    # Convert to float
    static [double]Float([object]$value) {
        return [AltarFilters]::Float($value, 0.0)
    }
    
    static [double]Float([object]$value, [double]$default) {
        try {
            return [double]$value
        }
        catch {
            return $default
        }
    }
    
    # Round number
    static [object]Round([object]$value) {
        return [AltarFilters]::Round($value, 0, "common")
    }
    
    static [object]Round([object]$value, [int]$precision) {
        return [AltarFilters]::Round($value, $precision, "common")
    }
    
    static [object]Round([object]$value, [int]$precision, [string]$method) {
        if ($value -isnot [int] -and $value -isnot [double] -and $value -isnot [decimal]) {
            return $value
        }
        
        $result = switch ($method) {
            "common" { [Math]::Round($value, $precision) }
            "ceil" { [Math]::Ceiling($value) }
            "floor" { [Math]::Floor($value) }
            default { [Math]::Round($value, $precision) }
        }
        return $result
    }
    
    # ==================== DICTIONARY FILTERS ====================
    
    # Sort dictionary by keys or values
    static [object]Dictsort([object]$value, [bool]$byValue = $false, [bool]$reverse = $false) {
        if ($value -isnot [hashtable]) {
            return $value
        }
        
        if ($byValue) {
            if ($reverse) {
                return $value.GetEnumerator() | Sort-Object -Property Value -Descending
            }
            return $value.GetEnumerator() | Sort-Object -Property Value
        }
        else {
            if ($reverse) {
                return $value.GetEnumerator() | Sort-Object -Property Key -Descending
            }
            return $value.GetEnumerator() | Sort-Object -Property Key
        }
    }
    
    # Get dictionary items as array of [key, value] pairs
    static [object]Items([object]$value) {
        if ($value -is [hashtable]) {
            $items = [System.Collections.Generic.List[object]]::new()
            foreach ($key in $value.Keys) {
                $items.Add(@($key, $value[$key]))
            }
            return $items.ToArray()
        }
        return $value
    }
    
    # Get attribute value
    static [object]Attr([object]$value, [string]$name) {
        if ($value -is [hashtable]) {
            return $value[$name]
        }
        return $value.$name
    }
    
    # ==================== CONVERSION FILTERS ====================
    
    # Convert to list/array
    static [object]List([object]$value) {
        if ($value -is [array]) {
            return $value
        }
        if ($value -is [string]) {
            return $value.ToCharArray()
        }
        if ($value -is [hashtable]) {
            return $value.Values
        }
        return @($value)
    }
    
    # Convert to JSON
    static [string]Tojson([object]$value) {
        return $value | ConvertTo-Json -Compress
    }
    
    static [string]Tojson([object]$value, [int]$indent) {
        return $value | ConvertTo-Json -Depth 10
    }
    
    # Pretty print
    static [string]Pprint([object]$value) {
        return $value | ConvertTo-Json -Depth 10
    }
    
    # ==================== OTHER FILTERS ====================
    
    # Default value if undefined or empty
    static [object]Default([object]$value) {
        return [AltarFilters]::Default($value, "", $false)
    }
    
    static [object]Default([object]$value, [object]$defaultValue) {
        return [AltarFilters]::Default($value, $defaultValue, $false)
    }
    
    static [object]Default([object]$value, [object]$defaultValue, [bool]$boolean) {
        if ($boolean) {
            if (-not $value) {
                return $defaultValue
            }
            return $value
        }
        
        if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrEmpty($value))) {
            return $defaultValue
        }
        return $value
    }
    
    # Format file size
    static [string]Filesizeformat([object]$value) {
        return [AltarFilters]::Filesizeformat($value, $false)
    }
    
    static [string]Filesizeformat([object]$value, [bool]$binary) {
        $bytes = [double]$value
        $base = if ($binary) { 1024 } else { 1000 }
        $units = if ($binary) { @("Bytes", "KiB", "MiB", "GiB", "TiB", "PiB") } else { @("Bytes", "kB", "MB", "GB", "TB", "PB") }
        
        if ($bytes -lt $base) {
            return "$bytes $($units[0])"
        }
        
        $exp = [Math]::Floor([Math]::Log($bytes) / [Math]::Log($base))
        $exp = [Math]::Min($exp, $units.Count - 1)
        
        $size = $bytes / [Math]::Pow($base, $exp)
        # Use invariant culture to ensure dot as decimal separator
        return $size.ToString("N1", [System.Globalization.CultureInfo]::InvariantCulture) + " " + $units[$exp]
    }
    
    # Generate XML attributes
    static [string]Xmlattr([object]$value) {
        return [AltarFilters]::Xmlattr($value, $true)
    }
    
    static [string]Xmlattr([object]$value, [bool]$autospace) {
        if ($value -isnot [hashtable]) {
            return ""
        }
        
        $attrs = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $value.Keys) {
            $val = $value[$key]
            if ($null -ne $val -and $val -ne $false) {
                $escapedValue = $val.ToString().Replace('"', '&quot;')
                $attrs.Add("$key=`"$escapedValue`"")
            }
        }
        
        $result = $attrs -join " "
        if ($autospace -and $result.Length -gt 0) {
            return " " + $result
        }
        return $result
    }
    
    # ==================== FORMAT FILTERS ====================
    
    # Format value with format string
    static [string]Format([object]$value, [string]$format) {
        return $value.ToString($format)
    }
    
    # Format date
    static [string]DateFormat([datetime]$value, [string]$format = "yyyy-MM-dd") {
        return $value.ToString($format)
    }
    
    # Safe filter (mark as safe HTML - for now just returns the value)
    static [string]Safe([string]$value) {
        return $value
    }
    
    # Convert object to string
    static [string]String([object]$value) {
        if ($null -eq $value) {
            return ""
        }
        return $value.ToString()
    }
    
    # Convert URLs in plain text into clickable links
    static [string]Urlize([string]$value) {
        return [AltarFilters]::Urlize($value, $null, $false, $null)
    }
    
    static [string]Urlize([string]$value, [int]$trimUrlLimit) {
        return [AltarFilters]::Urlize($value, $trimUrlLimit, $false, $null)
    }
    
    static [string]Urlize([string]$value, [int]$trimUrlLimit, [bool]$nofollow) {
        return [AltarFilters]::Urlize($value, $trimUrlLimit, $nofollow, $null)
    }
    
    static [string]Urlize([string]$value, [object]$trimUrlLimit, [bool]$nofollow, [string]$target) {
        if ([string]::IsNullOrEmpty($value)) {
            return $value
        }
        
        # Regex pattern to match URLs
        $urlPattern = '(?i)\b((?:https?://|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:''".,<>?«»""'']))'
        
        $result = [regex]::Replace($value, $urlPattern, {
            param($match)
            
            $url = $match.Value
            $displayUrl = $url
            
            # Add http:// if URL starts with www
            $href = $url
            if ($url -match '^www\.') {
                $href = "http://$url"
            }
            
            # Trim URL for display if limit is specified
            if ($null -ne $trimUrlLimit -and $trimUrlLimit -gt 0 -and $displayUrl.Length -gt $trimUrlLimit) {
                $displayUrl = $displayUrl.Substring(0, $trimUrlLimit) + "..."
            }
            
            # Build the anchor tag
            $attrs = [System.Collections.Generic.List[string]]::new()
            $attrs.Add("href=`"$href`"")
            
            if ($nofollow) {
                $attrs.Add('rel="nofollow"')
            }
            
            if (-not [string]::IsNullOrEmpty($target)) {
                $attrs.Add("target=`"$target`"")
            }
            
            return "<a $($attrs -join ' ')>$displayUrl</a>"
        })
        
        return $result
    }
}

# PowerShell Cmdlet for the Altar Template Engine
# Provides a user-friendly interface to render templates from files or strings
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
        [UndefinedBehavior]$UndefinedBehavior = [UndefinedBehavior]::Default,
        
        [Parameter(Mandatory = $false)]
        [string]$LineStatementPrefix,
        
        [Parameter(Mandatory = $false)]
        [string]$LineCommentPrefix
    )
    
    try {
        Write-Verbose "Creating template engine instance"
        $engine = [TemplateEngine]::new()
        
        # Set undefined behavior if provided
        if ($PSBoundParameters.ContainsKey('UndefinedBehavior')) {
            $engine.Environment.UndefinedBehavior = $UndefinedBehavior
            Write-Verbose "Undefined behavior set to: $UndefinedBehavior"
        }
        
        # Set line statement and comment prefixes if provided
        if ($PSBoundParameters.ContainsKey('LineStatementPrefix')) {
            [Lexer]::LINE_STATEMENT_PREFIX = $LineStatementPrefix
            Write-Verbose "Line statement prefix set to: $LineStatementPrefix"
        }
        
        if ($PSBoundParameters.ContainsKey('LineCommentPrefix')) {
            [Lexer]::LINE_COMMENT_PREFIX = $LineCommentPrefix
            Write-Verbose "Line comment prefix set to: $LineCommentPrefix"
        }
        
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            Write-Verbose "Using Path parameter set"
            
            # Check if the file exists
            Write-Verbose "Checking if file exists: $Path"
            if (-not (Test-Path -Path $Path)) {
                Write-Error "Template file not found: $Path"
                return
            }
            
            # Render the template using RenderFile which handles inheritance
            Write-Verbose "Rendering template from file"
            $result = $engine.RenderFile($Path, $Context)
            Write-Verbose "Template rendered successfully"
        }
        else {
            Write-Verbose "Using Template parameter set"
            
            # Use the provided template string
            Write-Verbose "Rendering template from string"
            $result = $engine.Render($Template, $Context)
            Write-Verbose "Template rendered successfully"
        }
        
        return $result
    }
    catch [TemplateError] {
        Write-Error "Template error at $($_.Exception.Filename):$($_.Exception.Line):$($_.Exception.Column) - $($_.Exception.Message)"
    }
    catch {
        Write-Error "Error processing template: $_"
    }
    finally {
        # Reset prefixes after rendering to avoid affecting subsequent renders
        if ($PSBoundParameters.ContainsKey('LineStatementPrefix')) {
            [Lexer]::LINE_STATEMENT_PREFIX = $null
        }
        
        if ($PSBoundParameters.ContainsKey('LineCommentPrefix')) {
            [Lexer]::LINE_COMMENT_PREFIX = $null
        }
    }
}

# When dot-sourcing the file, the function will be available in the current scope
# No need to use Export-ModuleMember
