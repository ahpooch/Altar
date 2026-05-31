# Line Statements and Line Comments in Altar

## Overview

Altar supports line statements and line comments syntax compatible with Jinja2. This allows you to write more compact and readable templates using special prefixes for statements and comments instead of full `{% %}` and `{# #}` tags.

## Line Statements

### What are Line Statements?

Line statements allow you to use a special prefix (e.g., `#`) at the beginning of a line instead of block tags `{% %}`. This makes templates more compact and similar to regular code.

### Syntax

```altar
# for item in items
    <li>{{ item }}</li>
# endfor
```

Equivalent to:

```altar
{% for item in items %}
    <li>{{ item }}</li>
{% endfor %}
```

### Configuring the Prefix

The prefix for line statements is configured via the `LineStatementPrefix` parameter of the `Invoke-AltarTemplate` function:

```powershell
Invoke-AltarTemplate -Template $template -Context $context -LineStatementPrefix '#'
```

Or directly via the static property:

```powershell
[Lexer]::LINE_STATEMENT_PREFIX = '#'
```

### Usage Rules

1. **The prefix must be at the beginning of the line** (after spaces/tabs)
2. **All statements are supported**: `for`, `if`, `elif`, `else`, `endif`, `endfor`, etc.
3. **Optional colon** at the end of the line (as in Jinja2):
   ```altar
   # for item in items:
       {{ item }}
   # endfor
   ```
4. **Works with indentation** — nested constructs can be used:
   ```altar
   # for category in categories
       <h2>{{ category.name }}</h2>
       # for item in category.items
           <li>{{ item }}</li>
       # endfor
   # endfor
   ```

### Examples

#### Basic Loop

```altar
<ul>
# for product in products
    <li>{{ product.name }} - ${{ product.price }}</li>
# endfor
</ul>
```

#### Conditional Statements

```altar
# if user_logged_in
    <p>Welcome, {{ username }}!</p>
# else
    <p>Please log in.</p>
# endif
```

#### Nested Constructs

```altar
# for category in categories
    <h2>{{ category.name }}</h2>
    <ul>
    # for item in category.items
        <li>{{ item }}</li>
    # endfor
    </ul>
# endfor
```

## Line Comments

### What are Line Comments?

Line comments allow you to add comments to a template using a special prefix (e.g., `##`). Comments are completely ignored during rendering.

### Syntax

```altar
## This is a comment - it will be ignored
<h1>User Profile</h1>

## The following section displays user information
# if user
    <div class="profile">
        <h2>{{ user.name }}</h2>  ## Display the user's name
    </div>
# endif
```

### Configuring the Prefix

The prefix for line comments is configured via the `LineCommentPrefix` parameter:

```powershell
Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '#' -LineCommentPrefix '##'
```

Or directly:

```powershell
[Lexer]::LINE_COMMENT_PREFIX = '##'
```

### Comment Types

1. **Full-line comments**:
   ```altar
   ## This is a full-line comment
   ```

2. **Inline comments**:
   ```altar
   <li>{{ item }}</li>  ## Comment at the end of the line
   ```

### Examples

```altar
## Template header
<h1>Product List</h1>

## Loop over products
# for product in products
    <li>{{ product.name }}</li>  ## Display the name
# endfor

## End of template
```

## Custom Prefixes

You can use any prefixes you like:

```powershell
# Using % for statements and // for comments
Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '%' -LineCommentPrefix '//'
```

Example template:

```altar
// User list
% for user in users
    <div>{{ user.name }}</div>  // User name
% endfor
```

## Jinja2 Compatibility

Line statements and line comments functionality is fully compatible with Jinja2:

- ✅ Prefixes are configured analogously to Jinja2
- ✅ Support for optional colon at the end of line statements
- ✅ Line comments work as in Jinja2 (full-line and inline)
- ✅ Prefix must be at the beginning of a line (after spaces)
- ✅ Works with nested constructs

## Important Notes

1. **Prefixes are reset after rendering** — this prevents side effects between different calls
2. **Caching accounts for prefixes** — changing prefixes invalidates the cache
3. **Line statements take priority over plain text** — if a line starts with the prefix, it is processed as a statement
4. **Trailing whitespace before inline comments is removed** — this ensures clean output

## Usage Examples

### Example 1: Simple List

```powershell
$template = @"
<ul>
# for item in items
    <li>{{ item }}</li>
# endfor
</ul>
"@

$context = @{ items = @('Apple', 'Banana', 'Cherry') }

$result = Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '#'
```

### Example 2: With Comments

```powershell
$template = @"
## User profile template
# if user
    <div class="profile">
        <h2>{{ user.name }}</h2>  ## Name
        <p>{{ user.email }}</p>   ## Email
    </div>
# else
    <p>User not found</p>
# endif
"@

$context = @{ user = @{ name = 'John'; email = 'john@example.com' } }

$result = Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '#' -LineCommentPrefix '##'
```

### Example 3: Nested Loops

```powershell
$template = @"
# for category in categories
    <h2>{{ category.name }}</h2>
    <ul>
    # for item in category.items
        <li>{{ item }}</li>
    # endfor
    </ul>
# endfor
"@

$context = @{
    categories = @(
        @{ name = 'Fruits'; items = @('Apple', 'Banana') },
        @{ name = 'Vegetables'; items = @('Carrot', 'Potato') }
    )
}

$result = Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '#'
```

## Disabling the Feature

If you do not want to use line statements and line comments, simply do not set the prefixes. By default they are disabled:

```powershell
# Normal mode without line statements
$result = Invoke-AltarTemplate -Template $template -Context $context
```
