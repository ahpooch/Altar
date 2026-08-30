# Oracle trailing-newline tests — verify that the Jinja2 Oracle returns exactly
# the output a real Python/Jinja2 user on Linux would receive for every trailing-
# newline edge-case documented in the Jinja2 whitespace-control specification.
#
# Reference: https://ttl255.com/jinja2-tutorial-part-3-whitespace-control/
#            https://jinja.palletsprojects.com/en/stable/templates/#whitespace-control
#
# Key Oracle configuration under test (from oracle/app.py _make_env):
#   keep_trailing_newline = True   — trailing LF in template is preserved in output
#   newline_sequence      = '\n'   — output always uses LF, never CRLF
#   trim_blocks           = False  — newline after %} is NOT stripped automatically
#   lstrip_blocks         = False  — leading whitespace before {% is NOT stripped
#
# These tests have NO dependency on Altar.ps1.  They test the Oracle only.
#
# Run:
#   Invoke-Pester -Path .\Tests\Oracle\TrailingNewlines.Tests.ps1 -Output Detailed
#   Invoke-Pester -Path .\Tests\ -Tag 'Oracle' -Output Detailed

BeforeAll {
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
        $oraEnv = Get-OracleEnvironment
        Write-Host "  [Oracle] Jinja2 $($oraEnv.version) / Python $($oraEnv.python_version)" -ForegroundColor DarkGray
    } catch {
        Write-Warning "Oracle unavailable — all trailing-newline tests will be skipped.`n  Run: pwsh oracle/setup.ps1 -Start"
    }

    # Render via the Oracle and return the raw output string (LF-normalised).
    function script:OraRender {
        param(
            [Parameter(Mandatory)] [AllowEmptyString()] [string] $Template,
            [hashtable] $Context = @{}
        )
        $body = [ordered]@{
            template       = $Template
            context        = $Context
            undefined_mode = 'default'
        }
        $resp = Invoke-RestMethod `
            -Uri         'http://127.0.0.1:5000/render' `
            -Method      Post `
            -ContentType 'application/json' `
            -Body        ($body | ConvertTo-Json -Depth 20) `
            -ErrorAction Stop
        # Always normalise line endings so comparisons are CRLF-safe on Windows.
        return $resp.output -replace "`r`n", "`n" -replace "`r", "`n"
    }
}

AfterAll {
    if ($script:OracleAvailable -and $null -ne $script:OracleProcess) {
        Stop-OracleService -Process $script:OracleProcess
    }
}

