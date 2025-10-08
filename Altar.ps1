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
    FILTER          # Template filters
    PIPE            # Pipe character | used before filters
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
    [string]$Filename                                  # Source filename
    [System.Collections.Generic.Stack[string]]$States  # Stack of lexer states (INITIAL, VARIABLE, BLOCK, COMMENT)
    
    # Constructor initializes the lexer state with the template text
    LexerState([string]$text, [string]$filename) {
        $this.Text = $text
        $this.Position = 0
        $this.Line = 1
        $this.Column = 1
        $this.Filename = $filename
        $this.States = [System.Collections.Generic.Stack[string]]::new()
        $this.States.Push("INITIAL")  # Start in the INITIAL state
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
    
    # Reserved keywords in the template language
    static [hashtable]$KEYWORDS = @{
        'if'      = $true   # Conditional blocks
        'for'     = $true   # Loop blocks
        'else'    = $true   # Alternative conditional branch
        'elif'    = $true   # Else-if conditional branch
        'endif'   = $true   # End of conditional block
        'endfor'  = $true   # End of loop block
        'in'      = $true   # Used in for loops
        'true'    = $true   # Boolean literal
        'false'   = $true   # Boolean literal
        'null'    = $true   # Null literal
        'none'    = $true   # Null literal (alias)
        'extends' = $true   # Template inheritance
        'block'   = $true   # Template block definition
        'endblock'= $true   # End of template block
        'include' = $true   # Include another template
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
                    $state.Consume()  # Consume '{'
                    $state.Consume()  # Consume '{'
                    $tokens.Add([Token]::new([TokenType]::VARIABLE_START, [Lexer]::VARIABLE_START, $state.Line, $state.Column - 2, $state.Filename))
                    $state.States.Push("VARIABLE")  # Switch to VARIABLE state
                    return
                }
                # Block tag: {% ... %}
                '%' {
                    $state.Consume()  # Consume '{'
                    $state.Consume()  # Consume '%'
                    
                    # Check for whitespace trimming syntax: {%- ... %}
                    if ($state.Peek() -eq '-') {
                        $state.Consume()  # Consume '-'
                        $tokens.Add([Token]::new([TokenType]::BLOCK_START, [Lexer]::BLOCK_START_TRIM, $state.Line, $state.Column - 3, $state.Filename))
                        
                        # Trim whitespace before the tag
                        $this.TrimWhitespaceBefore($tokens)
                    } else {
                        $tokens.Add([Token]::new([TokenType]::BLOCK_START, [Lexer]::BLOCK_START, $state.Line, $state.Column - 2, $state.Filename))
                    }
                    
                    $state.States.Push("BLOCK")  # Switch to BLOCK state
                    return
                }
                # Comment tag: {# ... #}
                '#' {
                    $state.Consume()  # Consume '{'
                    $state.Consume()  # Consume '#'
                    $tokens.Add([Token]::new([TokenType]::COMMENT_START, [Lexer]::COMMENT_START, $state.Line, $state.Column - 2, $state.Filename))
                    $state.States.Push("COMMENT")  # Switch to COMMENT state
                    return
                }
            }
        }
        
        # Process regular text content (everything up to the next tag or EOF)
        $textStart = $state.Position
        while (-not $state.IsEOF() -and $state.Peek() -ne '{') {
            $state.Consume()
        }
        
        # If we found any text content, create a TEXT token
        if ($state.Position -gt $textStart) {
            $textContent = $state.Text.Substring($textStart, $state.Position - $textStart)
            $tokens.Add([Token]::new([TokenType]::TEXT, $textContent, $state.Line, $state.Column - $textContent.Length, $state.Filename))
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
            $state.Consume()  # Consume '}'
            $state.Consume()  # Consume '}'
            $tokens.Add([Token]::new([TokenType]::VARIABLE_END, [Lexer]::VARIABLE_END, $state.Line, $state.Column - 2, $state.Filename))
            $state.States.Pop()  # Return to previous state
            return
        }
        
        # Handle block closing tags: %} or -%}
        if ($mode -eq "BLOCK") {
            # Check for whitespace trimming syntax: ... -%}
            if ($char -eq '-' -and $state.PeekOffset(1) -eq '%' -and $state.PeekOffset(2) -eq '}') {
                $state.Consume() # Consume '-'
                $state.Consume() # Consume '%'
                $state.Consume() # Consume '}'
                $tokens.Add([Token]::new([TokenType]::BLOCK_END, [Lexer]::BLOCK_END_TRIM, $state.Line, $state.Column - 3, $state.Filename))
                $state.States.Pop()  # Return to previous state
                
                # Trim whitespace after the tag
                $this.TrimWhitespaceAfter($state)
                return
            }
            # Regular block end: %}
            elseif ($char -eq '%' -and $state.PeekOffset(1) -eq '}') {
                $state.Consume()  # Consume '%'
                $state.Consume()  # Consume '}'
                $tokens.Add([Token]::new([TokenType]::BLOCK_END, [Lexer]::BLOCK_END, $state.Line, $state.Column - 2, $state.Filename))
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
            $state.Consume()
            $tokens.Add([Token]::new([TokenType]::PIPE, "|", $state.Line, $state.Column - 1, $state.Filename))
        }
        # Unexpected character
        else {
            throw "Unexpected character '$char' at line $($state.Line), column $($state.Column)"
        }
    }
    
    # Process template text inside comment blocks {# ... #}
    # Comments are ignored in the final output but need to be properly parsed
    [void]TokenizeComment([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        # Consume characters until we find the comment end marker #} or reach EOF
        while (-not $state.IsEOF()) {
            if ($state.Peek() -eq '#' -and $state.PeekOffset(1) -eq '}') {
                $state.Consume()  # Consume '#'
                $state.Consume()  # Consume '}'
                $tokens.Add([Token]::new([TokenType]::COMMENT_END, [Lexer]::COMMENT_END, $state.Line, $state.Column - 2, $state.Filename))
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
        # Consume characters until we find a non-identifier character
        while (-not $state.IsEOF() -and ($this.IsIdentifierChar($state.Peek()))) {
            $state.Consume()
        }
        
        # Extract the identifier text
        $identifier = $state.Text.Substring($start, $state.Position - $start)
        $line = $state.Line
        $column = $state.Column - $identifier.Length
        
        # Check if the identifier is a reserved keyword
        if ([Lexer]::KEYWORDS.ContainsKey($identifier)) {
            $tokens.Add([Token]::new([TokenType]::KEYWORD, $identifier, $line, $column, $state.Filename))
        }
        else {
            $tokens.Add([Token]::new([TokenType]::IDENTIFIER, $identifier, $line, $column, $state.Filename))
        }
    }
    
    # Process a numeric literal (integer or decimal)
    # Handles both integer and floating-point numbers
    [void]TokenizeNumber([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $start = $state.Position
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
        $tokens.Add([Token]::new([TokenType]::NUMBER, $number, $state.Line, $state.Column - $number.Length, $state.Filename))
    }
    
    # Process a string literal (enclosed in single or double quotes)
    # Handles escape sequences within strings
    [void]TokenizeString([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
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
        $tokens.Add([Token]::new([TokenType]::STRING, $stringContent, $state.Line, $state.Column - $stringContent.Length - 2, $state.Filename))
    }
    
    # Process a punctuation character (parentheses, brackets, commas, etc.)
    [void]TokenizePunctuation([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $char = $state.Consume()  # Consume the punctuation character
        $tokens.Add([Token]::new([TokenType]::PUNCTUATION, $char.ToString(), $state.Line, $state.Column - 1, $state.Filename))
    }
    
    # Process an operator character (+, -, *, /, =, etc.)
    [void]TokenizeOperator([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
        $char = $state.Consume()  # Consume the operator character
        $tokens.Add([Token]::new([TokenType]::OPERATOR, $char.ToString(), $state.Line, $state.Column - 1, $state.Filename))
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
        
        # Trim trailing whitespace from the content
        $trimmedContent = $content -replace '\s+$', ''
        
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
        # Skip whitespace after the tag
        while (-not $state.IsEOF() -and [char]::IsWhiteSpace($state.Peek())) {
            # If we encounter a newline, consume it and stop trimming
            # This ensures we only trim horizontal whitespace and one newline at most
            if ($state.Peek() -eq "`n") {
                $state.Consume()
                break
            }
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
    
    ForNode([string]$variable, [ExpressionNode]$iterable, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Variable = $variable
        $this.Iterable = $iterable
        $this.Body = @()          # Initialize empty array for loop body
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
    
    IncludeNode([ExpressionNode]$template, [int]$line, [int]$column, [string]$filename) : base($line, $column, $filename) {
        $this.Template = $template
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
    [bool]MatchTypeValue([TokenType]$type, [string]$value) {
        $token = $this.Current()
        if ($null -eq $token) {
            return $false  # No token to match
        }
        
        # Debug output for troubleshooting
        Write-Verbose "MatchTypeValue: Current token type: $($token.Type), Expected type: $type"
        Write-Verbose "MatchTypeValue: Current token value: '$($token.Value)', Expected value: '$value'"
        
        # Check if the token type matches
        if ($token.Type -ne $type) {
            Write-Verbose "MatchTypeValue: Type mismatch"
            return $false
        }
        
        # Check if the token value matches (if a value was specified)
        if ($null -ne $value -and $token.Value -ne $value) {
            Write-Verbose "MatchTypeValue: Value mismatch"
            return $false
        }
        
        Write-Verbose "MatchTypeValue: Match successful"
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
                    # Skip these tokens as they're handled by their respective parent parsers
                    $this.Consume() # Consume BLOCK_START
                    $this.Consume() # Consume the keyword (endfor, endif, etc.)
                    $this.Expect([TokenType]::BLOCK_END) # Consume BLOCK_END
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
            "block" { return $this.ParseBlock($startToken) }
            "include" { return $this.ParseInclude($startToken) }
            "extends" { return $this.ParseExtends($startToken) }
            "endblock" { return $null } # Just ending block
            default { throw "Unknown block keyword: $($keyword.Value)" }
        }
        return $null # only for PSScriptAnalyzer because it cannot understand derfault statement in switch
    }
    
    [ExtendsNode]ParseExtends([Token]$startToken) {
        $parentTemplate = $this.ParseExpression()
        $this.Expect([TokenType]::BLOCK_END)
        
        return [ExtendsNode]::new($parentTemplate, $startToken.Line, $startToken.Column, $startToken.Filename)
    }
    
    [BlockNode]ParseBlock([Token]$startToken) {
        $blockName = $this.Expect([TokenType]::IDENTIFIER, $null).Value
        $this.Expect([TokenType]::BLOCK_END)
        
        $blockNode = [BlockNode]::new($blockName, $startToken.Line, $startToken.Column, $startToken.Filename)
        
    # Parse block body
    while (-not ($this.Match([TokenType]::BLOCK_START) -and $this.PeekOffset(1).Value -eq 'endblock') -and -not $this.Match([TokenType]::EOF)) {
        $statement = $this.ParseStatement()
        if ($null -ne $statement) {
            $blockNode.Body += $statement
        }
    }
    
    # Check if we reached EOF without finding the expected end tag
    if ($this.Match([TokenType]::EOF)) {
        throw "Unexpected end of template. Expected: endblock"
    }
    
    # Consume endblock
    if ($this.Match([TokenType]::BLOCK_START) -and $this.PeekOffset(1).Value -eq 'endblock') {
            $this.Consume() # BLOCK_START
            $this.Consume() # endblock
            $this.Expect([TokenType]::BLOCK_END)
        }
        
        return $blockNode
    }
    
    [IncludeNode]ParseInclude([Token]$startToken) {
        $templateExpr = $this.ParseExpression()
        $this.Expect([TokenType]::BLOCK_END)
        
        return [IncludeNode]::new($templateExpr, $startToken.Line, $startToken.Column, $startToken.Filename)
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
        if ($this.Match([TokenType]::BLOCK_START) -and $this.PeekOffset(1).Value -eq 'elif') {
            Write-Host "ParseElif: Found nested elif tag"
            $this.Consume() # BLOCK_START
            $this.Consume() # elif
            $elifNode.ElifBranch = $this.ParseElif($startToken)
        } elseif ($this.Match([TokenType]::BLOCK_START) -and $this.PeekOffset(1).Value -eq 'else') {
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
        } elseif ($this.Match([TokenType]::BLOCK_START) -and $this.PeekOffset(1).Value -eq 'endif') {
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
        [int]$positionVar = $this.Position
        $currentToken = $this.Current()
        Write-Verbose "Current position: $positionVar, Token: $($currentToken.Type), Value: '$($currentToken.Value)'"
        
    while ($true) {
            Write-Verbose "In while loop, position: $($this.Position)"
            
            # Check for endfor tag
            if (($this.Position + 1) -lt $this.Tokens.Count) {
                $currentToken = $this.Current()
                $nextToken = $this.PeekOffset(1)
                
                Write-Verbose "Current token: $($currentToken.Type), Value: '$($currentToken.Value)'"
                if ($null -ne $nextToken) {
                    Write-Verbose "Next token: $($nextToken.Type), Value: '$($nextToken.Value)'"
                } else {
                    Write-Verbose "Next token: null"
                }
                
                # Check if we've reached the endfor tag
                if ($currentToken.Type -eq [TokenType]::BLOCK_START -and 
                    $nextToken.Type -eq [TokenType]::KEYWORD -and 
                    $nextToken.Value -eq 'endfor') {
                    Write-Verbose "Found endfor tag"
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
                Write-Verbose "Parsed statement is null"
            }
            
            [int]$newPositionVar = $this.Position
            if ($newPositionVar -eq $positionVar) {
                Write-Verbose "WARNING: Position did not change, potential infinite loop"
                break
            }
            $positionVar = $newPositionVar
            $currentToken = $this.Current()
            Write-Verbose "New position: $positionVar, Token: $($currentToken.Type), Value: '$($currentToken.Value)'"
        }
        
        Write-Verbose "Exited while loop"
        
        # Check if we reached EOF without finding the expected end tag
        if ($this.Match([TokenType]::EOF)) {
            Write-Verbose "Reached EOF without finding endfor"
            throw "Unexpected end of template. Expected: endfor"
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
        # Start with the highest precedence operator (logical OR)
        return $this.ParseLogicalOr()
    }
    
    # Parse logical OR expressions (e.g., a or b)
    # This has the lowest precedence in the expression hierarchy
    [ExpressionNode]ParseLogicalOr() {
        $left = $this.ParseLogicalAnd()  # Parse the left operand (higher precedence)
        
        # Look for OR operators and build a binary operation tree
        while ($this.MatchTypeValue([TokenType]::OPERATOR, "or")) {
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
        while ($this.MatchTypeValue([TokenType]::OPERATOR, "and")) {
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
                # Boolean or null literals
                switch ($token.Value.ToLower()) {
                    "true" { $expr = [LiteralNode]::new($true, $token.Line, $token.Column, $token.Filename) }
                    "false" { $expr = [LiteralNode]::new($false, $token.Line, $token.Column, $token.Filename) }
                    "null" { $expr = [LiteralNode]::new($null, $token.Line, $token.Column, $token.Filename) }
                    "none" { $expr = [LiteralNode]::new($null, $token.Line, $token.Column, $token.Filename) }
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
                    $arg = $this.ParseExpression()  # Parse argument expression
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
}

### Compiler
# PowerShell compiler that transforms the AST into executable PowerShell code
# This is the third stage of template processing (compilation)
class PowershellCompiler {
    [System.Text.StringBuilder]$Code
    [int]$IndentLevel
    [hashtable]$Context
    
    PowershellCompiler() {
        $this.Code = [System.Text.StringBuilder]::new()
        $this.IndentLevel = 0
        $this.Context = @{}
    }
    
    # Compile the AST into executable PowerShell code
    # This transforms the template structure into code that can render the template
    [string]Compile([TemplateNode]$template) {
        # Reset the code builder and indentation
        $this.Code.Clear()
        $this.IndentLevel = 0
        
        # Generate the function header
        $this.AppendLine('param($Context)')  # Context parameter contains template variables
        $this.AppendLine('$output = [System.Text.StringBuilder]::new()')  # Output buffer
        $this.AppendLine()
        
        # Process each node in the template body
        foreach ($node in $template.Body) {
            $this.Visit($node)
        }
        
        # Return the rendered output
        $this.AppendLine()
        $this.AppendLine('return $output.ToString()')
        
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
            default { throw "Unknown node type: $($node.GetType().Name)" }
        }
    }
    
    [void]VisitBlock([BlockNode]$node) {
        # TODO:
        # In a real implementation, blocks would be collected and used for template inheritance
        # For now, we'll just output the block content directly
        foreach ($statement in $node.Body) {
            $this.Visit($statement)
        }
    }
    
    [void]VisitExtends([ExtendsNode]$node) {
        # TODO:
        # In a real implementation, this would load the parent template and apply inheritance
        # For now, we'll just add a comment
        $parentTemplate = $this.VisitExpression($node.Parent)
        $this.AppendLine("# Extends template: $parentTemplate")
    }
    
    [void]VisitInclude([IncludeNode]$node) {
        # TODO:
        # In a real implementation, this would include another template
        # For now, we'll just add a comment
        $includedTemplate = $this.VisitExpression($node.Template)
        $this.AppendLine("# Include template: $includedTemplate")
    }
    
    [void]VisitText([TextNode]$node) {
        $escapedContent = $node.Content -replace "'", "''"
        $this.AppendLine("`$output.Append('$escapedContent') | Out-Null")
    }
    
    [void]VisitOutput([OutputNode]$node) {
        $expression = $this.VisitExpression($node.Expression)
        $this.AppendLine("`$output.Append(($expression).ToString()) | Out-Null")
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
        
        # Handle else branch
        if ($node.ElseBranch.Count -gt 0) {
            $this.AppendLine("} else {")
            $this.IndentLevel++
            
            foreach ($statement in $node.ElseBranch) {
                $this.Visit($statement)
            }
            
            $this.IndentLevel--
        }
        
        # Close the if statement
        $this.AppendLine("}")
    }
    
    [void]VisitFor([ForNode]$node) {
        $iterable = $this.VisitExpression($node.Iterable)
        $this.AppendLine("foreach (`$$($node.Variable) in $iterable) {")
        $this.IndentLevel++
        
        foreach ($statement in $node.Body) {
            $this.Visit($statement)
        }
        
        $this.IndentLevel--
        $this.AppendLine("}")
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
                # Check if the variable is a loop variable
                if ($variable.Name -eq 'item') {
                    return "`$$($variable.Name)"
                } else {
                    return "`$Context.'$($variable.Name)'"
                }
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
    
    # Render a template with the given context variables
    # This is the main public method for template rendering
    [string]Render([string]$template, [hashtable]$context) {
        # Use template hash as cache key
        $cacheKey = $template.GetHashCode()
        
        # Check if the template is already compiled and cached
        if (-not [TemplateEngine]::Cache.ContainsKey($cacheKey)) {
            # Compile the template and store in cache
            $compiled = $this.Compile($template)
            [TemplateEngine]::Cache[$cacheKey] = $compiled
        }
        
        # Execute the compiled template with the provided context
        $scriptBlock = [TemplateEngine]::Cache[$cacheKey]
        return & $scriptBlock $context
    }
    
    # Compile a template string into an executable PowerShell script block
    # This orchestrates the entire compilation pipeline: tokenize → parse → compile
    [scriptblock]Compile([string]$template) {
        try {
            # Step 1: Tokenization - Convert template text into tokens
            Write-Host "Tokenizing template..."
            $lexer = [Lexer]::new()
            $tokens = $lexer.Tokenize($template, "template")
            
            # Step 2: Parsing - Convert tokens into an Abstract Syntax Tree (AST)
            Write-Host "Parsing tokens..."
            $parser = [Parser]::new($tokens, "template")
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
                "template"
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
            
            # Read the template file
            Write-Verbose "Reading template file: $Path"
            try {
                $templateContent = [System.IO.File]::ReadAllText($Path)
                Write-Verbose "Template file read successfully"
            }
            catch {
                Write-Error "Error reading template file: $_"
                return
            }
            
            # Render the template
            Write-Verbose "Rendering template from file"
            $result = $engine.Render($templateContent, $Context)
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
