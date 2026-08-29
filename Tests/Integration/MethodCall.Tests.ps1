# Integration tests for .NET instance method call syntax (e.g., "hello".ToUpper())
# This is an Altar-specific extension enabling dot-notation method calls on .NET objects.
# These tests do NOT use Confirm-MatchesOracle because Jinja2 exposes Python string methods
# (e.g., .ljust()) while Altar exposes .NET methods (e.g., .PadRight()) - the semantics
# are equivalent but the method names differ between the two runtimes.

BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    Mock Get-AltarEnvironmentVariable { return $null }
}

Describe ".NET Method Call Integration Tests" -Tag "Integration" {

    Context "String padding methods" {
        It "PadRight should left-justify text (replaces ljust)" {
            $template = '{{ "test".PadRight(10) }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "test      "
        }

        It "PadLeft should right-justify text (replaces rjust)" {
            $template = '{{ "test".PadLeft(10) }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "      test"
        }

        It "PadRight with custom char should pad with fill character" {
            $template = '{{ "test".PadRight(10, "*") }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "test******"
        }

        It "PadLeft with custom char should pad with fill character" {
            $template = '{{ "test".PadLeft(10, "0") }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "000000test"
        }

        It "PadRight on string shorter than width should not truncate" {
            $template = '{{ "hi".PadRight(2) }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "hi"
        }
    }

    Context "String case methods" {
        It "ToUpper should convert string to uppercase" {
            $template = '{{ "hello".ToUpper() }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "HELLO"
        }

        It "ToLower should convert string to lowercase" {
            $template = '{{ "HELLO".ToLower() }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "hello"
        }
    }

    Context "String trimming methods" {
        It "Trim should remove leading and trailing whitespace" {
            $template = '{{ "  hello  ".Trim() }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "hello"
        }

        It "TrimStart should remove leading whitespace only" {
            $template = '{{ "  hello  ".TrimStart() }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "hello  "
        }

        It "TrimEnd should remove trailing whitespace only" {
            $template = '{{ "  hello  ".TrimEnd() }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "  hello"
        }
    }

    Context "String search and replace methods" {
        It "Replace should substitute substrings" {
            $template = '{{ "hello world".Replace("world", "Altar") }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "hello Altar"
        }

        It "Contains should return true when substring exists" {
            $template = '{{ "hello world".Contains("world") }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "True"
        }

        It "StartsWith should return true when string starts with prefix" {
            $template = '{{ "hello".StartsWith("he") }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "True"
        }

        It "EndsWith should return true when string ends with suffix" {
            $template = '{{ "hello".EndsWith("lo") }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "True"
        }

        It "IndexOf should return position of first occurrence" {
            $template = '{{ "hello".IndexOf("l") }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "2"
        }
    }

    Context "String extraction methods" {
        It "Substring with start index should return suffix" {
            $template = '{{ "hello world".Substring(6) }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "world"
        }

        It "Substring with start and length should return slice" {
            $template = '{{ "hello world".Substring(0, 5) }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "hello"
        }
    }

    Context "Method calls on context variables" {
        It "ToUpper on a context variable should work" {
            $template = '{{ name.ToUpper() }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{ name = "altar" }
            $result | Should -Be "ALTAR"
        }

        It "PadRight on a context variable should work" {
            $template = '{{ label.PadRight(10) }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{ label = "hi" }
            $result | Should -Be "hi        "
        }

        It "Replace on a context variable should work" {
            $template = '{{ greeting.Replace("World", "Altar") }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{ greeting = "Hello, World!" }
            $result | Should -Be "Hello, Altar!"
        }
    }

    Context "Method call chaining" {
        It "Two chained method calls should apply left to right" {
            $template = '{{ "  hello  ".Trim().ToUpper() }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "HELLO"
        }

        It "Three chained method calls should apply left to right" {
            $template = '{{ "  hello world  ".Trim().Replace("world", "altar").ToUpper() }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "HELLO ALTAR"
        }
    }

    Context "Method call combined with filters" {
        It "Method result can be piped into a filter" {
            $template = '{{ "hello".ToUpper() | lower }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "hello"
        }

        It "Chained methods on a variable combined with a filter" {
            $template = '{{ name.ToUpper().PadRight(10) | trim }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{ name = "hi" }
            $result | Should -Be "HI"
        }
    }

    Context "Integer methods" {
        It "ToString on a parenthesized integer literal should convert to string" {
            $template = '{{ (42).ToString() }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "42"
        }
    }

    Context "Property access unchanged" {
        It "Property access without parentheses still works" {
            $template = '{{ "hello".Length }}'
            $result   = Invoke-AltarTemplate -Template $template -Context @{}
            $result | Should -Be "5"
        }
    }
}