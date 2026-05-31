# Call Functionality Analysis in Altar

## Analysis Date
October 24, 2025

## Summary
The **Call** functionality from Jinja2 is **partially implemented** in Altar, but has critical issues that make it **non-functional** in its current state.

## What is Call in Jinja2?

A call block in Jinja2 is a special construct that allows passing a block of content into a macro via the special variable `caller()`. This makes macros more flexible and powerful.

### Core Call Features:

1. **Basic usage**: Passing a block of content into a macro
```jinja2
{% macro render_dialog(title) -%}
    <div>
        <h2>{{ title }}</h2>
        <div class="contents">
            {{ caller() }}
        </div>
    </div>
{%- endmacro %}

{% call render_dialog('Hello World') %}
    This is the content passed to the macro.
{% endcall %}
```

2. **Call with parameters**: The macro can pass data back to the caller
```jinja2
{% macro dump_users(users) -%}
    <ul>
    {%- for user in users %}
        <li>{{ caller(user) }}</li>
    {%- endfor %}
    </ul>
{%- endmacro %}

{% call(user) dump_users(list_of_users) %}
    <p>{{ user.username }}</p>
{% endcall %}
```

## Current State in Altar

### ✅ What is implemented:

1. **AST nodes**:
   - `CallNode` — class for representing a call block in the AST
   - Contains `MacroCall` and `Body` (block content)

2. **Parsing**:
   - `ParseCall()` method exists
   - Recognizes the syntax `{% call macroname() %} ... {% endcall %}`
   - Parses the call block body

3. **Compilation**:
   - `VisitCall()` method exists
   - Generates PowerShell code for the call block
   - Creates a `__CALLER__` function with the block content

4. **Lexer**:
   - Keywords `call` and `endcall` are added to the keywords list

### ❌ What does NOT work:

1. **Critical issue #1: caller() is not defined**
   ```
   Error: The term '__MACRO_caller__' is not recognized
   ```
   - The compiler creates a `__CALLER__` function, but the macro tries to call `__MACRO_caller__`
   - Function name mismatch

2. **Critical issue #2: Call with parameters is not parsed**
   ```
   Error: Unexpected token PUNCTUATION. Expected: IDENTIFIER.
   ```
   - The syntax `{% call(user) macroname() %}` is not supported
   - The parser does not expect parameters in parentheses after `call`

3. **Issue #3: Passing parameters to caller()**
   - Even if the basic `caller()` starts working, passing parameters like `caller(user)` is not implemented

## Detailed Code Analysis

### Parser (ParseCall)
```powershell
[CallNode]ParseCall([Token]$startToken) {
    # Parse the macro call expression
    $macroCall = $this.ParseMacroCallExpression()
    
    # Expect closing %}
    $this.Expect([TokenType]::BLOCK_END)
    
    # Create call node
    $callNode = [CallNode]::new($macroCall, $startToken.Line, $startToken.Column, $startToken.Filename)
    
    # Parse call body until {% endcall %}
    # ...
}
```

**Issue**: Does not handle parameters like `{% call(user) ... %}`

