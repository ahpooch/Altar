# Undefined Behavior (Jinja2 Compatibility)

## Overview

Altar supports different modes for handling undefined variables, compatible with Jinja2. This allows you to control how the template engine behaves when accessing non-existent variables or properties.

## Undefined Behavior Modes

### 1. Default (Default Mode)

The default mode, compatible with Jinja2. Undefined variables and properties return an empty string.

**Behavior:**
- Undefined variable → empty string
- Null variable → empty string
- Undefined property → empty string

**Example:**
```powershell
$template = "Hello {{ name }}!"
$context = @{}

$result = Invoke-AltarTemplate -Template $template -Context $context
# Result: "Hello !"
```

### 2. Debug

Debug mode. Undefined variables are output as placeholders in the format `{{ variable_name }}`.

**Behavior:**
- Undefined variable → `{{ variable_name }}`
- Null variable → empty string
- Undefined property → `{{ object.property }}`

**Example:**
```powershell
$template = "Hello {{ name }}!"
$context = @{}

$result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Debug
# Result: "Hello {{ name }}!"
```

**Use Cases:**
- Template debugging
- Visualizing missing data
- Development and testing

### 3. Strict

Strict mode. Throws an exception when accessing undefined variables.

**Behavior:**
- Undefined variable → throws `UndefinedError` exception
- Null variable → empty string
- Undefined property → throws `UndefinedError` exception

**Example:**
```powershell
$template = "Hello {{ name }}!"
$context = @{}

try {
    $result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Strict
} catch {
    Write-Host "Error: $_"
    # Result: "Error: UndefinedError: 'name' is undefined"
}
```

**Use Cases:**
- Template validation
- Ensuring data completeness
- Production environments with strict requirements

### 4. Chainable

Chainable mode. Allows accessing properties of non-existent objects without errors.

**Behavior:**
- Undefined variable → empty string
- Null variable → empty string
- Undefined property → empty string (no exception)

**Example:**
```powershell
$template = "{{ user.profile.avatar.url }}"
$context = @{
    user = @{}  # profile doesn't exist
}

$result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Chainable
# Result: "" (empty string, no exception)
```

**Use Cases:**
- Working with optional nested data
- Simplifying templates without multiple checks

## Usage

### Via Function Parameter

```powershell
# Default mode (default)
Invoke-AltarTemplate -Template $template -Context $context

# Explicitly specify mode
Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Debug
Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Strict
Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Chainable
```

### Via TemplateEngine

```powershell
$engine = [TemplateEngine]::new()
$engine.Environment.UndefinedBehavior = [UndefinedBehavior]::Debug

$result = $engine.Render($template, $context)
```

## Difference Between Undefined and Null

It's important to understand the difference between an undefined variable and a variable with a `$null` value:

### Undefined Variable
The variable doesn't exist in the context:
```powershell
$context = @{}
# 'name' is undefined
```

### Null Variable
The variable exists but its value is `$null`:
```powershell
$context = @{
    name = $null
}
# 'name' is defined but null
```

### Behavior by Mode

| Mode | Undefined | Null |
|------|-----------|------|
| Default | Empty string | Empty string |
| Debug | `{{ name }}` | Empty string |
| Strict | Exception | Empty string |
| Chainable | Empty string | Empty string |

## Usage Examples

### Example 1: Generating HTML with Optional Fields

```powershell
$template = @"
<div class="user-card">
    <h2>{{ user.name }}</h2>
    <p>Email: {{ user.email }}</p>
    <p>Phone: {{ user.phone }}</p>
</div>
"@

$context = @{
    user = @{
        name = "John Doe"
        email = "john@example.com"
        # phone is missing
    }
}

# Default mode - phone will be empty string
$result = Invoke-AltarTemplate -Template $template -Context $context
# <p>Phone: </p>

# Debug mode - shows that phone is missing
$result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Debug
# <p>Phone: {{ user.phone }}</p>
```

### Example 2: Data Validation in Strict Mode

```powershell
$template = "Order #{{ order.id }} for {{ customer.name }}"
$context = @{
    order = @{
        id = "12345"
    }
    # customer is missing
}

try {
    $result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Strict
} catch {
    Write-Host "Validation failed: Missing required data"
    # Can log or handle the error
}
```

### Example 3: Working with Deeply Nested Structures

```powershell
$template = "Avatar: {{ user.profile.settings.avatar.url }}"

# Chainable mode - safely access nested properties
$context = @{
    user = @{
        profile = @{}  # settings doesn't exist
    }
}

$result = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Chainable
# Result: "Avatar: " (no exception)
```

## Jinja2 Compatibility

The implementation closely matches Jinja2 behavior:

| Jinja2 Class | Altar Enum | Description |
|--------------|------------|-------------|
| `Undefined` | `Default` | Standard behavior |
| `StrictUndefined` | `Strict` | Strict checking |
| `DebugUndefined` | `Debug` | Debug mode |
| `ChainableUndefined` | `Chainable` | Chainable calls |

## Recommendations

1. **Development**: Use `Debug` mode to quickly identify missing data
2. **Testing**: Use `Strict` mode to validate data completeness
3. **Production**: Use `Default` mode for Jinja2 compatibility
4. **Optional Data**: Use `Chainable` for working with optional nested structures

## Caching

Templates are cached with the `UndefinedBehavior` mode taken into account. This means that the same template with different modes will be compiled separately for each mode.

```powershell
# These calls will create two different cached templates
$result1 = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Default
$result2 = Invoke-AltarTemplate -Template $template -Context $context -UndefinedBehavior Debug
