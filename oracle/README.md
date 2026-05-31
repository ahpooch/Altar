# Jinja2 Oracle Service

A lightweight RESTful service that exposes canonical [Jinja2](https://jinja.palletsprojects.com/) rendering behavior over HTTP.

**Purpose:** provide a source-of-truth Jinja2 implementation that Pester tests for the [Altar](../README.md) PowerShell template engine can query to obtain reference outputs — without hard-coding expected strings manually.

---

## Requirements

- Python 3.11+
- PowerShell 7+ (`pwsh`) — for the cross-platform setup script

## Installation

The setup script creates an isolated Python virtual environment (`.venv`) inside the `oracle/` directory and installs all dependencies. It works identically on Windows, Linux and macOS.

```powershell
# Install dependencies only
pwsh oracle/setup.ps1

# Install and immediately start the service on the default port (5000)
pwsh oracle/setup.ps1 -Start

# Install and start on a custom port
pwsh oracle/setup.ps1 -Start -Port 8080

# Force-recreate the virtual environment from scratch
pwsh oracle/setup.ps1 -Force
```

The script resolves all OS-specific paths automatically (Python binary name, venv `Scripts/` vs `bin/`, etc.).

### CI/CD

In a CI pipeline the same command is used regardless of the runner OS:

```yaml
# GitHub Actions example
- name: Start Jinja2 Oracle
  shell: pwsh
  run: pwsh oracle/setup.ps1 -Start -Port 5000 &
```

No manual `pip install`, no manual venv activation, no OS-specific shell conditionals.

---

## Running

```powershell
# Via setup script (recommended)
pwsh oracle/setup.ps1 -Start

# Or activate the venv and run directly (Windows)
. oracle\.venv\Scripts\Activate.ps1
python oracle/app.py

# Or activate the venv and run directly (Linux / macOS)
. oracle/.venv/bin/Activate.ps1
python oracle/app.py
```

The service is ready when you see:

```
Jinja2 Oracle Service v3.1.x starting on port 5000
```

---

## API Reference

### Unified response format

Every response (success or failure) contains:

| Field        | Type    | Description                                       |
|--------------|---------|---------------------------------------------------|
| `success`    | boolean | `true` if rendering succeeded                     |
| `version`    | string  | Jinja2 version used (e.g. `"3.1.6"`)             |
| `request_id` | string  | Echoed back unchanged when provided by the client |

---

### `POST /render`

Render a single Jinja2 template.

#### Request

```json
{
  "request_id": "test_001",
  "template": "Hello {{ name | upper }}!",
  "context": { "name": "world" },
  "undefined_mode": "strict"
}
```

| Field            | Type   | Default    | Description                              |
|------------------|--------|------------|------------------------------------------|
| `template`       | string | `""`       | Jinja2 template string                   |
| `context`        | object | `{}`       | Template variables                       |
| `undefined_mode` | string | `"strict"` | `"strict"` or `"default"`               |
| `request_id`     | string | —          | Optional correlation identifier          |

`undefined_mode` values:

| Value     | Jinja2 class      | Behavior                                     |
|-----------|-------------------|----------------------------------------------|
| `strict`  | `StrictUndefined` | Raises `UndefinedError` on undefined access  |
| `default` | `Undefined`       | Returns empty string for undefined access    |

#### Success response

```json
{
  "request_id": "test_001",
  "success": true,
  "version": "3.1.6",
  "output": "Hello WORLD!"
}
```

#### Error response

```json
{
  "request_id": "test_001",
  "success": false,
  "version": "3.1.6",
  "exception": "UndefinedError",
  "message": "'foo' is undefined"
}
```

---

### `POST /batch`

Render multiple templates in a single HTTP request.

#### Request

```json
[
  {
    "request_id": "test_001",
    "template": "{{ x + y }}",
    "context": { "x": 1, "y": 2 }
  },
  {
    "request_id": "test_002",
    "template": "{{ missing_var }}",
    "context": {}
  }
]
```

#### Response

Array of results — same structure as `/render`:

```json
[
  {
    "request_id": "test_001",
    "success": true,
    "version": "3.1.6",
    "output": "3"
  },
  {
    "request_id": "test_002",
    "success": false,
    "version": "3.1.6",
    "exception": "UndefinedError",
    "message": "'missing_var' is undefined"
  }
]
```

---

### `POST /parse`

Parse a template and return its AST.

#### Request

```json
{
  "request_id": "parse_001",
  "template": "{% if user %}Hello{% endif %}"
}
```

#### Success response

```json
{
  "request_id": "parse_001",
  "success": true,
  "version": "3.1.6",
  "ast": { "node_type": "Template", "body": [ "..." ] }
}
```

---

### `POST /validate`

Validate template syntax **without rendering**.

Useful for testing the PowerShell parser independently of the interpreter.

#### Request

```json
{
  "request_id": "val_001",
  "template": "{% if user %}Hello{% endif %}"
}
```

#### Success response

```json
{
  "request_id": "val_001",
  "success": true,
  "version": "3.1.6"
}
```

#### Error response

```json
{
  "request_id": "val_001",
  "success": false,
  "version": "3.1.6",
  "exception": "TemplateSyntaxError",
  "message": "unexpected 'endif'",
  "line": 1
}
```

---

### `GET /health`

Service liveness check.

```json
{ "status": "ok", "version": "3.1.6" }
```

---

### `GET /environment`

Jinja2 environment configuration. Filters, tests and extensions are
reported dynamically — not hard-coded.

Recommended usage in CI: call this endpoint before test runs and save
the response to a log file to record the exact Jinja2 version and
available capabilities.

```json
{
  "version": "3.1.6",
  "python_version": "3.11.8",
  "environment": {
    "undefined": "StrictUndefined",
    "autoescape": false,
    "trim_blocks": false,
    "lstrip_blocks": false,
    "newline_sequence": "\n",
    "keep_trailing_newline": true,
    "optimized": true,
    "enable_async": false
  },
  "extensions": [],
  "filters": ["abs", "attr", "batch", "capitalize", "..."],
  "tests":   ["boolean", "callable", "defined", "..."]
}
```

---

### `GET /capabilities`

Machine-readable list of supported oracle features. Intended for future
API evolution without breaking client logic.

```json
{
  "render":            true,
  "batch":             true,
  "parse":             true,
  "validate":          true,
  "environment":       true,
  "strict_undefined":  true,
  "default_undefined": true,
  "ast_export":        true
}
```

---

## Usage in Pester tests

The PowerShell helper [`Tests/Helpers/OracleClient.ps1`](../Tests/Helpers/OracleClient.ps1)
wraps all endpoints. A typical test pattern:

```powershell
BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"
}

It "upper filter matches Jinja2" {
    $template = '{{ "hello world" | upper }}'

    $expected = Invoke-OracleRender -Template $template
    $actual   = Invoke-AltarTemplate -Template $template -Context @{}

    $actual | Should -Be $expected
}
```

### Starting the oracle from Pester

```powershell
BeforeAll {
    $script:Oracle = Start-OracleService
}

AfterAll {
    Stop-OracleService -Process $script:Oracle
}
```

---

## curl examples

```bash
# Health check
curl http://localhost:5000/health

# Render
curl -s -X POST http://localhost:5000/render \
  -H "Content-Type: application/json" \
  -d '{"template":"Hello {{ name }}!","context":{"name":"World"}}'

# Validate syntax
curl -s -X POST http://localhost:5000/validate \
  -H "Content-Type: application/json" \
  -d '{"template":"{% if x %}ok{% endif %}"}'

# Environment info
curl http://localhost:5000/environment
```

---

## Design principles

- **Stateless:** each request creates a fresh `jinja2.Environment`. No shared mutable state between requests.
- **Transparent errors:** Jinja2 exceptions are never suppressed. The `exception` field always contains `type(exc).__name__`.
- **Deterministic:** no random values, no current time — unless explicitly passed through `context`.
- **Minimal:** only `flask` and `jinja2` are required. No ORM, no database, no authentication.
- **Cross-platform:** `setup.ps1` abstracts OS-specific paths; the same commands work on Windows, Linux and macOS.
