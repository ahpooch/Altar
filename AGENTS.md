# AGENTS.md — Altar Development Guide for AI Agents

> **Purpose:** This file provides AI coding agents (Cline, GitHub Copilot Workspace,
> OpenAI Codex, Cursor, Devin, etc.) with an authoritative, machine-readable map of
> the Altar project — its architecture, conventions, testing strategy, and the rules
> that must be followed when making any change.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Repository Layout](#2-repository-layout)
3. [Architecture — Processing Pipeline](#3-architecture--processing-pipeline)
4. [Class Map](#4-class-map)
5. [Public API](#5-public-api)
6. [Supported Template Features](#6-supported-template-features)
7. [Built-in Filters Reference](#7-built-in-filters-reference)
8. [Testing Guide](#8-testing-guide)
9. [Jinja2 Oracle](#9-jinja2-oracle)
10. [Code Conventions](#10-code-conventions)
11. [Adding a New Feature — Agent Checklist](#11-adding-a-new-feature--agent-checklist)
12. [Adding Tests — Canonical Template](#12-adding-tests--canonical-template)
13. [Environment Variables](#13-environment-variables)
14. [Important Constraints & Pitfalls](#14-important-constraints--pitfalls)

---

## 1. Project Overview

**Altar** is a **Jinja2-compatible template engine written entirely in PowerShell**.

| Property | Value |
|---|---|
| Language | PowerShell 7+ (`pwsh`) |
| Engine entry point | `Altar.ps1` (single file, ~5 400 lines) |
| Compatibility target | [Jinja2](https://jinja.palletsprojects.com/) (Python) |
| Test framework | [Pester 5](https://pester.dev/) |
| Reference oracle | Jinja2 via Flask HTTP API (`oracle/`) |
| Template file extension | `.alt` (convention, not enforced) |

Altar parses a template string (or file), builds an AST, compiles it to a PowerShell
`ScriptBlock`, caches the result, and executes it against a user-supplied `$Context`
hashtable to produce the final rendered string.

**The engine lives entirely in `Altar.ps1`. Do not split it into multiple files.**

---

## 2. Repository Layout

```
Altar/
├── Altar.ps1                        # entire engine (lexer + parser + compiler + filters + cmdlet)
│
├── Tests/
│   ├── Integration/                 # Pester integration tests, one file per feature
│   │   ├── BracketNotation.Tests.ps1
│   │   ├── Call.Tests.ps1
│   │   ├── Comment.Tests.ps1
│   │   ├── EnvironmentVariables.Tests.ps1
│   │   ├── Extends.Tests.ps1
│   │   ├── Filters.Tests.ps1
│   │   ├── For.Tests.ps1
│   │   ├── If.Tests.ps1
│   │   ├── Include.Tests.ps1
│   │   ├── InOperator.Tests.ps1
│   │   ├── IsOperator.Tests.ps1
│   │   ├── IsTests.Tests.ps1
│   │   ├── LineStatements.Tests.ps1
│   │   ├── Macro.Tests.ps1
│   │   ├── MethodCall.Tests.ps1
│   │   ├── Raw.Tests.ps1
│   │   ├── Self.Tests.ps1
│   │   ├── Ternary.Tests.ps1
│   │   ├── Variable.Tests.ps1
│   │   └── WhitespaceControl.Tests.ps1
│   ├── QA/                          # Unit tests for internal classes
│   │   ├── LexerState.Tests.ps1
│   │   └── Token.Tests.ps1
│   └── Helpers/
│       └── OracleClient.ps1         # PowerShell HTTP client for the Jinja2 Oracle
│
├── oracle/                          # Jinja2 reference service (Python / Flask)
│   ├── app.py                       # Flask application — the oracle
│   ├── setup.ps1                    # Cross-platform venv setup + optional start
│   ├── smoke-test.ps1               # Quick health check for the oracle
│   ├── requirements.txt             # flask, jinja2
│   └── README.md                    # Oracle API documentation
│
├── Docs/                            # Feature documentation
│   ├── LineStatements.md
│   ├── SelfVariable.md
│   └── UndefinedBehavior.md
│
├── Examples/                        # Working .alt template examples per feature
│   ├── Array Indexing/
│   ├── Call Block/
│   ├── Comment Block/
│   ├── Extends Statement/
│   ├── Filters/
│   ├── For Statesments/
│   ├── If Statesments/
│   ├── Include Statement/
│   ├── Line Statements/
│   ├── Operators/  (in, is, Ternary)
│   ├── Raw Block/
│   ├── Self Variable/
│   └── Variable/
│
├── AGENTS.md                        # this file
└── .vscode/settings.json            # cSpell word list for Jinja2-specific terms
```

---

## 3. Architecture — Processing Pipeline

Every call to `Invoke-AltarTemplate` follows this pipeline:

```
Template string / file path
        │
        ▼
┌──────────────┐
│    Lexer     │  Tokenizes raw text into a flat List[Token]
│              │  States: INITIAL → VARIABLE / BLOCK / COMMENT / RAW_BLOCK
└──────┬───────┘
       │  List[Token]
       ▼
┌──────────────┐
│    Parser    │  Consumes tokens, produces an AST rooted at TemplateNode
│              │  Handles: expressions, statements, inheritance, macros, calls
└──────┬───────┘
       │  TemplateNode (AST)
       ▼
┌────────────────────┐
│ PowershellCompiler │  Walks AST, emits a PowerShell script string
│                    │  Converts every Jinja2 construct to idiomatic PS code
└──────┬─────────────┘
       │  string (PowerShell source)
       ▼
┌──────────────┐
│  ScriptBlock │  Compiled via [scriptblock]::Create()
│   + Cache    │  Cached in [TemplateEngine]::Cache (keyed by template hash
│              │  + all lexer/environment settings — see §10)
└──────┬───────┘
       │  ScriptBlock invoked with ($Context, $TemplateDir)
       ▼
  Rendered string
```

### Template Inheritance sub-pipeline

When `{% extends "parent.alt" %}` is detected:

```
Child AST  ──┐
             ├─► MergeTemplates() ──► merged AST ──► PowershellCompiler ──► output
Parent AST ──┘
```

Parent blocks are compiled separately and injected so that `super()` calls work.

---

## 4. Class Map

All classes are defined in `Altar.ps1` in the order shown below.

### Lexer / Token layer (lines 1–1 024)

| Class | Role |
|---|---|
| `UndefinedBehavior` | Enum: `Default`, `Strict`, `Debug`, `Chainable` |
| `TokenType` | Enum of all token kinds (TEXT, VARIABLE_START, KEYWORD, …) |
| `TemplateEnvironment` | Settings bag: `UndefinedBehavior`, `TrimBlocks`, `LstripBlocks` |
| `Token` | A single lexeme: `Type`, `Value`, `Line`, `Column`, `Filename` |
| `LexerState` | Mutable cursor over the template text; owns a `Stack[string]` of lexer states |
| `Lexer` | Stateless tokenizer; static config for delimiters, prefixes, whitespace control |

### AST node layer (lines 1 025–1 397)

| Class | Role |
|---|---|
| `ASTNode` | Abstract base: `Line`, `Column`, `Filename` |
| `ExpressionNode` | Abstract base for all value-producing nodes |
| `StatementNode` | Abstract base for all statement nodes |
| `LiteralNode` | String / number / bool / null literal |
| `VariableNode` | Variable reference (`name`) |
| `PropertyAccessNode` | Dot access (`object.property`) |
| `IndexAccessNode` | Bracket access (`array[0]`, `dict['key']`) |
| `BinaryOpNode` | Binary operator (`+`, `-`, `==`, `and`, `in`, …) |
| `FilterNode` | Filter application (`value \| filter(args…)`) |
| `ConditionalExpressionNode` | Ternary (`x if condition else y`) |
| `IsTestNode` | `is` test (`value is defined`, `value is divisibleby(3)`) |
| `ArrayLiteralNode` | Array literal (`[1, 2, 3]`) |
| `DictLiteralNode` | Dict literal (`{'a': 1}`) |
| `SuperNode` | `super()` call inside an overridden block |
| `SelfCallNode` | `self.blockname()` call |
| `MacroCallNode` | Macro invocation with positional/named args |
| `MethodCallNode` | .NET method call on a value (`"str".PadRight(10)`, `var.ToUpper()`) |
| `TextNode` | Raw text pass-through |
| `OutputNode` | `{{ expression }}` — evaluated and output |
| `IfNode` | `{% if %}…{% elif %}…{% else %}…{% endif %}` |
| `ForNode` | `{% for x in collection %}…{% else %}…{% endfor %}` |
| `BlockNode` | `{% block name %}…{% endblock %}` |
| `ExtendsNode` | `{% extends "parent.alt" %}` |
| `IncludeNode` | `{% include "file.alt" %}` |
| `RawNode` | `{% raw %}…{% endraw %}` |
| `CommentNode` | `{# … #}` |
| `SetNode` | `{% set var = expr %}` |
| `MacroNode` | `{% macro name(params) %}…{% endmacro %}` |
| `CallNode` | `{% call(args) macro() %}…{% endcall %}` |
| `ImportNode` | `{% import "file" as ns %}` |
| `FromImportNode` | `{% from "file" import name %}` |
| `PowerShellBlockNode` | `{% powershell %}…{% endpowershell %}` (escape hatch) |
| `TemplateNode` | Root of the AST: `Body[]`, `Blocks{}`, `Extends` |

### Compiler / Engine layer (lines 1 398–5 422)

| Class | Role |
|---|---|
| `Parser` | Recursive-descent parser; `ParseTemplate()` returns `TemplateNode` |
| `PowershellCompiler` | AST visitor that emits a PowerShell script string |
| `TemplateEngine` | Orchestrator: `Render()`, `RenderFile()`, `Parse()`, `RenderWithInheritance()` |
| `TemplateError` | Exception type: `Message`, `Line`, `Column`, `Filename` |
| `AltarFilters` | Static class with all built-in filter methods |

### Helper function (line 5 327)

| Name | Purpose |
|---|---|
| `Get-AltarEnvironmentVariable` | Thin wrapper around `[System.Environment]::GetEnvironmentVariable()` — **must be mocked in all tests** |

---

## 5. Public API

### `Invoke-AltarTemplate`

The single public cmdlet exposed to consumers (and used in every test).

```powershell
Invoke-AltarTemplate
    [-Path] <string>              # render from a file (ParameterSet: 'Path')
    [-Template] <string>          # render from a string (ParameterSet: 'Template')
    [-Context] <hashtable>        # template variables  (mandatory, Position 1)
    [-UndefinedBehavior <UndefinedBehavior>]   # Default | Strict | Debug | Chainable
    [-LineStatementPrefix <string>]            # e.g. '#'
    [-LineCommentPrefix <string>]              # e.g. '##'
    [-TrimBlocks <bool>]                       # remove first newline after block end tag
    [-LstripBlocks <bool>]                     # strip leading whitespace before block tags
```

**Priority order for whitespace-control settings:**
`Explicit parameter  >  Env var (Altar_TrimBlocks / Altar_LstripBlocks)  >  default ($false)`

#### Quick examples

```powershell
# dot-source the engine
. .\Altar.ps1

# render from a string
$result = Invoke-AltarTemplate -Template '{{ greeting }}, {{ name }}!' `
                               -Context @{ greeting = 'Hello'; name = 'World' }

# render from a file
$result = Invoke-AltarTemplate -Path '.\Examples\Variable\example-variable.alt' `
                               -Context @{ title = 'Altar Demo' }

# strict undefined — throws on missing variable
$result = Invoke-AltarTemplate -Template '{{ missing }}' `
                               -Context @{} `
                               -UndefinedBehavior Strict

# line statements + whitespace control
$result = Invoke-AltarTemplate -Template $tpl -Context $ctx `
                               -LineStatementPrefix '#' `
                               -LineCommentPrefix '##' `
                               -TrimBlocks $true `
                               -LstripBlocks $true
```

### `TemplateEngine` (class — advanced usage)

```powershell
$engine = [TemplateEngine]::new()
$engine.Environment.UndefinedBehavior = [UndefinedBehavior]::Debug
$engine.TemplateDir = 'C:\templates'
$result = $engine.Render($templateString, $contextHashtable)
$result = $engine.RenderFile('C:\templates\page.alt', $contextHashtable)
```

---

## 6. Supported Template Features

| Feature | Syntax | Notes |
|---|---|---|
| Variable output | `{{ variable }}` | Dot and bracket access supported |
| Property access | `{{ user.name }}` | Nested: `{{ a.b.c.d }}` |
| Bracket access | `{{ dict['key'] }}`, `{{ arr[0] }}` | Mixed: `{{ a.b[0].c }}` |
| Filters | `{{ value \| filter }}`, `{{ value \| filter(args) }}` | Chainable: `{{ x \| trim \| upper }}` |
| If / elif / else | `{% if %}…{% elif %}…{% else %}…{% endif %}` | |
| For loop | `{% for x in items %}…{% else %}…{% endfor %}` | `loop.index`, `loop.index0`, `loop.first`, `loop.last`, `loop.length`, `loop.revindex`, `loop.revindex0` |
| Block | `{% block name %}…{% endblock %}` | Used with inheritance |
| Template inheritance | `{% extends "base.alt" %}` | File-based; `super()` supported |
| Include | `{% include "file.alt" %}` | Relative to template dir |
| Macro | `{% macro name(p1, p2='default') %}…{% endmacro %}` | Positional + named + default args |
| Call block | `{% call(args) macro() %}…{% endcall %}` | `caller()` inside macro |
| Set | `{% set var = expr %}` | Scoped inside blocks |
| Raw block | `{% raw %}…{% endraw %}` | Content passed through unchanged |
| Comments | `{# comment #}` | Not rendered |
| Line statements | `# for x in items` (prefix configurable) | Must be at line start |
| Line comments | `## comment` (prefix configurable) | Full-line or inline |
| Ternary operator | `x if condition else y` | |
| `in` operator | `value in collection` | |
| `is` tests | `value is defined`, `value is divisibleby(3)`, … | See IsTests.Tests.ps1 |
| Logical operators | `and`, `or`, `not` | |
| Arithmetic | `+`, `-`, `*`, `/`, `//`, `%`, `**` | |
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` | |
| Concatenation | `~` | String concat operator |
| Whitespace control | `{%- -%}`, `{{- -}}` | Trim markers |
| `self.blockname()` | `{{ self.title() }}` | Reuse block content; see Docs/SelfVariable.md |
| Undefined modes | `Default`, `Strict`, `Debug`, `Chainable` | See Docs/UndefinedBehavior.md |
| Dict literals | `{% set d = {'a': 1, 'b': 2} %}` | |
| Array literals | `{% set a = [1, 2, 3] %}` | |
| Import / from-import | `{% import "macros.alt" as m %}` | |
| PowerShell block | `{% powershell %}…{% endpowershell %}` | Escape hatch |
| .NET method calls | `{{ "str".PadRight(10) }}`, `{{ var.ToUpper() }}` | PowerShell/.NET extension — **not** Jinja2-compatible |

---

## 7. Built-in Filters Reference

All filters are static methods of `AltarFilters`. They are invoked by the compiled
ScriptBlock — never call `AltarFilters` directly in templates.

### String filters

| Filter | Signature | Description |
|---|---|---|
| `capitalize` | `(string)` | First letter upper, rest lower |
| `upper` | `(string)` | All uppercase |
| `lower` | `(string)` | All lowercase |
| `title` | `(string)` | Title Case |
| `trim` | `(string)` | Strip leading/trailing whitespace |
| `replace` | `(string, old, new[, count])` | Substring replacement, optional limit |
| `center` | `(string, width)` | Center in field |
| `reverse` | `(string)` | Reverse string |
| `indent` | `(string[, width=4[, indentFirst=false]])` | Indent lines |
| `striptags` | `(string)` | Remove HTML tags |
| `truncate` | `(string[, length[, killwords[, end]]])` | Truncate with ellipsis |
| `wordwrap` | `(string[, width=79[, breakLong=true]])` | Wrap at word boundaries |
| `escape` / `e` | `(string)` | HTML-escape `<`, `>`, `&`, `"`, `'` |
| `forceescape` | `(string)` | Force HTML-escape |
| `urlencode` | `(string)` | URL-encode |
| `urlize` | `(string[, trimLimit[, nofollow[, target]]])` | Convert URLs to `<a>` tags |
| `safe` | `(string)` | Mark as safe (no-op, for Jinja2 compat.) |
| `string` | `(object)` | Convert to string |
| `format` | `(object, formatString)` | .NET format string |
| `dateformat` | `(datetime[, format])` | Date formatting |

### List / array filters

| Filter | Signature | Description |
|---|---|---|
| `join` | `(list[, delimiter=''])` | Join items into string |
| `length` / `count` | `(collection)` | Item count |
| `reverse` | `(list)` | Reverse order |
| `sort` | `(list[, reverse[, attribute]])` | Sort items |
| `unique` | `(list)` | Remove duplicates |
| `batch` | `(list, linecount[, fillWith])` | Split into chunks |
| `slice` | `(list, slices[, fillWith])` | Slice into n groups |
| `sum` | `(list[, attribute[, start]])` | Sum values |
| `min` | `(list)` | Minimum value |
| `max` | `(list)` | Maximum value |
| `random` | `(list)` | Random element |
| `select` | `(list[, attribute])` | Filter truthy items |
| `reject` | `(list[, attribute])` | Filter falsy items |
| `selectattr` | `(list, attr[, test[, value]])` | Filter by attribute test |
| `rejectattr` | `(list, attr[, test[, value]])` | Exclude by attribute test |
| `map` | `(list, attribute)` | Extract attribute from each item |
| `groupby` | `(list, attribute)` | Group by attribute |
| `list` | `(object)` | Convert to list |
| `dictsort` | `(dict[, byValue[, reverse]])` | Sort dict entries |
| `items` | `(dict)` | Dict key-value pairs |
| `attr` | `(object, name)` | Get attribute by name |

### Math / misc filters

| Filter | Signature | Description |
|---|---|---|
| `abs` | `(number)` | Absolute value |
| `int` | `(value[, default])` | Convert to integer |
| `float` | `(value[, default])` | Convert to float |
| `round` | `(number[, precision[, method]])` | Round number |
| `default` / `d` | `(value[, default[, boolean]])` | Fallback for undefined/falsy |
| `tojson` | `(object[, indent])` | Serialize to JSON |
| `pprint` | `(object)` | Pretty-print representation |
| `filesizeformat` | `(bytes[, binary])` | Human-readable file size |
| `xmlattr` | `(dict[, autospace])` | Render HTML attribute string |
| `wordcount` | `(string)` | Count words |

---

## 8. Testing Guide

### Running tests

```powershell
# All tests (from repo root)
Invoke-Pester -Path .\Tests\ -Output Detailed

# Only integration tests
Invoke-Pester -Path .\Tests\Integration\ -Output Detailed

# Only QA (unit) tests
Invoke-Pester -Path .\Tests\QA\ -Output Detailed

# Single feature file
Invoke-Pester -Path .\Tests\Integration\Filters.Tests.ps1 -Output Detailed

# By tag
Invoke-Pester -Path .\Tests\ -Tag 'Integration' -Output Detailed
Invoke-Pester -Path .\Tests\ -Tag 'CI'          -Output Detailed
```

### File naming and location

| Pattern | Location | Tag |
|---|---|---|
| `FeatureName.Tests.ps1` | `Tests/Integration/` | `'Integration'` |
| `ClassName.Tests.ps1` | `Tests/QA/` | `'CI'` |

### Mandatory test boilerplate

Every integration test file **must**:
1. Dot-source `Altar.ps1` in `BeforeAll`
2. Mock `Get-AltarEnvironmentVariable` to return `$null`
3. Use `Describe … -Tag 'Integration'`

```powershell
BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    Mock Get-AltarEnvironmentVariable { return $null }
}

Describe 'MyFeature Integration Tests' -Tag 'Integration' {
    Context "Basic Functionality" {
        It "does the basic thing" {
            $template = '{{ greeting }}, World!'
            $context  = @{ greeting = 'Hello' }
            $result   = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be 'Hello, World!'
        }
    }
}
```

### Oracle-enhanced tests (preferred pattern for Jinja2-compatible features)

```powershell
BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
        $oraEnv = Get-OracleEnvironment
        Write-Host "  [Oracle] Jinja2 $($oraEnv.version) / Python $($oraEnv.python_version)" -ForegroundColor DarkGray
    } catch {
        Write-Warning "Jinja2 Oracle unavailable — oracle assertions skipped.`n  Run: pwsh oracle/setup.ps1 -Start"
    }

    function script:Confirm-MatchesOracle {
        param(
            [Parameter(Mandatory)] [string]    $Template,
            [hashtable]                        $Context       = @{},
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $AltarResult,
            [string]                           $UndefinedMode = 'default'
        )
        if (-not $script:OracleAvailable) { return }

        $oracle     = Invoke-OracleRender -Template $Template -Context $Context -UndefinedMode $UndefinedMode
        $altarNorm  = $AltarResult -replace '\r\n', "`n" -replace '\r', "`n"
        $oracleNorm = $oracle      -replace '\r\n', "`n" -replace '\r', "`n"
        $altarNorm | Should -Be $oracleNorm -Because 'Altar output must match canonical Jinja2 rendering'
    }
}

AfterAll {
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
}

Describe 'MyFeature Integration Tests' -Tag 'Integration' {
    It "upper filter matches Jinja2" {
        $template = '{{ "hello world" | upper }}'
        $result   = Invoke-AltarTemplate -Template $template -Context @{}
        $result | Should -Be 'HELLO WORLD'
        Confirm-MatchesOracle -Template $template -Context @{} -AltarResult $result
    }
}
```

---

## 9. Jinja2 Oracle

The **Jinja2 Oracle** is a lightweight Flask HTTP service that exposes real Jinja2
rendering over a REST API. It is the source of truth for all compatibility decisions.

### Setup and start

```powershell
# Install Python venv + deps (one-time)
pwsh oracle/setup.ps1

# Install + start service on port 5000 (default)
pwsh oracle/setup.ps1 -Start

# Custom port
pwsh oracle/setup.ps1 -Start -Port 8080

# Force-recreate venv from scratch
pwsh oracle/setup.ps1 -Force
```

The service is ready when you see:
```
Jinja2 Oracle Service v3.1.x starting on port 5000
```

### API endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Liveness check — `{"status":"ok","version":"3.1.x"}` |
| `GET` | `/environment` | Jinja2 env: version, all filters, all tests |
| `GET` | `/capabilities` | Feature flags supported by this oracle instance |
| `POST` | `/render` | Render a single template |
| `POST` | `/batch` | Render multiple templates in one request |
| `POST` | `/parse` | Parse-only — returns AST as JSON |
| `POST` | `/validate` | Syntax validation — returns `true`/`false` |

### PowerShell helper functions (`Tests/Helpers/OracleClient.ps1`)

```powershell
# Lifecycle
$process = Start-OracleService [-Port 5000] [-TimeoutSeconds 15]
Stop-OracleService -Process $process
$ready   = Test-OracleReady [-Port 5000]

# Rendering
$output  = Invoke-OracleRender   -Template $t [-Context @{}] [-UndefinedMode 'default']
$results = Invoke-OracleBatch    -Requests @(@{template=$t; context=@{}}, ...)

# Inspection
$ast   = Invoke-OracleParse    -Template $t
$valid = Invoke-OracleValidate -Template $t    # returns [bool]
$env   = Get-OracleEnvironment
$caps  = Get-OracleCapabilities
```

### Oracle design rules (do not violate these)

- **Stateless:** every request creates a fresh `jinja2.Environment`.
- **Transparent errors:** Jinja2 exceptions are never suppressed.
- **Deterministic:** no random values or timestamps unless passed via context.
- **Minimal deps:** only `flask` and `jinja2` — no ORM, no auth, no DB.

---

## 10. Code Conventions

### Naming

| Element | Convention | Example |
|---|---|---|
| Classes | PascalCase | `LexerState`, `ASTNode`, `PowershellCompiler` |
| Class methods | PascalCase | `Tokenize()`, `ParseTemplate()`, `RenderFile()` |
| Class properties | PascalCase | `$this.Position`, `$this.UndefinedBehavior` |
| Static constants | UPPER_SNAKE | `[Lexer]::TRIM_BLOCKS`, `[Lexer]::BLOCK_START` |
| Public cmdlets | Verb-Noun | `Invoke-AltarTemplate`, `Start-OracleService` |
| Parameters | PascalCase | `-Template`, `-Context`, `-UndefinedBehavior` |
| Script-scope vars | `$script:Name` | `$script:OracleAvailable` |

### Comments

- Every class, method, and non-trivial property must have a **single-line comment** on
  the line immediately above it describing its purpose.
- Public cmdlet parameters use standard PowerShell `<# .SYNOPSIS … #>` block syntax.

### Class declaration order within `Altar.ps1`

1. Enums (`UndefinedBehavior`, `TokenType`)
2. Settings / value types (`TemplateEnvironment`, `Token`, `LexerState`)
3. Lexer (`Lexer`)
4. AST nodes — base classes first, then leaves
5. Parser (`Parser`)
6. Compiler (`PowershellCompiler`)
7. Engine (`TemplateEngine`)
8. Error type (`TemplateError`)
9. Filters (`AltarFilters`)
10. Helper function (`Get-AltarEnvironmentVariable`)
11. Public cmdlet (`Invoke-AltarTemplate`)

### Cache key — completeness rule

`[TemplateEngine]::Cache` maps `string → ScriptBlock`.

The key **must** encode every input that changes compilation output:

```powershell
# Current key (TemplateEngine.Render()):
"$($template.GetHashCode())|$lineStmtPrefix|$lineCommentPrefix|$undefinedBehavior|$trimBlocks|$lstripBlocks"
```

**If you add a new Lexer or environment setting, add it to the cache key.**
Missing this causes stale ScriptBlocks to be served silently with wrong behaviour.

---

## 11. Adding a New Feature — Agent Checklist

Follow these steps in order when implementing any new template feature.

### Step 1 — Lexer (if new syntax is needed)

- [ ] Add new keyword(s) to `[Lexer]::KEYWORDS` hashtable (lines ~167–200).
- [ ] Or add a new delimiter constant (`static [string]$MY_DELIM = '...'`).
- [ ] If new syntax requires a new lexer state, add it to the `switch` in `Tokenize()`.

### Step 2 — AST node (if new semantic construct)

- [ ] Add a new class inheriting `StatementNode` (block-level) or
      `ExpressionNode` (value-producing) in the AST node section (after line 1 025).
- [ ] Always pass `$line`, `$column`, `$filename` to the base constructor.

```powershell
# Represents a new {% mytag %} statement
class MyTagNode : StatementNode {
    [string]$SomeProperty

    MyTagNode([string]$prop, [int]$line, [int]$column, [string]$filename) `
        : base($line, $column, $filename) {
        $this.SomeProperty = $prop
    }
}
```

### Step 3 — Parser

- [ ] In `Parser.ParseStatement()`, add a branch recognising the keyword, calling
      a new `ParseMyTag()` method.
- [ ] `ParseMyTag()` consumes tokens and returns the new AST node.
- [ ] Add a property to `TemplateNode` if the feature needs root-level tracking.

### Step 4 — Compiler

- [ ] Add `CompileMyTag([MyTagNode]$node)` to `PowershellCompiler`.
- [ ] Call it from `CompileStatement()` / `CompileExpression()` with a type check.
- [ ] Emit valid PowerShell code; append to `$this.Output`.

### Step 5 — Tests

- [ ] Create `Tests/Integration/MyFeature.Tests.ps1` using the template from §12.
- [ ] Cover: happy path, edge cases, error cases.
- [ ] Use `Confirm-MatchesOracle` for every Jinja2-compatible scenario.

### Step 6 — Examples

- [ ] Add at least one `.alt` example in `Examples/My Feature/`.

### Step 7 — Docs (recommended)

- [ ] Add `Docs/MyFeature.md` with syntax, parameters, and usage examples.

---

## 12. Adding Tests — Canonical Template

Copy this as the starting point for `Tests/Integration/MyFeature.Tests.ps1`.

```powershell
# Integration tests for MyFeature functionality
BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
        $oraEnv = Get-OracleEnvironment
        Write-Host "  [Oracle] Jinja2 $($oraEnv.version) / Python $($oraEnv.python_version)" -ForegroundColor DarkGray
    } catch {
        Write-Warning "Jinja2 Oracle unavailable — oracle assertions skipped.`n  Run: pwsh oracle/setup.ps1 -Start"
    }

    function script:Confirm-MatchesOracle {
        param(
            [Parameter(Mandatory)] [string]    $Template,
            [hashtable]                        $Context       = @{},
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $AltarResult,
            [string]                           $UndefinedMode = 'default'
        )
        if (-not $script:OracleAvailable) { return }
        $oracle     = Invoke-OracleRender -Template $Template -Context $Context -UndefinedMode $UndefinedMode
        $altarNorm  = $AltarResult -replace '\r\n', "`n" -replace '\r', "`n"
        $oracleNorm = $oracle      -replace '\r\n', "`n" -replace '\r', "`n"
        $altarNorm | Should -Be $oracleNorm -Because 'Altar output must match canonical Jinja2 rendering'
    }
}

AfterAll {
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
}

Describe 'MyFeature Integration Tests' -Tag 'Integration' {

    Context "Basic Functionality" {
        It "does the basic thing" {
            $template = '...'
            $context  = @{ key = 'value' }
            $result   = Invoke-AltarTemplate -Template $template -Context $context
            $result | Should -Be 'expected output'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    Context "Edge Cases" {
        It "handles empty input" { }
    }

    Context "Error Handling" {
        It "throws on invalid syntax" {
            { Invoke-AltarTemplate -Template '{% bad_tag %}' -Context @{} } | Should -Throw
        }
    }
}
```

---

## 13. Environment Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `Altar_TrimBlocks` | `bool` (via `[System.Convert]::ToBoolean`) | `$false` | Remove the first newline after a block end tag `%}` |
| `Altar_LstripBlocks` | `bool` | `$false` | Strip leading whitespace/tabs before a block start tag `{%` |

Read via `Get-AltarEnvironmentVariable` inside `Invoke-AltarTemplate`.
Explicit parameters always take precedence over env vars.

**Always mock in tests to prevent host environment bleed:**
```powershell
Mock Get-AltarEnvironmentVariable { return $null }
```

---

## 14. Important Constraints & Pitfalls

### ① Single-file rule
`Altar.ps1` is the entire engine. Do not split it into modules or separate files.
Consumers dot-source this one file and get everything. All classes, the compiler,
the filter library, and the cmdlet must stay in `Altar.ps1`.

### ② Static Lexer state is session-wide
`[Lexer]::LINE_STATEMENT_PREFIX`, `[Lexer]::LINE_COMMENT_PREFIX`,
`[Lexer]::TRIM_BLOCKS`, and `[Lexer]::LSTRIP_BLOCKS` are **static** — shared across
all instances in the same PowerShell process. `Invoke-AltarTemplate` sets them before
each call. Avoid parallel rendering calls in the same session; Pester runs tests
sequentially by default, so this is not an issue in practice.

### ③ Cache key completeness
Any new setting that changes compilation output **must** be added to the cache key in
`TemplateEngine.Render()`. Omitting it causes stale ScriptBlocks to be served silently
with wrong behaviour.

### ④ Line ending normalisation
Jinja2 (Python) always produces LF (`\n`). PowerShell on Windows may produce CRLF.
Always normalise before comparing. `Confirm-MatchesOracle` does this automatically:
```powershell
$normalised = $output -replace '\r\n', "`n" -replace '\r', "`n"
```

### ⑤ Template inheritance is file-based only
`{% extends %}` and `{% include %}` resolve paths relative to `$engine.TemplateDir`
(set automatically by `RenderFile()`). When testing inheritance, use temporary files
or invoke `TemplateEngine` directly with `TemplateDir` set.

### ⑥ `super()` requires parent block compilation
`super()` inside an overridden block works because `RenderWithInheritance()` compiles
parent blocks separately and injects their ScriptBlocks. Preserve this mechanism if
touching the inheritance pipeline.

### ⑦ `[TemplateEngine]::MaxSelfRecursionDepth`
Default is `1`. Prevents infinite loops when `self.blockname()` is called inside
the same block. Raise it only when explicitly required.

### ⑧ Use `TemplateError` for template-origin errors
Throw `[TemplateError]::new($message, $line, $column, $filename)` — not raw exceptions —
for all errors that originate from template syntax or runtime issues. This ensures
consistent error messages with file/line information.

### ⑨ Jinja2 is the final arbiter
When in doubt about correct behaviour for any feature, the oracle is the answer:
```powershell
pwsh oracle/setup.ps1 -Start
# in a second terminal:
$result = Invoke-OracleRender -Template '{{ your | filter }}' -Context @{ your = 'value' }
```
Do not hard-code expected values when `Confirm-MatchesOracle` can verify them
dynamically. Future Jinja2 upgrades are then automatically caught.

---

*Last updated: 2026-08-29 | Maintained for the Altar project*

