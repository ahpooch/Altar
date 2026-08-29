## Failure Triage

### Category A — Test code bug: `$context` undefined (Filters.Tests.ps1, ~35 failures)

Every test that hits `Confirm-MatchesOracle -Context $context` but used `@{}` inline in `Invoke-AltarTemplate` instead of assigning `$context` first throws `RuntimeException: The variable '$context' cannot be retrieved`. The `Should -Be` assertion itself would pass; only the Oracle call crashes. Fix: add `$context = @{}` before each `Invoke-AltarTemplate` call in those tests.

### Category B — Test code bug: wrong `$expected` value — indentation consumed by `-%}` (For.Tests.ps1, If.Tests.ps1, ~20 failures)

Templates like `{% for item in items -%}\n - {{ item }}` — the `-%}` strips the `\n` AND the two leading spaces before `- {{ item }}`, so Altar (and Oracle) both output `- apple`, not `- apple`. The hardcoded `$expected` string includes indentation that the whitespace-trim marker already removes. The `Confirm-MatchesOracle` line passes (Oracle agrees with Altar), which confirms the `$expected` values are wrong. Fix: correct the `$expected` strings to match what Oracle actually returns.

### Category C — Test code bug: trailing `\r\n` not expected (For.Tests.ps1, If.Tests.ps1, Ternary.Tests.ps1, WhitespaceControl.Tests.ps1, ~25 failures)

Tests like `$expected = "Large count"` vs Altar output `"Large count\r\n"`. The template ends with a content line whose trailing newline is real output. The `Confirm-MatchesOracle` call on the same test either passes or is not reached, confirming Oracle also returns the trailing newline. Fix: add the trailing `\r\n` to the `$expected` strings, or use `.TrimEnd()` in assertions that genuinely don't care.

### Category D — Real Altar bug: `{#-` left-trim on comments doesn't strip preceding whitespace (Comment.Tests.ps1, ~12 failures)

`{#- comment -#}` with the leading `-` should strip all whitespace before the `{#`. Oracle gives `'First line.Last line.'` but Altar gives `'First line.\nLast line.'` — Altar is not consuming the newline before `{#-`. The right-trim (`-#}`) works correctly; only the left-trim is broken. This is in the lexer/compiler's handling of `CommentNode` whitespace markers.

### Category E — Real Altar bug: `string` filter on `$null` returns `''` instead of `'None'` (Filters.Tests.ps1, 1 failure)

Jinja2 renders `{{ value | string }}` where `value` is `null` as `'None'` (Python's `str(None)`). Altar's `AltarFilters::String()` returns empty string. Fix: in the `string` filter, check for `$null` and return `'None'`.

### Category F — Real Altar bug: macros suppress surrounding newlines (Macro.Tests.ps1, 9 failures)

A template with:

```javascript
{% macro greeting(name) %}
Hello, {{ name }}!
{% endmacro %}

{{ greeting('World') }}
```

Oracle returns `'\n\n\nHello, World!\n'`. Altar returns `'Hello, World!'`. Altar is silently dropping the newlines between the macro definition block, the blank line, and the call site. The `Should -Be` assertions use `.Trim()` so they pass, but the Oracle comparison gets the trimmed Altar result against Oracle's full (untrimmed) result and fails. The core issue: Altar is not emitting the whitespace/newlines that surround macro definition statements in the compiled output, whereas Jinja2 preserves them. This is in `PowershellCompiler` — the `MacroNode` compile method eats its surrounding text nodes or the text nodes adjacent to `{% macro %}` and `{% endmacro %}` are being swallowed.

---

## Fix Plan

### Step 1 — Fix `Filters.Tests.ps1` (test-only, ~35 tests)

For every `It` block that uses `@{}` inline and then calls `Confirm-MatchesOracle -Context $context`, add `$context = @{}` as the first line of the `It` block. No Altar.ps1 change needed for this step.

### Step 2 — Fix `Filters.Tests.ps1` null→string (Altar.ps1, 1 test)

In `AltarFilters`, the `string` static method: add a `$null` guard that returns `'None'`.

### Step 3 — Fix `For.Tests.ps1` and `If.Tests.ps1` expected values (test-only, ~20 tests)

Audit each failing `$expected` string. For indentation cases, remove the spaces that `-%}` consumes. For trailing newline cases, add `\r\n` to `$expected` (or add `.TrimEnd()` to the assertion). Verify each corrected expected value matches Oracle output before finalizing.

### Step 4 — Fix `Ternary.Tests.ps1` and `WhitespaceControl.Tests.ps1` trailing newlines (test-only, ~10 tests)

Same trailing `\r\n` pattern — correct `$expected` strings.

### Step 5 — Fix comment left-trim in `Altar.ps1` (Comment.Tests.ps1, ~12 tests)

Find the lexer or compiler section that handles `{#-` comment tokens. The left-trim flag on a comment node should strip all preceding whitespace (including newlines) from the preceding `TextNode`, mirroring how `{%-` block tags work. Read the relevant lexer/compiler section of Altar.ps1 first to confirm the exact code path before patching.

### Step 6 — Fix macro surrounding newlines in `Altar.ps1` (Macro.Tests.ps1, 9 tests)

Read the `MacroNode` compile path in `PowershellCompiler`. The most likely cause is that the compiler emits nothing for a `MacroNode` at the top level and does not preserve the adjacent `TextNode` content (the newlines around it). The fix should ensure the `{% macro %}…{% endmacro %}` block is treated like other block statements with respect to surrounding whitespace — the newlines before and after it appear in the output exactly as Jinja2 would render them.

---

## Execution Order

1. `Filters.Tests.ps1` test fixes (Category A) — quick, no Altar.ps1 change, big win (35 tests).
2. `For.Tests.ps1` + `If.Tests.ps1` expected-value fixes (Categories B+C).
3. `Ternary.Tests.ps1` + `WhitespaceControl.Tests.ps1` trailing-newline fixes (Category C).
4. `Altar.ps1` — `string` filter null→`'None'` (Category E, small).
5. `Altar.ps1` — comment left-trim `{#-` (Category D, read lexer first).
6. `Altar.ps1` — macro surrounding newlines (Category F, read compiler first).

Steps 1–3 are pure test fixes and can be done in parallel. Steps 5–6 require reading Altar.ps1 before writing.
