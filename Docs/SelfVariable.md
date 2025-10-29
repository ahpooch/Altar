# Self Variable

The `self` variable in Altar allows you to call blocks as functions from anywhere in your template. This is a Jinja2-compatible feature that enables powerful template reusability patterns.

## Table of Contents

- [Overview](#overview)
- [Basic Usage](#basic-usage)
- [Use Cases](#use-cases)
- [Template Inheritance](#template-inheritance)
- [Recursion Protection](#recursion-protection)
- [Examples](#examples)

## Overview

In Altar templates, blocks can be called as functions using the `self.blockname()` syntax. This allows you to:

- Define reusable content once and use it multiple times
- Create component-like patterns within templates
- Avoid repetition in your templates
- Build more maintainable template structures

## Basic Usage

### Syntax

```jinja2
{% block blockname %}content{% endblock %}

{{ self.blockname() }}
```

### Simple Example

```jinja2
{% block title %}Welcome to My Site{% endblock %}

<head>
    <title>{{ self.title() }}</title>
</head>
<body>
    <h1>{{ self.title() }}</h1>
</body>
```

**Output:**
```html
<head>
    <title>Welcome to My Site</title>
</head>
<body>
    <h1>Welcome to My Site</h1>
</body>
```

## Use Cases

### 1. Reusable UI Components

Define a block once and reuse it with different variables:

```jinja2
{% block button %}<button class="btn btn-{{ style }}">{{ label }}</button>{% endblock %}

<div class="toolbar">
    {% set style = "primary" %}{% set label = "Save" %}{{ self.button() }}
    {% set style = "danger" %}{% set label = "Delete" %}{{ self.button() }}
    {% set style = "success" %}{% set label = "Submit" %}{{ self.button() }}
</div>
```

### 2. Consistent Headers and Footers

Use the same content in multiple places:

```jinja2
{% block table_header %}
<tr>
    <th>Name</th>
    <th>Email</th>
    <th>Status</th>
</tr>
{% endblock %}

<table>
    <thead>{{ self.table_header() }}</thead>
    <tbody>
        <!-- table rows -->
    </tbody>
    <tfoot>{{ self.table_header() }}</tfoot>
</table>
```

### 3. DRY (Don't Repeat Yourself) Principle

Avoid repeating the same content:

```jinja2
{% block copyright %}&copy; 2024 My Company. All rights reserved.{% endblock %}

<footer>
    <p>{{ self.copyright() }}</p>
</footer>

<div class="legal">
    <small>{{ self.copyright() }}</small>
</div>
```

## Template Inheritance

The `self` variable works seamlessly with template inheritance. When a child template overrides a block, all `self.blockname()` calls (including those in the parent template) will use the child's version.

### Base Template (base.alt)

```jinja2
{% block page_title %}Default Title{% endblock %}

<!DOCTYPE html>
<html>
<head>
    <title>{{ self.page_title() }}</title>
</head>
<body>
    <h1>{{ self.page_title() }}</h1>
    
    {% block content %}
    Default content
    {% endblock %}
    
    <footer>
        <p>{{ self.page_title() }} - All rights reserved</p>
    </footer>
</body>
</html>
```

### Child Template (page.alt)

```jinja2
{% extends "base.alt" %}

{% block page_title %}About Us{% endblock %}

{% block content %}
<h2>Welcome to {{ self.page_title() }}</h2>
<p>This is the about page.</p>
{% endblock %}
```

**Result:** All instances of `{{ self.page_title() }}` throughout the page (in both base and child templates) will display "About Us".

## Recursion Protection

To prevent infinite loops, Altar limits the recursion depth for `self.blockname()` calls.

### Default Behavior

By default, the maximum recursion depth is **1 level**. This means a block can call itself once, but not recursively beyond that.

### Example of Prevented Recursion

```jinja2
{% block recursive %}{{ self.recursive() }}{% endblock %}
```

This will throw an error: `Maximum self recursion depth exceeded for block 'recursive'`

### Configuring Recursion Depth

You can adjust the maximum recursion depth globally:

```powershell
# Set maximum recursion depth to 2 levels
[TemplateEngine]::MaxSelfRecursionDepth = 2

# Render template
$result = Invoke-AltarTemplate -Path "template.alt" -Context $context

# Reset to default (1 level)
[TemplateEngine]::MaxSelfRecursionDepth = 1
```

### Safe Recursion Pattern

If you need recursive-like behavior, use conditional logic:

```jinja2
{% block item_list %}
{% for item in items %}
    <li>{{ item }}</li>
{% endfor %}
{% endblock %}

<!-- Safe: calling block from different context -->
<ul>{{ self.item_list() }}</ul>
```

## Working with Filters

You can apply filters to `self.blockname()` calls:

```jinja2
{% block name %}john doe{% endblock %}

<p>Lowercase: {{ self.name() }}</p>
<p>Uppercase: {{ self.name() | upper }}</p>
<p>Title Case: {{ self.name() | title }}</p>
```

**Output:**
```html
<p>Lowercase: john doe</p>
<p>Uppercase: JOHN DOE</p>
<p>Title Case: John Doe</p>
```

## Combining with super()

You can use `self.blockname()` together with `super()` in inherited templates:

```jinja2
{% extends "base.alt" %}

{% block content %}
{{ super() }}
<p>Additional content</p>
<p>Title: {{ self.page_title() }}</p>
{% endblock %}
```

## Best Practices

1. **Use Descriptive Block Names**: Choose clear, semantic names for your blocks
   ```jinja2
   {% block user_greeting %}Hello, {{ username }}!{% endblock %}
   ```

2. **Keep Blocks Focused**: Each block should have a single, clear purpose
   ```jinja2
   {% block submit_button %}<button type="submit">Submit</button>{% endblock %}
   ```

3. **Avoid Deep Recursion**: Design your templates to avoid recursive `self` calls
   
4. **Document Complex Usage**: Add comments when using `self` in non-obvious ways
   ```jinja2
   {# Reuse header in both thead and tfoot #}
   {% block table_header %}...{% endblock %}
   ```

5. **Combine with Variables**: Use `{% set %}` to parameterize reusable blocks
   ```jinja2
   {% block alert %}<div class="alert-{{ type }}">{{ message }}</div>{% endblock %}
   {% set type = "info" %}{% set message = "Success!" %}{{ self.alert() }}
   ```

## Limitations

1. **No Parameters**: Unlike macros, `self.blockname()` cannot accept parameters directly
   - Use `{% set %}` to set variables before calling the block
   
2. **Recursion Depth**: Limited recursion depth to prevent infinite loops
   - Default maximum depth is 1 level
   - Can be configured via `[TemplateEngine]::MaxSelfRecursionDepth`

3. **Block Must Exist**: Calling a non-existent block will throw an error
   ```jinja2
   {{ self.nonexistent() }}  {# Error: block not found #}
   ```

## Examples

See the `Examples/Self Variable/` directory for complete working examples:

- `example-self-basic.alt` - Basic usage
- `example-self-reusable.alt` - Reusable UI components
- `example-self-inheritance-base.alt` - Base template with inheritance
- `example-self-inheritance-child.alt` - Child template using self

## Comparison with Macros

| Feature | self.blockname() | Macros |
|---------|------------------|--------|
| Parameters | No (use {% set %}) | Yes |
| Inheritance | Works with extends | Separate namespace |
| Recursion | Limited depth | Supported |
| Use Case | Template structure | Reusable functions |

## See Also

- [Template Inheritance](../README.md#template-inheritance)
- [Blocks](../README.md#blocks)
- [Macros](../README.md#macros)
- [super() Function](../README.md#super-function)
