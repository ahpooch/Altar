# Integration tests for trailing-newline behaviour — Altar vs canonical Jinja2.
#
# Each test calls Altar's renderer and then validates the result against the live
# Jinja2 Oracle using Confirm-MatchesOracle.  Every failing test is therefore a
# concrete Altar bug with an exact diff produced by Pester.
#
# Reference: https://ttl255.com/jinja2-tutorial-part-3-whitespace-control/
#            https://jinja.palletsprojects.com/en/stable/templates/#whitespace-control
#
# Oracle configuration assumed throughout (matches oracle/app.py _make_env):
#   keep_trailing_newline = True   — trailing LF in template is preserved in output
#   newline_sequence      = '\n'   — output always uses LF, never CRLF
#   trim_blocks           = False  — newline after %} is NOT stripped automatically
#   lstrip_blocks         = False  — leading whitespace before {% is NOT stripped
#
# All tests use default Altar settings (TrimBlocks=$false, LstripBlocks=$false)
# to match the Oracle defaults.  Whitespace-control flag combinations are already
# covered in Tests/Integration/WhitespaceControl.Tests.ps1.
#
# Run:
#   Invoke-Pester -Path .\Tests\Integration\TrailingNewlines.Tests.ps1 -Output Detailed
#   Invoke-Pester -Path .\Tests\ -Tag 'Integration' -Output Detailed

BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    # Isolate from any host environment variables that would change trim/lstrip behaviour.
    Mock Get-AltarEnvironmentVariable { return $null }

    # ------------------------------------------------------------------
    # Oracle lifecycle — start automatically; tests degrade gracefully
    # when the service is not available.
    # ------------------------------------------------------------------
    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
    } catch {
        Write-Warning "Jinja2 Oracle unavailable — oracle assertions skipped.`n  Run: pwsh oracle/setup.ps1 -Start"
    }

    # ------------------------------------------------------------------
    # Confirm-MatchesOracle
    #   Sends the same template+context to the reference Jinja2 service
    #   and asserts that Altar's output is byte-for-byte identical after
    #   LF-normalisation.  No-op when the oracle is not running.
    # ------------------------------------------------------------------
    function script:Confirm-MatchesOracle {
        param(
            [Parameter(Mandatory)] [string]    $Template,
            [hashtable]                        $Context       = @{},
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $AltarResult,
            [string]                           $UndefinedMode = 'default'
        )
        if (-not $script:OracleAvailable) { return }

        $oracle     = Invoke-OracleRender -Template $Template -Context $Context -UndefinedMode $UndefinedMode
        $altarNorm  = $AltarResult -replace "`r`n", "`n" -replace "`r", "`n"
        $oracleNorm = $oracle      -replace "`r`n", "`n" -replace "`r", "`n"
        $altarNorm | Should -Be $oracleNorm -Because 'Altar output must match canonical Jinja2 rendering'
    }

    # ------------------------------------------------------------------
    # AltarRender
    #   Convenience wrapper: renders a template string through Altar and
    #   returns the result with line endings normalised to LF so that all
    #   Should -Be comparisons work identically on Windows and Linux.
    # ------------------------------------------------------------------
    function script:AltarRender {
        param(
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $Template,
            [hashtable] $Context = @{}
        )
        $raw = Invoke-AltarTemplate -Template $Template -Context $Context
        return $raw -replace "`r`n", "`n" -replace "`r", "`n"
    }
}

AfterAll {
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
}

