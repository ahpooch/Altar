# Altar vs Jinja2: Compatibility Notes

This document records intentional behavioural differences between Altar and Jinja2 —
cases where Altar deliberately diverges from Jinja2 semantics due to PowerShell
platform constraints or conscious design decisions. These are **not bugs**; bugs belong
in `KNOWN_BUGS.md`.

Understanding these differences is important for:
- Authors migrating templates from Jinja2 to Altar
- AI agents working on the codebase — do not attempt to "fix" the behaviours below

---

## ① Block scope: `scoped` modifier

### Jinja2 behaviour

In Jinja2, blocks do **not** have access to outer-scope variables (e.g., loop
variables) by default. This is intentional — it prevents subtle bugs when a block
defined in one template is overridden in a child template that has no knowledge of
the parent's loop context.

The `scoped` modifier opts a block into outer-scope access:

```jinja2
{% for item in seq %}
    {# Without scoped: item is NOT accessible inside the block #}
    <li>{% block loop_item scoped %}{{ item }}{% endblock %}</li>
{% endfor %}
```

Without `scoped`, Jinja2 renders empty `<li>` elements because `item` is undefined
inside the block.

### Altar behaviour

In Altar, blocks **always** have access to outer-scope variables. No `scoped`
modifier is needed:

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

### Why the difference exists

PowerShell uses **dynamic scoping** for `foreach` loops. The compiled output for a
`for` block looks like:

```powershell
foreach ($item in $LoopItems) {
    $loop = [PSCustomObject]@{ ... }
    # block body is inlined here — $item is naturally visible
    $output.Append($item.ToString()) | Out-Null
}
```

The loop variable `$item` lives in the `foreach` scope and is automatically visible
to all code inlined within it, including the code generated for `{% block %}`. There
is no isolation mechanism equivalent to Python's function scope.

### Syntax compatibility

The `scoped` modifier is **parsed and silently accepted** for Jinja2 template
compatibility (`Altar.ps1` — `ParseBlockDef()`), but it has no effect on behaviour.
A Jinja2 template using `{% block name scoped %}` will render correctly in Altar —
it will just always behave as if `scoped` were present.

### Summary

| Aspect | Jinja2 (without `scoped`) | Jinja2 (with `scoped`) | Altar |
|---|---|---|---|
| Loop variable accessible inside block | ❌ No | ✅ Yes | ✅ Yes (always) |
| `scoped` syntax accepted | — | ✅ Yes | ✅ Yes (no-op) |
| Block isolation from outer scope | ✅ Yes | ❌ No | ❌ No |

---

## ② `{% extends %}` accepts only string literals

### Jinja2 behaviour

Since Jinja2 2.4, the argument to `{% extends %}` can be any expression — a string
literal, a variable, or any expression that evaluates to a template name at runtime:

```jinja2
{# All of these are valid in Jinja2 #}
{% extends "base.html" %}
{% extends layout %}
{% extends get_template() %}
```

### Altar behaviour

Altar only accepts a **string literal**. Passing a variable or any other expression
throws an error at render time:

```altar
{# Works #}
{% extends "base.alt" %}

{# Throws: "Parent template name must be a string literal" #}
{% extends parentTemplate %}
```

### Why the limitation exists

`RenderWithInheritance()` (`Altar.ps1`) resolves the parent template at compile time,
before the context is available. The check is explicit:

```powershell
if ($parentExpr -isnot [LiteralNode]) {
    throw "Parent template name must be a string literal"
}
```

Supporting dynamic expressions would require deferring parent resolution to runtime
and re-entering the inheritance pipeline with a context-evaluated path — a significant
architectural change.

### Impact

Templates that use `{% extends variable %}` (a pattern occasionally seen in Jinja2
projects for theme switching) will not work in Altar without converting the expression
to a literal. Use `{% include %}` with conditional logic as a workaround if dynamic
template selection is needed.

---

*Last updated: 2026-08-30 | Maintained for the Altar project*
