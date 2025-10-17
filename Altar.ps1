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
    static [string]$BLOCK_START = '{%'       # Start of block expression
    static [string]$BLOCK_END = '%}'         # End of block expression
    static [string]$BLOCK_START_TRIM = '{%-' # Start of block with whitespace trimming
    static [string]$BLOCK_END_TRIM = '-%}'   # End of block with whitespace trimming
    static [string]$COMMENT_START = '{#'     # Start of comment
    static [string]$COMMENT_END = '#}'       # End of comment
    static [string]$PIPE = '|'               # Pipe before filter
    
    # Reserved keywords in the template language
    static [hashtable]$KEYWORDS = @{
        'if'      = $true   # Conditional blocks
        'for'     = $true   # Loop blocks
        'else'    = $true   # Alternative conditional branch
        'elif'    = $true   # Else-if conditional branch
        'endif'   = $true   # End of conditional block
        'endfor'  = $true   # End of loop block
        'in'      = $true   # Used in for loops
        'and'     = $true   # Logical AND operator
        'or'      = $true   # Logical OR operator
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
    }
    
    # Main tokenization method that converts template text into a list of tokens
    # This is the entry point for the lexical analysis process
    [System.Collections.Generic.List[Token]]Tokenize([string]$text, [string]$filename) {
        # Initialize lexer state with the template text
        $state = [LexerState]::new($text, $filename)
        $tokens = [System.Collections.Generic.List[Token]]::new()
        
        # Process the template until we reach the end
        while (-not $state.IsEOF()) {
            # Get the current lexer state (INITIAL, VARIABLE, BLOCK, COMMENT)
            $currentState = $state.States.Peek()
            
            # Call the appropriate tokenization method based on the current state
            switch ($currentState) {
                "INITIAL" { $this.TokenizeInitial($state, $tokens) }  # Processing regular text
                "VARIABLE" { $this.TokenizeExpression($state, $tokens, "VARIABLE") }  # Inside {{ ... }}
                "BLOCK" { $this.TokenizeExpression($state, $tokens, "BLOCK") }  # Inside {% ... %}
                "COMMENT" { $this.TokenizeComment($state, $tokens) }  # Inside {# ... #}
                default { throw "Unknown lexer state: $currentState" }
            }
        }
        
        # Add an EOF token to mark the end of the template
        $tokens.Add([Token]::new([TokenType]::EOF, "", $state.Line, $state.Column, $filename))
        return $tokens
    }
    
    # Process template text in the INITIAL state (outside of any tags)
    # Handles regular text content and detects the start of variable, block, or comment tags
    [void]TokenizeInitial([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $char = $state.Peek()
        
        # Check for template tags starting with '{'
        if ($char -eq '{') {
            $nextChar = $state.PeekOffset(1)
            switch ($nextChar) {
                # Variable tag: {{ ... }}
                '{' {
                    $state.CaptureStart()
                    $state.Consume()  # Consume '{'
                    $state.Consume()  # Consume '{'
                    $tokens.Add([Token]::new([TokenType]::VARIABLE_START, [Lexer]::VARIABLE_START, $state.StartLine, $state.StartColumn, $state.Filename))
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
        
        # Process regular text content (everything up to the next tag or EOF)
        $textStart = $state.Position
        $state.CaptureStart()
        while (-not $state.IsEOF() -and $state.Peek() -ne '{') {
            $state.Consume()
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
        
        # Handle variable closing tag: }}
        if ($mode -eq "VARIABLE" -and $char -eq '}' -and $state.PeekOffset(1) -eq '}') {
            $state.CaptureStart()
            $state.Consume()  # Consume '}'
            $state.Consume()  # Consume '}'
            $tokens.Add([Token]::new([TokenType]::VARIABLE_END, [Lexer]::VARIABLE_END, $state.StartLine, $state.StartColumn, $state.Filename))
            $state.States.Pop()  # Return to previous state
            return
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
    
    # Trim whitespace before a tag when using the {%- syntax
    # This removes trailing whitespace from the previous text token
    [void]TrimWhitespaceBefore([System.Collections.Generic.List[Token]]$tokens) {
        # If there are no tokens or the last token is not TEXT, nothing to trim
        if ($tokens.Count -eq 0 -or $tokens[-1].Type -ne [TokenType]::TEXT) {
            return
        }
        
        # Get the last token, which should be a TEXT token
        $lastToken = $tokens[-1]
        $content = $lastToken.Value
        
        # Trim trailing horizontal whitespace (spaces and tabs) on the last line only
        # This preserves newlines but removes spaces/tabs before the tag
        # Pattern: match any spaces/tabs at the end of the string
        $trimmedContent = $content -replace '[ \t]+$', ''
        
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
    
    BlockNode([string]$name, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Name = $name
        $this.Body = @()    # Initialize empty array for block content
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

# Represents an array literal in the template (e.g., ['item1', 'item2'])
class ArrayLiteralNode : ExpressionNode {
    [ExpressionNode[]]$Elements  # The elements in the array
    
    ArrayLiteralNode([ExpressionNode[]]$elements, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Elements = $elements
    }
}

# Represents a super() call in the template
# Used to include the parent block's content when overriding blocks
class SuperNode : ExpressionNode {
    SuperNode([int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {}
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
    
    Parser([System.Collections.Generic.List[Token]]$tokens, [string]$filename) {
        $this.Tokens = $tokens
        $this.Position = 0
        $this.Filename = $filename
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
            # Comment {# ... #} - ignored in output
            $this.ParseComment()
            return $null
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
        $this.Expect([TokenType]::BLOCK_END)
        
        $blockNode = [BlockNode]::new($blockName, $startToken.Line, $startToken.Column, $startToken.Filename)
        
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
            $elements.Add($element)
            
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
        
        # Now we need to collect all content until we find {% endraw %}
        # We'll collect TEXT tokens and reconstruct the raw content
        $rawContent = ""
        
        while ($true) {
            $currentToken = $this.Current()
            
            # Check if we've reached EOF
            if ($null -eq $currentToken -or $currentToken.Type -eq [TokenType]::EOF) {
                throw "Unexpected end of template. Expected: endraw"
            }
            
            # Check if we've found the {% endraw %} tag
            if ($currentToken.Type -eq [TokenType]::BLOCK_START) {
                $nextToken = $this.PeekOffset(1)
                if ($null -ne $nextToken -and $nextToken.Type -eq [TokenType]::KEYWORD -and $nextToken.Value -eq 'endraw') {
                    # Found the endraw tag, consume it
                    $this.Consume() # BLOCK_START
                    $this.Consume() # endraw
                    $this.Expect([TokenType]::BLOCK_END)
                    break
                }
            }
            
            # Collect the content - we need to reconstruct the original text
            # including any template syntax that would normally be tokenized
            if ($currentToken.Type -eq [TokenType]::TEXT) {
                $rawContent += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::VARIABLE_START) {
                $rawContent += [Lexer]::VARIABLE_START
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::VARIABLE_END) {
                $rawContent += [Lexer]::VARIABLE_END
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::BLOCK_START) {
                $rawContent += [Lexer]::BLOCK_START
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::BLOCK_END) {
                $rawContent += [Lexer]::BLOCK_END
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::COMMENT_START) {
                $rawContent += [Lexer]::COMMENT_START
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::COMMENT_END) {
                $rawContent += [Lexer]::COMMENT_END
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::IDENTIFIER) {
                $rawContent += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::KEYWORD) {
                $rawContent += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::STRING) {
                # Reconstruct string with quotes
                $rawContent += '"' + $currentToken.Value + '"'
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::NUMBER) {
                $rawContent += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::OPERATOR) {
                $rawContent += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::PUNCTUATION) {
                $rawContent += $currentToken.Value
                $this.Consume()
            }
            elseif ($currentToken.Type -eq [TokenType]::PIPE) {
                $rawContent += [Lexer]::PIPE
                $this.Consume()
            }
            else {
                # Skip any other tokens
                $this.Consume()
            }
        }
        
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
                            # Check for endif tag
                            if (($this.Position + 1) -lt $this.Tokens.Count) {
                                $currentToken = $this.Current()
                                $nextToken = $this.PeekOffset(1)
                                
                                Write-Host "ParseIf: (else branch) Current token: $($currentToken.Type), Value: '$($currentToken.Value)'"
                                Write-Host "ParseIf: (else branch) Next token: $($nextToken.Type), Value: '$($nextToken.Value)'"
                                
                                # Check if we've reached the endif tag
                                if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
                                    $nextToken.Type -eq [TokenType]::KEYWORD -and 
                                    $nextToken.Value -eq 'endif') {
                                    Write-Host "ParseIf: (else branch) Found endif tag"
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
                            } else {
                                # If ParseStatement returns null, we need to advance the position
                                # to avoid an infinite loop
                                if ($this.Position -lt $this.Tokens.Count) {
                                    $this.Position++
                                } else {
                                    throw "Unexpected end of template. Expected: endif"
                                }
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
            } else {
                # If ParseStatement returns null, we need to advance the position
                # to avoid an infinite loop
                if ($this.Position -lt $this.Tokens.Count) {
                    $this.Position++
                } else {
                    throw "Unexpected end of template. Expected: endif"
                }
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
            } else {
                # If ParseStatement returns null, we need to advance the position
                # to avoid an infinite loop
                if ($this.Position -lt $this.Tokens.Count) {
                    Write-Host "ParseElif: Advancing position"
                    $this.Position++
                } else {
                    Write-Host "ParseElif: Reached end of tokens without finding else/elif/endif"
                    throw "Unexpected end of template. Expected: endif"
                }
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
                } else {
                    # If ParseStatement returns null, we need to advance the position
                    # to avoid an infinite loop
                    if ($this.Position -lt $this.Tokens.Count) {
                        Write-Host "ParseElif: (else branch) Advancing position"
                        $this.Position++
                    } else {
                        Write-Host "ParseElif: (else branch) Reached end of tokens without finding endif"
                        throw "Unexpected end of template. Expected: endif"
                    }
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
            } else {
                Write-Verbose "Parsed statement is null, advancing position"
                if ($this.Position -lt $this.Tokens.Count) {
                    $this.Position++
                } else {
                    throw "Unexpected end of template. Expected: endfor"
                }
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
    
    # Parse a comment block {# ... #}
    # Comments are ignored in the output
    [void]ParseComment() {
        $this.Expect([TokenType]::COMMENT_START)  # Consume the {# token
        $this.Expect([TokenType]::COMMENT_END)    # Consume the #} token
        # No AST node is created for comments as they don't affect the output
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
    
    # Parse comparison expressions (e.g., a == b, x > y)
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
                # Variable reference (e.g., user, item, etc.)
                $expr = [VariableNode]::new($token.Value, $token.Line, $token.Column, $token.Filename)
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
                # Parenthesized expression (e.g., (a + b))
                if ($token.Value -eq '(') {
                    $expr = $this.ParseExpression()  # Parse the expression inside the parentheses
                    $this.Expect([TokenType]::PUNCTUATION, ')', $null)  # Expect closing parenthesis
                }
            }
            default {
                throw "Unexpected token in expression: $($token.Type)"
            }
        }
        
    # Check for property access (e.g., user.name)
    while ($this.MatchTypeValue([TokenType]::PUNCTUATION, ".")) {
        $dotToken = $this.Consume()  # Consume the dot
        $propertyToken = $this.Expect([TokenType]::IDENTIFIER)  # Expect property name
        # Create a property access node
        $expr = [PropertyAccessNode]::new($expr, $propertyToken.Value, $dotToken.Line, $dotToken.Column, $dotToken.Filename)
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
    
    PowershellCompiler() {
        $this.Code = [System.Text.StringBuilder]::new()
        $this.IndentLevel = 0
        $this.Context = @{}
        $this.ParentBlocks = @{}
        $this.CurrentBlock = $null
    }
    
    # Compile the AST into executable PowerShell code
    # This transforms the template structure into code that can render the template
    [string]Compile([TemplateNode]$template) {
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
        
        # Process each node in the template body
        foreach ($node in $template.Body) {
            $this.Visit($node)
        }
        
        # Return the rendered output (trim trailing newline)
        $this.AppendLine()
        $this.AppendLine('return $output.ToString().TrimEnd("`r", "`n")')
        
        return $this.Code.ToString()
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
            default { throw "Unknown node type: $($node.GetType().Name)" }
        }
    }
    
    [void]VisitBlock([BlockNode]$node) {
        # Save the current block name for super() support
        $previousBlock = $this.CurrentBlock
        $this.CurrentBlock = $node.Name
        
        # Check if this block contains super() calls and we have a parent block
        $hasSuper = $false
        if ($this.ParentBlocks.ContainsKey($node.Name)) {
            # Check if any statement in the block body contains super()
            foreach ($statement in $node.Body) {
                if ($this.ContainsSuper($statement)) {
                    $hasSuper = $true
                    break
                }
            }
        }
        
        # If we have super() calls, we need to compile parent block first
        if ($hasSuper) {
            # Compile parent block content into a variable
            $parentBlock = $this.ParentBlocks[$node.Name]
            $savedBlock = $this.CurrentBlock
            $this.CurrentBlock = $null  # Prevent nested super() in parent
            
            # Add comment and variable initialization
            $this.AppendLine("# Parent block content for super()")
            $this.AppendLine("`$__SUPER_BLOCK_$($node.Name)__ = [System.Text.StringBuilder]::new()")
            
            # Create a NEW compiler instance for the parent block
            # This ensures we don't mix parent and child code
            $parentCompiler = [PowershellCompiler]::new()
            $parentCompiler.CurrentBlock = $null
            
            foreach ($statement in $parentBlock.Body) {
                $parentCompiler.Visit($statement)
            }
            
            $parentCode = $parentCompiler.Code.ToString()
            
            # Replace ALL $output.Append with parent block variable appends
            $modifiedCode = $parentCode.Replace('$output.Append', "`$__SUPER_BLOCK_$($node.Name)__.Append")
            
            # Add the modified code line by line
            $lines = $modifiedCode -split "`r?`n"
            foreach ($line in $lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $this.AppendLine($line.TrimEnd())
                }
            }
            
            # Convert to string and trim trailing newline for cleaner super() insertion
            $this.AppendLine("`$__SUPER_BLOCK_$($node.Name)__ = `$__SUPER_BLOCK_$($node.Name)__.ToString().TrimEnd(""`r"", ""`n"")")
            
            $this.CurrentBlock = $savedBlock
        }
        
        # Process block content
        foreach ($statement in $node.Body) {
            $this.Visit($statement)
        }
        
        # Restore previous block name
        $this.CurrentBlock = $previousBlock
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
        # Add null check before calling ToString()
        $this.AppendLine("`$__value__ = $expression")
        $this.AppendLine("if (`$null -ne `$__value__) {")
        $this.IndentLevel++
        $this.AppendLine("`$output.Append(`$__value__.ToString()) | Out-Null")
        $this.IndentLevel--
        $this.AppendLine("}")
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
            $this.AppendLine("`$__iterable__ = $iterable")
            $this.AppendLine("if (`$__iterable__ -and (`$__iterable__ -is [array] -and `$__iterable__.Count -gt 0) -or (`$__iterable__ -isnot [array])) {")
            $this.IndentLevel++
            
            # Generate the foreach loop
            $this.AppendLine("foreach (`$$($node.Variable) in `$__iterable__) {")
            $this.IndentLevel++
            
            foreach ($statement in $node.Body) {
                $this.Visit($statement)
            }
            
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
            # No else branch, generate simple foreach loop
            $this.AppendLine("foreach (`$$($node.Variable) in $iterable) {")
            $this.IndentLevel++
            
            foreach ($statement in $node.Body) {
                $this.Visit($statement)
            }
            
            $this.IndentLevel--
            $this.AppendLine("}")
        }
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
                
                return "($left $operator $right)"
            }
            "FilterNode" {
                $filterNode = [FilterNode]$node
                $expr = $this.VisitExpression($filterNode.Expression)
                $filterName = $filterNode.FilterName
                
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
            "SuperNode" {
                # Handle super() call - insert parent block content
                if ($null -eq $this.CurrentBlock) {
                    throw "super() can only be used inside a block"
                }
                
                if (-not $this.ParentBlocks.ContainsKey($this.CurrentBlock)) {
                    throw "No parent block found for '$($this.CurrentBlock)'"
                }
                
                # Return a placeholder that will be replaced with parent block content
                return "`$__SUPER_BLOCK_$($this.CurrentBlock)__"
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
    [string]$TemplateDir  # Directory where templates are located
    
    TemplateEngine() {
        $this.TemplateDir = ""
    }
    
    # Render a template with the given context variables
    # This is the main public method for template rendering
    [string]Render([string]$template, [hashtable]$context) {
        # Use template hash as cache key
        $cacheKey = $template.GetHashCode()
        
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
        
        # Pass parent blocks to compiler for super() support
        foreach ($blockName in $parentAst.Blocks.Keys) {
            $compiler.ParentBlocks[$blockName] = $parentAst.Blocks[$blockName]
        }
        
        $powershellCode = $compiler.Compile($mergedAst)
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
            $ast = $parser.ParseTemplate()
            
            # Step 3: Compilation - Convert AST into PowerShell code
            Write-Host "Compiling AST to PowerShell code..."
            $compiler = [PowershellCompiler]::new()
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
    # String filters
    static [string]Capitalize([string]$value) {
        if ([string]::IsNullOrEmpty($value)) {
            return ""
        }
        return [char]::ToUpper($value[0]) + $value.Substring(1).ToLower()
    }
    
    static [string]Upper([string]$value) {
        return $value.ToUpper()
    }
    
    static [string]Lower([string]$value) {
        return $value.ToLower()
    }
    
    static [string]Title([string]$value) {
        $textInfo = (Get-Culture).TextInfo
        return $textInfo.ToTitleCase($value.ToLower())
    }
    
    static [string]Trim([string]$value) {
        return $value.Trim()
    }
    
    static [string]Replace([string]$value, [string]$old, [string]$new) {
        return $value.Replace($old, $new)
    }
    
    # List filters
    static [array]First([array]$value) {
        if ($value.Count -eq 0) {
            return $null
        }
        return $value[0]
    }
    
    static [array]Last([array]$value) {
        if ($value.Count -eq 0) {
            return $null
        }
        return $value[-1]
    }
    
    static [array]Join([array]$value, [string]$delimiter = "") {
        return $value -join $delimiter
    }
    
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
    
    # Default filter
    static [string]Default([object]$value, [object]$defaultValue) {
        if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrEmpty($value))) {
            return $defaultValue
        }
        return $value
    }
    
    # Escape filters
    static [string]HtmlEscape([string]$value) {
        return $value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;").Replace("'", "&#39;")
    }
    
    static [string]UrlEncode([string]$value) {
        # Use built-in .NET class instead of System.Web.HttpUtility
        return [System.Uri]::EscapeDataString($value)
    }
    
    # Format filters
    static [string]Format([object]$value, [string]$format) {
        return $value.ToString($format)
    }
    
    # Date filters
    static [string]DateFormat([datetime]$value, [string]$format = "yyyy-MM-dd") {
        return $value.ToString($format)
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
        [hashtable]$Context
    )
    
    try {
        Write-Verbose "Creating template engine instance"
        $engine = [TemplateEngine]::new()
        
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
}

# When dot-sourcing the file, the function will be available in the current scope
# No need to use Export-ModuleMember