Describe 'Oracle Trailing-Newline Behaviour' -Tag 'Oracle' {

    # Skip every It block when the oracle is not running.
    BeforeEach {
        if (-not $script:OracleAvailable) {
            Set-ItResult -Skipped -Because 'Oracle service is not running — run: pwsh oracle/setup.ps1 -Start'
        }
    }

    # -------------------------------------------------------------------------
    Context 'Oracle environment — keep_trailing_newline and newline_sequence' {
        # These two settings govern ALL trailing-newline behaviour in the oracle.
        # Verifying them here means a broken oracle/app.py is caught immediately.

        BeforeAll {
            if ($script:OracleAvailable) {
                $script:OraEnv = Get-OracleEnvironment
            }
        }

        It 'keep_trailing_newline is $true — Oracle preserves a trailing LF from the template source' {
            # Jinja2 default is keep_trailing_newline=False; the Oracle sets it True
            # to match the behaviour users see when loading .j2 files from disk
            # (files always end with a newline on Linux).
            $script:OraEnv.environment.keep_trailing_newline | Should -BeTrue
        }

        It 'newline_sequence is LF — Oracle never emits CRLF in its output' {
            # Jinja2 normalises to LF when newline_sequence="\n".
            $script:OraEnv.environment.newline_sequence | Should -Be "`n"
        }

        It 'trim_blocks is $false — the Oracle does not auto-strip the newline after a block end tag' {
            $script:OraEnv.environment.trim_blocks | Should -BeFalse
        }

        It 'lstrip_blocks is $false — the Oracle does not auto-strip leading whitespace before a block tag' {
            $script:OraEnv.environment.lstrip_blocks | Should -BeFalse
        }
    }

    # -------------------------------------------------------------------------
    Context 'Plain text — LF pass-through' {
        # No Jinja2 tags at all.  Jinja2 passes the raw text unchanged, so
        # keep_trailing_newline is the only thing that matters here.

        It 'a string with no trailing newline is returned unchanged' {
            OraRender -Template 'hello' | Should -Be 'hello'
        }

        It 'a string with a single trailing LF retains that LF' {
            OraRender -Template "hello`n" | Should -Be "hello`n"
        }

        It 'a string with two trailing LFs retains both LFs' {
            OraRender -Template "hello`n`n" | Should -Be "hello`n`n"
        }

        It 'a string that is only a single LF is returned as a single LF' {
            OraRender -Template "`n" | Should -Be "`n"
        }

        It 'a multi-line string with a trailing LF retains all lines and the trailing LF' {
            OraRender -Template "a`nb`nc`n" | Should -Be "a`nb`nc`n"
        }

        It 'a multi-line string without a trailing LF retains all lines and no trailing LF' {
            OraRender -Template "line1`nline2" | Should -Be "line1`nline2"
        }
    }

    # -------------------------------------------------------------------------
    Context 'Comment blocks — the comment is removed but surrounding whitespace stays' {
        # Rule from Jinja2 docs and ttl255 article:
        #   "All of the language blocks are removed when the template is rendered
        #    but all of the whitespaces remain in place."
        # So {# comment #} disappears, but the newline that came AFTER it stays.

        It 'a bare comment with no surrounding newlines renders as an empty string' {
            OraRender -Template '{# comment #}' | Should -Be ''
        }

        It 'a comment followed by a LF renders as just that LF' {
            # The comment disappears; the trailing LF is kept by keep_trailing_newline.
            OraRender -Template "{# comment #}`n" | Should -Be "`n"
        }

        It 'a comment on its own line between two text lines leaves a blank line in the output' {
            # "line1\n" stays, comment disappears but its surrounding "\n" remains,
            # producing "line1\n\nline2" — the blank line represents the comment line.
            OraRender -Template "line1`n{# comment #}`nline2" | Should -Be "line1`n`nline2"
        }

        It 'a comment between text lines with a trailing LF preserves both the blank line and the trailing LF' {
            OraRender -Template "line1`n{# comment #}`nline2`n" | Should -Be "line1`n`nline2`n"
        }
    }

    # -------------------------------------------------------------------------
    Context 'Variable output — LF is part of the template, not the variable value' {

        It 'a variable expression with no surrounding newlines outputs just the value' {
            OraRender -Template '{{ x }}' -Context @{ x = 'hello' } | Should -Be 'hello'
        }

        It 'a variable expression followed by a LF outputs value then LF' {
            OraRender -Template "{{ x }}`n" -Context @{ x = 'hello' } | Should -Be "hello`n"
        }

        It 'two variable expressions each on their own line with trailing LF outputs two lines' {
            OraRender -Template "{{ x }}`n{{ y }}`n" -Context @{ x = 'a'; y = 'b' } |
                Should -Be "a`nb`n"
        }

        It 'a filter chain followed by a trailing LF retains the trailing LF' {
            OraRender -Template "{{ items | join(',') }}`n" -Context @{ items = @(1, 2, 3) } |
                Should -Be "1,2,3`n"
        }
    }

    # -------------------------------------------------------------------------
    Context 'Block tags without strip markers — newlines adjacent to %} and {% stay' {
        # With trim_blocks=False (the Oracle default) the newline that follows a
        # closing %} is NOT removed.  This is the source of the "extra blank lines"
        # problem described in the ttl255 article.

        It 'an inline if-block with no surrounding newlines outputs only the body' {
            OraRender -Template '{% if True %}hello{% endif %}' | Should -Be 'hello'
        }

        It 'an inline if-block followed by a LF outputs the body then that LF' {
            OraRender -Template "{% if True %}hello{% endif %}`n" | Should -Be "hello`n"
        }

        It 'if-block tags on their own lines produce a leading LF and preserve the body LF' {
            # {% if True %} on its own line — its trailing \n stays  →  leading \n
            # hello\n  →  body with its own \n
            # {% endif %} has no trailing LF in the template  →  no extra \n after it
            OraRender -Template "{% if True %}`nhello`n{% endif %}" | Should -Be "`nhello`n"
        }

        It 'if-block tags on their own lines with a trailing template LF produce an extra trailing LF' {
            OraRender -Template "{% if True %}`nhello`n{% endif %}`n" | Should -Be "`nhello`n`n"
        }

        It 'a set-statement on its own line leaves a blank line before the variable output' {
            # {% set x = 42 %} disappears but its trailing \n stays
            OraRender -Template "{% set x = 42 %}`n{{ x }}" | Should -Be "`n42"
        }

        It 'a set-statement on its own line with trailing LF preserves both the blank line and the trailing LF' {
            OraRender -Template "{% set x = 42 %}`n{{ x }}`n" | Should -Be "`n42`n"
        }
    }

    # -------------------------------------------------------------------------
    Context 'Whitespace strip markers {%- and -%} — ALL adjacent whitespace is consumed' {
        # Key rule from ttl255 article:
        #   "all of the whitespaces before/after the block are stripped, not just
        #    the ones on the same line"
        # {%- strips whitespace (spaces, tabs, newlines) BEFORE the tag.
        # -%} strips whitespace (spaces, tabs, newlines) AFTER the tag.

        It '{%- and -%} on every tag strips all surrounding whitespace leaving only the body' {
            OraRender -Template '{%- if True -%}hello{%- endif -%}' | Should -Be 'hello'
        }

        It 'strip markers on all tags surrounding a multi-line block collapse everything to the body' {
            OraRender -Template "A`n{%- if True -%}`nhello`n{%- endif -%}`nB" | Should -Be 'AhelloB'
        }

        It '{%- on the opening if strips the preceding LF; -%} on the closing strips the following LF' {
            OraRender -Template "A`n{%- if True %}hello{% endif -%}`nB" | Should -Be 'AhelloB'
        }

        It '-%} after the if tag strips the following LF so the body has no leading blank line' {
            # {% if True -%} consumes the \n after it.
            # {% endif %} has no strip marker so its preceding \n and the \n after stay.
            OraRender -Template "A`n{% if True -%}`nhello`n{% endif %}`nB" | Should -Be "A`nhello`n`nB"
        }

        It '{%- consumes ALL preceding newlines, not just the one on the same line' {
            # Two newlines before {%- are both consumed.
            OraRender -Template "line1`n`n{%- if True %}yes{% endif %}" | Should -Be 'line1yes'
        }

        It '{%- consumes the single preceding LF when there is only one' {
            OraRender -Template "line1`n{%- if True %}yes{% endif %}" | Should -Be 'line1yes'
        }

        It '-%} on the last endif consumes the template trailing LF so nothing follows the body' {
            # The template string ends with \n but -%} on endif eats it.
            OraRender -Template "{%- if True -%}hello{%- endif -%}`n" | Should -Be 'hello'
        }

        It '-%} eats the LF and any leading spaces on the next line' {
            # {% if True -%}\n   \nB → -%} eats \n + "   \n" → B glues to A.
            OraRender -Template "A{% if True -%}`n   `n   B{% endif %}C" | Should -Be 'ABC'
        }

        It '{%- on endif eats the newline before it; -%} on endif eats the newline after it' {
            # \n after {% if True %} stays  →  leading \n
            # {%- eats \n before endif  →  B glues directly to endif removal
            # -%} eats \n after endif  →  "after" glues directly
            OraRender -Template "{% if True %}`nB`n{%- endif -%}`nafter" | Should -Be "`nBafter"
        }

        It 'nested blocks with strip markers on all tags collapse to the innermost body only' {
            $tpl = "{%- if True -%}`n  {%- if True -%}`n    inner`n  {%- endif -%}`n{%- endif -%}"
            OraRender -Template $tpl | Should -Be 'inner'
        }

        It 'nested blocks without any strip markers retain all surrounding newlines and indentation' {
            $tpl = "{% if True %}`n  {% if True %}`n    inner`n  {% endif %}`n{% endif %}"
            OraRender -Template $tpl | Should -Be "`n  `n    inner`n  `n"
        }
    }

    # -------------------------------------------------------------------------
    Context 'For-loop trailing newlines' {
        # For loops multiply the whitespace effect: each iteration repeats the
        # newlines that surround the {% for %} and {% endfor %} tags.

        It 'an inline for-loop with no surrounding newlines concatenates all values' {
            OraRender -Template '{% for i in items %}{{ i }}{% endfor %}' `
                       -Context @{ items = @(1, 2, 3) } |
                Should -Be '123'
        }

        It 'an inline for-loop followed by a template trailing LF retains that LF' {
            OraRender -Template "{% for i in items %}{{ i }}{% endfor %}`n" `
                       -Context @{ items = @(1, 2, 3) } |
                Should -Be "123`n"
        }

        It 'block-style for-loop produces a leading blank before each item and trailing blank after the last' {
            # {% for %}\n  → leading \n per iteration
            # {{ i }}\n    → item line
            # {% endfor %}\n → extra \n after last iteration + \n from template
            # For items [1,2]: \n1\n + \n2\n + \n(endfor) = \n1\n\n2\n\n
            OraRender -Template "{% for i in items %}`n{{ i }}`n{% endfor %}`n" `
                       -Context @{ items = @(1, 2) } |
                Should -Be "`n1`n`n2`n`n"
        }

        It 'comma-separated items with no loop.last check appends a trailing comma after the last item' {
            OraRender -Template '{% for i in items %}{{ i }},{% endfor %}' `
                       -Context @{ items = @(1, 2, 3) } |
                Should -Be '1,2,3,'
        }

        It 'comma-separated items using loop.last produces no trailing comma' {
            OraRender -Template '{% for i in items %}{{ i }}{% if not loop.last %},{% endif %}{% endfor %}' `
                       -Context @{ items = @(1, 2, 3) } |
                Should -Be '1,2,3'
        }

        It 'loop.index produces 1-based indices, each item line terminated by the body LF' {
            OraRender -Template "{% for i in items %}{{ loop.index }}: {{ i }}`n{% endfor %}" `
                       -Context @{ items = @('a', 'b', 'c') } |
                Should -Be "1: a`n2: b`n3: c`n"
        }

        It 'an empty collection with an else-branch renders the else body with no trailing LF' {
            OraRender -Template '{% for i in items %}{{ i }}{% else %}empty{% endfor %}' `
                       -Context @{ items = @() } |
                Should -Be 'empty'
        }

        It 'an empty collection with else-branch and a template trailing LF retains the trailing LF' {
            OraRender -Template "{% for i in items %}{{ i }}{% else %}empty{% endfor %}`n" `
                       -Context @{ items = @() } |
                Should -Be "empty`n"
        }

        It 'a for-loop surrounded by text lines retains surrounding text and blank separators between items' {
            # Each iteration: \n  - N\n, plus the \n from endfor before "after"
            OraRender -Template "before`n{% for i in items %}`n  - {{ i }}`n{% endfor %}`nafter" `
                       -Context @{ items = @(1, 2) } |
                Should -Be "before`n`n  - 1`n`n  - 2`n`nafter"
        }
    }

    # -------------------------------------------------------------------------
    Context 'Raw blocks — content passed through verbatim, surrounding LFs stay' {
        # {% raw %}...{% endraw %} passes its content through unchanged.
        # The block tags themselves follow the same newline rules as other tags.

        It 'a raw block with no surrounding newlines outputs only the raw content' {
            OraRender -Template '{% raw %}{{ not_a_var }}{% endraw %}' |
                Should -Be '{{ not_a_var }}'
        }

        It 'a raw block followed by a trailing LF retains the trailing LF' {
            OraRender -Template "{% raw %}{{ not_a_var }}{% endraw %}`n" |
                Should -Be "{{ not_a_var }}`n"
        }

        It 'a raw block whose content spans multiple lines preserves all internal newlines' {
            OraRender -Template "{% raw %}`nline1`nline2`n{% endraw %}" |
                Should -Be "`nline1`nline2`n"
        }

        It 'raw block content that looks like a Jinja2 block tag is output literally' {
            OraRender -Template '{% raw %}{% for x in y %}{% endraw %}' |
                Should -Be '{% for x in y %}'
        }
    }

    # -------------------------------------------------------------------------
    Context 'Newline normalisation — CRLF input is normalised to LF in output' {
        # Jinja2 normalises line endings on all platforms.
        # Oracle sets newline_sequence="\n" so output is always LF-only.

        It 'CRLF at the end of a plain-text line is normalised to a plain LF in the output' {
            # Input: "hello\r\n"  ->  Output: "hello\n"
            OraRender -Template "hello`r`n" | Should -Be "hello`n"
        }

        It 'CRLF throughout a multi-line template is normalised to LF throughout the output' {
            # Input: "\r\nhello\r\n"  ->  Output: "\nhello\n"
            OraRender -Template "`r`nhello`r`n" | Should -Be "`nhello`n"
        }
    }
}
