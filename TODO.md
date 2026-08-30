# TODO

## Extend environment variable support to all configurable settings

**Date added:** 2026-08-30
**Priority:** Low
**Jinja2 compatibility impact:** None (Jinja2 has no config-file concept; this is a PowerShell-operational convenience)

### Background

`Invoke-AltarTemplate` exposes five configurable settings via parameters.
Only two of them (`TrimBlocks`, `LstripBlocks`) can be pre-configured through
environment variables (`Altar_TrimBlocks`, `Altar_LstripBlocks`).
The remaining three have no env-var equivalent, so they must be passed
explicitly on every call.

### Missing environment variables

| Parameter              | Env var to add              | Type                                                               |
|------------------------|-----------------------------|--------------------------------------------------------------------|
| `-LineStatementPrefix` | `Altar_LineStatementPrefix` | `string`                                                           |
| `-LineCommentPrefix`   | `Altar_LineCommentPrefix`   | `string`                                                           |
| `-UndefinedBehavior`   | `Altar_UndefinedBehavior`   | `UndefinedBehavior` enum (`Default`\|`Strict`\|`Debug`\|`Chainable`) |

### Implementation scope (all changes in `Altar.ps1`)

1. In `Invoke-AltarTemplate` — add env-var fallback blocks for the three
   missing parameters, mirroring the existing pattern for `TrimBlocks` /
   `LstripBlocks` (lines 5474–5496).
2. For `Altar_UndefinedBehavior` — parse via `[UndefinedBehavior]::Parse()`
   or a `switch`, emit `Write-Warning` on invalid values (same pattern).
3. Update `AGENTS.md` §13 (Environment Variables table) with the three
   new entries.
4. Add tests in `Tests/Integration/EnvironmentVariables.Tests.ps1`
   (mock the new variable names via `Get-AltarEnvironmentVariable`).

### Priority order (must be preserved)

`Explicit parameter > Env var > Default` — same as the existing two vars.

### Out of scope

- Config file format of any kind.
- Auto-detection of prefixes from template content.

---

## Support named block end-tags: `{% endblock blockname %}`

**Date added:** 2026-08-30
**Priority:** Low
**Jinja2 compatibility impact:** Syntactic only — purely a readability feature, no semantic difference

### Background

Jinja2 allows optionally naming the closing tag of a block to improve readability
in long or nested templates:

```jinja2
{% block content %}
    ...many lines...
{% endblock content %}
```

In Altar, `{% endblock content %}` currently throws a parse error because the parser
calls `$this.Expect([TokenType]::BLOCK_END)` immediately after consuming the
`endblock` keyword, with no handling for an optional trailing identifier
(`ParseBlockDef()`, `Altar.ps1` ~line 1733).

### Implementation scope (all changes in `Altar.ps1`)

1. In `ParseBlockDef()`, after consuming the `endblock` keyword, add an optional
   skip of one `IDENTIFIER` token before `Expect(BLOCK_END)`:
   ```powershell
   # Consume endblock
   $this.Consume() # BLOCK_START
   $this.Consume() # endblock keyword
   # Skip optional block name for Jinja2 compatibility: {% endblock blockname %}
   if ($this.Match([TokenType]::IDENTIFIER)) {
       $this.Consume()
   }
   $this.Expect([TokenType]::BLOCK_END)
   ```
2. Add a test case in `Tests/Integration/Extends.Tests.ps1` that actually **renders**
   a template with a named endblock (the existing test only checks the string,
   not the render result).