Describe 'Trailing-Newline Behaviour Integration Tests' -Tag 'Integration' {

    # -------------------------------------------------------------------------
    Context 'Plain text — LF pass-through' {
        # No Jinja2 tags at all.  Altar must pass raw text through unchanged.
        # keep_trailing_newline=True means a trailing LF in the source is
        # preserved verbatim in the output.

        It 'a string with no trailing newline is returned unchanged' {
            $template = 'hello'
            $result   = AltarRender -Template $template
            $result | Should -Be 'hello'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a string with a single trailing LF retains that LF' {
            $template = "hello`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "hello`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a string with two trailing LFs retains both LFs' {
            $template = "hello`n`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "hello`n`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a string that is only a single LF is returned as a single LF' {
            $template = "`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a multi-line string with a trailing LF retains all lines and the trailing LF' {
            $template = "a`nb`nc`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "a`nb`nc`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a multi-line string without a trailing LF retains all lines and no trailing LF' {
            $template = "line1`nline2"
            $result   = AltarRender -Template $template
            $result | Should -Be "line1`nline2"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }
    }

    # -------------------------------------------------------------------------
    Context 'Comment blocks — the comment is removed but surrounding whitespace stays' {
        # Rule: all language blocks are removed when rendered, but all surrounding
        # whitespace remains in place.  So {# comment #} disappears but the
        # newline that came after it stays.

        It 'a bare comment with no surrounding newlines renders as an empty string' {
            $template = '{# comment #}'
            $result   = AltarRender -Template $template
            $result | Should -Be ''
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a comment followed by a LF renders as just that LF' {
            # The comment disappears; the trailing LF is kept (keep_trailing_newline).
            $template = "{# comment #}`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a comment on its own line between two text lines leaves a blank line in the output' {
            # "line1\n" stays, comment disappears but the \n that terminated the
            # comment line remains, producing "line1\n\nline2" — the blank line
            # represents the comment line.
            $template = "line1`n{# comment #}`nline2"
            $result   = AltarRender -Template $template
            $result | Should -Be "line1`n`nline2"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a comment between text lines with trailing LF preserves both the blank line and the trailing LF' {
            $template = "line1`n{# comment #}`nline2`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "line1`n`nline2`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }
    }

    # -------------------------------------------------------------------------
    Context 'Variable output — LF is part of the template, not the variable value' {

        It 'a variable expression with no surrounding newlines outputs just the value' {
            $template = '{{ x }}'
            $context  = @{ x = 'hello' }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be 'hello'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'a variable expression followed by a LF outputs value then LF' {
            $template = "{{ x }}`n"
            $context  = @{ x = 'hello' }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be "hello`n"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'two variable expressions each on their own line with trailing LF outputs two lines' {
            $template = "{{ x }}`n{{ y }}`n"
            $context  = @{ x = 'a'; y = 'b' }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be "a`nb`n"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'a filter chain followed by a trailing LF retains the trailing LF' {
            $template = "{{ items | join(',') }}`n"
            $context  = @{ items = @(1, 2, 3) }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be "1,2,3`n"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    # -------------------------------------------------------------------------
    Context 'Block tags without strip markers — newlines adjacent to %} and {% stay' {
        # With trim_blocks=False (Altar default) the newline that follows a
        # closing %} is NOT removed.  This is the source of the "extra blank lines"
        # problem described in the Jinja2 whitespace-control documentation.

        It 'an inline if-block with no surrounding newlines outputs only the body' {
            $template = '{% if True %}hello{% endif %}'
            $result   = AltarRender -Template $template
            $result | Should -Be 'hello'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'an inline if-block followed by a LF outputs the body then that LF' {
            $template = "{% if True %}hello{% endif %}`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "hello`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'if-block tags on their own lines produce a leading LF and preserve the body LF' {
            # {% if True %} on its own line — its trailing \n stays → leading \n in output
            # hello\n  → body with its own \n
            # {% endif %} has no trailing LF in the template → no extra \n after it
            $template = "{% if True %}`nhello`n{% endif %}"
            $result   = AltarRender -Template $template
            $result | Should -Be "`nhello`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'if-block tags on their own lines with a trailing template LF produce an extra trailing LF' {
            $template = "{% if True %}`nhello`n{% endif %}`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "`nhello`n`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a set-statement on its own line leaves a blank line before the variable output' {
            # {% set x = 42 %} disappears but its trailing \n stays → blank line
            $template = "{% set x = 42 %}`n{{ x }}"
            $result   = AltarRender -Template $template
            $result | Should -Be "`n42"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a set-statement on its own line with trailing LF preserves both the blank line and the trailing LF' {
            $template = "{% set x = 42 %}`n{{ x }}`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "`n42`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }
    }

    # -------------------------------------------------------------------------
    Context 'Whitespace strip markers {%- and -%} — ALL adjacent whitespace is consumed' {
        # Key rule from the Jinja2 documentation and ttl255 article:
        #   "all of the whitespaces before/after the block are stripped, not just
        #    the ones on the same line"
        # {%- strips all whitespace (spaces, tabs, newlines) BEFORE the tag.
        # -%} strips all whitespace (spaces, tabs, newlines) AFTER the tag.

        It '{%- and -%} on every tag strips all surrounding whitespace leaving only the body' {
            $template = '{%- if True -%}hello{%- endif -%}'
            $result   = AltarRender -Template $template
            $result | Should -Be 'hello'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'strip markers on all tags surrounding a multi-line block collapse everything to the body' {
            $template = "A`n{%- if True -%}`nhello`n{%- endif -%}`nB"
            $result   = AltarRender -Template $template
            $result | Should -Be 'AhelloB'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It '{%- on the opening if strips the preceding LF; -%} on the closing strips the following LF' {
            $template = "A`n{%- if True %}hello{% endif -%}`nB"
            $result   = AltarRender -Template $template
            $result | Should -Be 'AhelloB'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It '-%} after the if tag strips the following LF so the body has no leading blank line' {
            # {% if True -%} consumes the \n after it.
            # {% endif %} has no strip marker so its preceding \n and the \n after stay.
            $template = "A`n{% if True -%}`nhello`n{% endif %}`nB"
            $result   = AltarRender -Template $template
            $result | Should -Be "A`nhello`n`nB"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It '{%- consumes ALL preceding newlines, not just the one on the same line' {
            # Two newlines before {%- are both consumed.
            $template = "line1`n`n{%- if True %}yes{% endif %}"
            $result   = AltarRender -Template $template
            $result | Should -Be 'line1yes'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It '{%- consumes the single preceding LF when there is only one' {
            $template = "line1`n{%- if True %}yes{% endif %}"
            $result   = AltarRender -Template $template
            $result | Should -Be 'line1yes'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It '-%} on the last endif consumes the template trailing LF so nothing follows the body' {
            # The template string ends with \n but -%} on endif eats it.
            $template = "{%- if True -%}hello{%- endif -%}`n"
            $result   = AltarRender -Template $template
            $result | Should -Be 'hello'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It '-%} eats the LF and any leading spaces on the next line' {
            # {% if True -%}\n   \nB → -%} eats \n + "   \n" → B glues to A.
            $template = "A{% if True -%}`n   `n   B{% endif %}C"
            $result   = AltarRender -Template $template
            $result | Should -Be 'ABC'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It '{%- on endif eats the newline before it; -%} on endif eats the newline after it' {
            # \n after {% if True %} stays → leading \n
            # {%- eats \n before endif → B glues directly to endif removal
            # -%} eats \n after endif → "after" glues directly
            $template = "{% if True %}`nB`n{%- endif -%}`nafter"
            $result   = AltarRender -Template $template
            $result | Should -Be "`nBafter"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'nested blocks with strip markers on all tags collapse to the innermost body only' {
            $template = "{%- if True -%}`n  {%- if True -%}`n    inner`n  {%- endif -%}`n{%- endif -%}"
            $result   = AltarRender -Template $template
            $result | Should -Be 'inner'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'nested blocks without any strip markers retain all surrounding newlines and indentation' {
            $template = "{% if True %}`n  {% if True %}`n    inner`n  {% endif %}`n{% endif %}"
            $result   = AltarRender -Template $template
            $result | Should -Be "`n  `n    inner`n  `n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }
    }

    # -------------------------------------------------------------------------
    Context 'For-loop trailing newlines' {
        # For loops multiply the whitespace effect: each iteration repeats the
        # newlines that surround the {% for %} and {% endfor %} tags.

        It 'an inline for-loop with no surrounding newlines concatenates all values' {
            $template = '{% for i in items %}{{ i }}{% endfor %}'
            $context  = @{ items = @(1, 2, 3) }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be '123'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'an inline for-loop followed by a template trailing LF retains that LF' {
            $template = "{% for i in items %}{{ i }}{% endfor %}`n"
            $context  = @{ items = @(1, 2, 3) }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be "123`n"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'block-style for-loop produces a leading blank before each item and trailing blank after the last' {
            # {% for %}\n  → leading \n per iteration; {% endfor %}\n → extra \n after last
            # For items [1,2]: \n1\n + \n2\n + \n(endfor) = \n1\n\n2\n\n
            $template = "{% for i in items %}`n{{ i }}`n{% endfor %}`n"
            $context  = @{ items = @(1, 2) }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be "`n1`n`n2`n`n"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'comma-separated items with no loop.last check appends a trailing comma after the last item' {
            $template = '{% for i in items %}{{ i }},{% endfor %}'
            $context  = @{ items = @(1, 2, 3) }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be '1,2,3,'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'comma-separated items using loop.last produces no trailing comma' {
            $template = '{% for i in items %}{{ i }}{% if not loop.last %},{% endif %}{% endfor %}'
            $context  = @{ items = @(1, 2, 3) }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be '1,2,3'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'loop.index produces 1-based indices, each item line terminated by the body LF' {
            $template = "{% for i in items %}{{ loop.index }}: {{ i }}`n{% endfor %}"
            $context  = @{ items = @('a', 'b', 'c') }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be "1: a`n2: b`n3: c`n"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'an empty collection with an else-branch renders the else body with no trailing LF' {
            $template = '{% for i in items %}{{ i }}{% else %}empty{% endfor %}'
            $context  = @{ items = @() }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be 'empty'
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'an empty collection with else-branch and a template trailing LF retains the trailing LF' {
            $template = "{% for i in items %}{{ i }}{% else %}empty{% endfor %}`n"
            $context  = @{ items = @() }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be "empty`n"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }

        It 'a for-loop surrounded by text lines retains surrounding text and blank separators between items' {
            # Each iteration: \n  - N\n, plus the \n from endfor before "after"
            $template = "before`n{% for i in items %}`n  - {{ i }}`n{% endfor %}`nafter"
            $context  = @{ items = @(1, 2) }
            $result   = AltarRender -Template $template -Context $context
            $result | Should -Be "before`n`n  - 1`n`n  - 2`n`nafter"
            Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
        }
    }

    # -------------------------------------------------------------------------
    Context 'Raw blocks — content passed through verbatim, surrounding LFs stay' {
        # {% raw %}...{% endraw %} passes its content through unchanged.
        # The block tags themselves follow the same newline rules as any other
        # block tag: surrounding \n characters are NOT stripped unless explicit
        # strip markers are used.

        It 'a raw block with no surrounding newlines outputs only the raw content' {
            $template = '{% raw %}{{ not_a_var }}{% endraw %}'
            $result   = AltarRender -Template $template
            $result | Should -Be '{{ not_a_var }}'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a raw block followed by a trailing LF retains the trailing LF' {
            $template = "{% raw %}{{ not_a_var }}{% endraw %}`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "{{ not_a_var }}`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'a raw block whose content spans multiple lines preserves all internal newlines' {
            $template = "{% raw %}`nline1`nline2`n{% endraw %}"
            $result   = AltarRender -Template $template
            $result | Should -Be "`nline1`nline2`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'raw block content that looks like a Jinja2 block tag is output literally' {
            $template = '{% raw %}{% for x in y %}{% endraw %}'
            $result   = AltarRender -Template $template
            $result | Should -Be '{% for x in y %}'
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }
    }

    # -------------------------------------------------------------------------
    Context 'Newline normalisation — CRLF input is normalised to LF in output' {
        # Jinja2 normalises line endings on all platforms.
        # The Oracle sets newline_sequence="\n" so output is always LF-only.
        # Altar must do the same: CRLF in the source template becomes LF in output.

        It 'CRLF at the end of a plain-text line is normalised to a plain LF in the output' {
            # Input: "hello\r\n"  ->  Output: "hello\n"
            $template = "hello`r`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "hello`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }

        It 'CRLF throughout a multi-line template is normalised to LF throughout the output' {
            # Input: "\r\nhello\r\n"  ->  Output: "\nhello\n"
            $template = "`r`nhello`r`n"
            $result   = AltarRender -Template $template
            $result | Should -Be "`nhello`n"
            Confirm-MatchesOracle -Template $template -AltarResult $result
        }
    }
}