### Compiler (VisitCall)
```powershell
[void]VisitCall([CallNode]$node) {
    # Generate code for call block with caller() support
    $macroCall = $node.MacroCall
    
    # First, compile the caller block into a function
    $this.AppendLine("# Call block with caller()")
    $this.AppendLine("function __CALLER__ {")
    # ...
    
    # Now call the macro with the caller function available
    $this.AppendLine("`$caller = Get-Item function:__CALLER__")
    # ...
}
```

**Issues**:
1. `__CALLER__` is created, but the macro looks for `__MACRO_caller__`
2. Parameters are not passed to the caller function
3. `$caller` is set as a variable, but the macro calls it as a function

## Is the Call Functionality Needed in Altar?

### ✅ Arguments FOR:

1. **Jinja2 compatibility**: Call is a standard Jinja2 feature
2. **Macro flexibility**: Allows creating more powerful and reusable components
3. **Alternative to loops**: Call with parameters can replace some complex loops
4. **Already partially implemented**: The basic structure exists, only fixes are needed

### ❌ Arguments AGAINST:

1. **Complexity**: Adds additional complexity to templates
2. **Alternatives**: Many tasks can be solved with regular macros and loops
3. **Rare usage**: In practice, call is not used very often in Jinja2

### 📊 Conclusion: **YES, the functionality is needed**

Reasons:
- Already partially implemented (50% of the work is done)
- Important for full Jinja2 compatibility
- Allows creating more elegant solutions for complex tasks
- The fix requires relatively small changes

## Fix Recommendations

### Priority 1: Fix the basic caller()

1. **Issue**: Name mismatch `__CALLER__` vs `__MACRO_caller__`
   
   **Solution**: In `VisitCall()` change:
   ```powershell
   # Instead of:
   $this.AppendLine("function __CALLER__ {")
   
   # Use:
   $this.AppendLine("function __MACRO_caller__ {")
   ```

2. **Issue**: `$caller` as a variable instead of a function
   
   **Solution**: Remove the line `$caller = Get-Item function:__CALLER__` and simply define the function

### Priority 2: Add parameter support in call

1. **In the parser**: Add parsing of parameters after `call`
   ```powershell
   [CallNode]ParseCall([Token]$startToken) {
       # Check for parameters: {% call(param1, param2) ... %}
       $parameters = @()
       if ($this.MatchTypeValue([TokenType]::PUNCTUATION, "(")) {
           $this.Consume()  # (
           # Parse parameter names
           while (-not $this.MatchTypeValue([TokenType]::PUNCTUATION, ")")) {
               $param = $this.Expect([TokenType]::IDENTIFIER).Value
               $parameters += $param
               if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                   $this.Consume()
               }
           }
           $this.Consume()  # )
       }
       # ...
   }
   ```

2. **In CallNode**: Add a property for parameters
   ```powershell
   class CallNode : StatementNode {
       [MacroCallNode]$MacroCall
       [StatementNode[]]$Body
       [string[]]$Parameters  # NEW
   }
   ```

3. **In the compiler**: Pass parameters to the caller function
   ```powershell
   # Generate caller function with parameters
   if ($node.Parameters.Count -gt 0) {
       $paramList = $node.Parameters -join ', $'
       $this.AppendLine("function __MACRO_caller__ {")
       $this.AppendLine("    param(`$$paramList)")
   } else {
       $this.AppendLine("function __MACRO_caller__ {")
   }
   ```

### Priority 3: Add tests

Create the file `Tests/Integration/Call.Tests.ps1` with tests for:
1. Basic call without parameters
2. Call with one parameter
3. Call with multiple parameters
4. Call with nested macros
5. Call with conditions inside

### Priority 4: Add examples

Create `Examples/Call Block/` with examples:
1. `example-call-simple.alt` — basic example
2. `example-call-with-params.alt` — with parameters
3. `example-call-dialog.alt` — practical example (dialogs)
4. `example-call-list.alt` — practical example (lists)

## Effort Estimate

- **Fixing basic caller()**: 1–2 hours
- **Adding parameter support**: 3–4 hours
- **Writing tests**: 2–3 hours
- **Creating examples and documentation**: 1–2 hours

**Total**: 7–11 hours of work

## Conclusion

Call functionality in Altar:
- ✅ **50% implemented** (structure exists but does not work)
- ❌ **Has critical bugs** (caller() is not defined, parameters are not supported)
- ✅ **Required for full Jinja2 compatibility**
- ✅ **Can be fixed relatively quickly** (7–11 hours)

**Recommendation**: Fix and bring to a working state, because:
1. The foundational work has already been done
2. The functionality is important for Jinja2 compatibility
3. The fix does not require a large time investment
4. Adds significant flexibility when working with macros
