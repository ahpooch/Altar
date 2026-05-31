# Analysis of the `scoped` Modifier in Jinja2 and Altar

## What is `scoped` in Jinja2?

In Jinja2, blocks do **NOT have access** to variables from the outer scope (e.g., loop variables) by default. This is intentional to prevent issues with template inheritance.

### Example of the problem in Jinja2 (without scoped):

```jinja2
{% for item in seq %}
    <li>{% block loop_item %}{{ item }}{% endblock %}</li>
{% endfor %}
```

In Jinja2, this code will produce **empty** `<li>` elements, because the variable `item` is not accessible inside the block.

### Solution in Jinja2 — the `scoped` modifier:

```jinja2
{% for item in seq %}
    <li>{% block loop_item scoped %}{{ item }}{% endblock %}</li>
{% endfor %}
```

The `scoped` modifier **grants** the block access to variables from the outer scope.

## Behavior in Altar

### Current implementation:

In Altar, blocks inside loops **ALREADY have access** to loop variables by default:

```altar
{% for item in items %}
<li>{% block loop_item %}{{ item }}{% endblock %}</li>
{% endfor %}
```

**Output:**
```html
<li>apple</li>
<li>banana</li>
<li>cherry</li>
```

### Why does this work?

**Reason:** PowerShell uses dynamic scoping.

When the compiler generates code for a loop:

```powershell
foreach ($item in $LoopItems) {
    # Creating the loop variable
    $loop = [PSCustomObject]@{ ... }
    
    # Block code is generated here, in the same scope
    $output.Append($item.ToString()) | Out-Null
}
```

The variable `$item` is created in the `foreach` scope and is automatically accessible in all nested code blocks, including the code generated for `{% block %}`.

## Comparison

| Aspect | Jinja2 (without scoped) | Jinja2 (with scoped) | Altar (current) |
|--------|-------------------------|----------------------|-----------------|
| Access to loop variables inside a block | ❌ No | ✅ Yes | ✅ Yes (by default) |
| Syntax | `{% block name %}` | `{% block name scoped %}` | `{% block name %}` |
| Block isolation | ✅ Yes | ❌ No | ❌ No |

## Recommendations

### Option 1: Leave as is
- **Pros:** Simpler to use, no additional syntax required
- **Cons:** Differs from the default Jinja2 behavior

### Option 2: Implement full Jinja2 compatibility
- Change the default behavior: blocks do NOT have access to outer variables
- Add support for the `scoped` modifier to grant access
- **Pros:** Full Jinja2 compatibility
- **Cons:** Breaking change, increased implementation complexity

### Option 3: Add `scoped` syntax support (without changing behavior)
- The parser accepts the `scoped` modifier but ignores it
- Behavior remains the same (access is always granted)
- **Pros:** Syntactic compatibility — Jinja2 templates using `scoped` will work
- **Cons:** Semantic incompatibility (but this already exists)

## Current Status

The `scoped` modifier is **NOT implemented** in Altar. The parser throws an error when attempting to use this syntax.

**Option 3** is recommended: add syntax support for compatibility while preserving the current behavior.
