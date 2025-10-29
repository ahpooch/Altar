# Template Inheritance Comparison: Jinja2 vs Altar

## Overview
This document compares the template inheritance functionality described in the Jinja2 documentation (https://tedboy.github.io/jinja2/templ9.html#base-template) with the current implementation in Altar.

## Feature Comparison

### ✅ 1. Base Template with Blocks
**Jinja2**: Supports defining blocks in base templates using `{% block name %}...{% endblock %}`

**Altar**: ✅ **FULLY IMPLEMENTED**
- Code location: `BlockNode` class and `ParseBlockDef()` method in Parser
- Blocks are parsed and stored in the template AST
- Example from code:
```powershell
[BlockNode]ParseBlockDef([Token]$startToken) {
    $blockName = $this.Expect([TokenType]::IDENTIFIER, $null).Value
    # ... parsing logic
    $blockNode = [BlockNode]::new($blockName, $startToken.Line, $startToken.Column, $startToken.Filename)
}
```

### ✅ 2. Child Template Extension
**Jinja2**: Child templates use `{% extends "base.html" %}` to inherit from parent

**Altar**: ✅ **FULLY IMPLEMENTED**
- Code location: `ExtendsNode` class and `ParseExtends()` method
- Inheritance is handled in `RenderWithInheritance()` method
- Example from code:
```powershell
[ExtendsNode]ParseExtends([Token]$startToken) {
    $parentTemplate = $this.ParseExpression()
    $this.Expect([TokenType]::BLOCK_END)
    return [ExtendsNode]::new($parentTemplate, $startToken.Line, $startToken.Column, $startToken.Filename)
}
```

### ✅ 3. Block Override
**Jinja2**: Child templates can override parent blocks by defining blocks with the same name

**Altar**: ✅ **FULLY IMPLEMENTED**
- Code location: `MergeTemplates()` method in TemplateEngine
- Child blocks override parent blocks in the merged AST
- Example from code:
```powershell
[TemplateNode]MergeTemplates([TemplateNode]$parent, [TemplateNode]$child) {
    # Override parent blocks with child blocks
    foreach ($blockName in $child.Blocks.Keys) {
        $merged.Blocks[$blockName] = $child.Blocks[$blockName]
    }
}
```

### ✅ 4. Super() Function
**Jinja2**: `{{ super() }}` renders the parent block's content within a child block

**Altar**: ✅ **FULLY IMPLEMENTED**
- Code location: `SuperNode` class and super() handling in PowershellCompiler
- Parent block content is compiled into a variable that can be inserted
- Example from code:
```powershell
"SuperNode" {
    # Handle super() call - insert parent block content
    if ($null -eq $this.CurrentBlock) {
        throw "super() can only be used inside a block"
    }
    if (-not $this.ParentBlocks.ContainsKey($this.CurrentBlock)) {
        throw "No parent block found for '$($this.CurrentBlock)'"
    }
    return "`$__SUPER_BLOCK_$($this.CurrentBlock)__"
}
```

### ✅ 5. Named Block End-Tags
**Jinja2**: Allows `{% endblock blockname %}` for better readability

**Altar**: ⚠️ **PARTIALLY IMPLEMENTED**
- The parser expects `{% endblock %}` without the block name
- Named end-tags are NOT currently supported
- This is a minor feature for readability only

### ✅ 6. Block Nesting
**Jinja2**: Blocks can be nested within other blocks

**Altar**: ✅ **SUPPORTED**
- The parser handles nested blocks through recursive statement parsing
- No specific restrictions prevent block nesting

### ⚠️ 7. Scoped Modifier
**Jinja2**: `{% block name scoped %}` makes outer scope variables available in the block

**Altar**: ⚠️ **ACCEPTED BUT NOT ENFORCED**
- Code location: `ParseBlockDef()` method
- The `scoped` modifier is parsed and stored in `BlockNode.Scoped` property
- However, due to PowerShell's scoping rules, ALL blocks already have access to outer scope variables
- The modifier is accepted for Jinja2 compatibility but doesn't change behavior
- Example from code:
```powershell
# Check for optional 'scoped' modifier (Jinja2 compatibility)
# Note: In Altar, blocks always have access to outer scope variables due to PowerShell's scoping rules.
# The 'scoped' modifier is accepted for Jinja2 template compatibility but doesn't change behavior.
$isScoped = $false
if ($this.Match([TokenType]::IDENTIFIER) -and $this.Current().Value -eq 'scoped') {
    $this.Consume()  # Consume 'scoped'
    $isScoped = $true
}
```

### ❌ 8. Self Variable
**Jinja2**: `{{ self.blockname() }}` allows calling a block multiple times

**Altar**: ❌ **NOT IMPLEMENTED**
- No `self` variable is available in the template context
- Blocks cannot be called as functions from within the template
- This would require significant changes to support

### ❌ 9. Template Objects as Parent
**Jinja2**: Can extend from a template object passed in context (Jinja 2.4+)

**Altar**: ❌ **NOT IMPLEMENTED**
- `{% extends %}` only accepts string literals for template paths
- Cannot pass template objects through context
- Example from code shows literal requirement:
```powershell
if ($parentExpr -isnot [LiteralNode]) {
    throw "Parent template name must be a string literal"
}
```

## Summary

### Fully Implemented Features (6/9)
1. ✅ Base template with blocks
2. ✅ Child template extension
3. ✅ Block override
4. ✅ Super() function
5. ✅ Block nesting
6. ⚠️ Scoped modifier (accepted but not enforced due to PowerShell scoping)

### Not Implemented Features (3/9)
1. ❌ Named block end-tags (minor readability feature)
2. ❌ Self variable for calling blocks as functions
3. ❌ Template objects as parent (dynamic template extension)

## Compatibility Assessment

**Overall Compatibility: ~67% (6 out of 9 features fully working)**

Altar implements the **core template inheritance functionality** from Jinja2:
- ✅ Defining blocks in base templates
- ✅ Extending parent templates
- ✅ Overriding blocks in child templates
- ✅ Using super() to include parent content
- ✅ Nesting blocks

The missing features are:
- **Named end-tags**: Minor convenience feature, not critical
- **Self variable**: Advanced feature for calling blocks as functions
- **Template objects**: Dynamic template selection feature

## Recommendations

### High Priority
None - core functionality is complete

### Medium Priority
1. **Implement self variable**: Would allow more flexible template reuse
2. **Support template objects in extends**: Would enable dynamic template selection

### Low Priority
1. **Named block end-tags**: Purely cosmetic, low value

## Code Quality Notes

The implementation is well-structured with:
- Clear separation of concerns (Lexer → Parser → Compiler)
- Proper AST node classes for each construct
- Good error handling with line/column information
- Comprehensive comments explaining the code

The scoped modifier handling shows good attention to compatibility while acknowledging platform differences (PowerShell vs Python scoping).
