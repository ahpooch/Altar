# Integration tests for 'is' operator tests — enhanced with Jinja2 Oracle validation

BeforeAll {
    . "$PSScriptRoot/../../Altar.ps1"
    . "$PSScriptRoot/../Helpers/OracleClient.ps1"

    Mock Get-AltarEnvironmentVariable { return $null }

    $script:OracleAvailable = $false
    $script:OracleProcess   = $null

    try {
        $script:OracleProcess   = Start-OracleService -TimeoutSeconds 20
        $script:OracleAvailable = $true
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

Describe "Is Operator - Basic Tests" {
    It "Should test 'defined' - variable is defined" {
        $template = "{% if name is defined %}defined{% else %}not defined{% endif %}"
        $context = @{ name = "John" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "defined"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'defined' - variable is not defined" {
        $template = "{% if name is defined %}defined{% else %}not defined{% endif %}"
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not defined"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'undefined' - variable is undefined" {
        $template = "{% if name is undefined %}undefined{% else %}defined{% endif %}"
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "undefined"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'undefined' - variable is defined" {
        $template = "{% if name is undefined %}undefined{% else %}defined{% endif %}"
        $context = @{ name = "John" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "defined"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'none' - value is null" {
        $template = "{% if value is none %}null{% else %}not null{% endif %}"
        $context = @{ value = $null }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "null"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'none' - value is not null" {
        $template = "{% if value is none %}null{% else %}not null{% endif %}"
        $context = @{ value = 42 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not null"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}

Describe "Is Operator - Numeric Tests" {
    It "Should test 'even' - number is even" {
        $template = "{% if num is even %}even{% else %}odd{% endif %}"
        $context = @{ num = 4 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "even"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'even' - number is odd" {
        $template = "{% if num is even %}even{% else %}odd{% endif %}"
        $context = @{ num = 5 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "odd"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'odd' - number is odd" {
        $template = "{% if num is odd %}odd{% else %}even{% endif %}"
        $context = @{ num = 7 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "odd"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'odd' - number is even" {
        $template = "{% if num is odd %}odd{% else %}even{% endif %}"
        $context = @{ num = 8 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "even"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'divisibleby' - number is divisible" {
        $template = "{% if num is divisibleby(3) %}divisible{% else %}not divisible{% endif %}"
        $context = @{ num = 9 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "divisible"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'divisibleby' - number is not divisible" {
        $template = "{% if num is divisibleby(3) %}divisible{% else %}not divisible{% endif %}"
        $context = @{ num = 10 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not divisible"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}

Describe "Is Operator - Type Tests" {
    It "Should test 'number' - value is a number" {
        $template = "{% if value is number %}number{% else %}not number{% endif %}"
        $context = @{ value = 42 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "number"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'number' - value is not a number" {
        $template = "{% if value is number %}number{% else %}not number{% endif %}"
        $context = @{ value = "text" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not number"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'string' - value is a string" {
        $template = "{% if value is string %}string{% else %}not string{% endif %}"
        $context = @{ value = "hello" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "string"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'string' - value is not a string" {
        $template = "{% if value is string %}string{% else %}not string{% endif %}"
        $context = @{ value = 123 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not string"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'iterable' - value is iterable (array)" {
        $template = "{% if value is iterable %}iterable{% else %}not iterable{% endif %}"
        $context = @{ value = @(1, 2, 3) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "iterable"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'iterable' - value is not iterable (number)" {
        $template = "{% if value is iterable %}iterable{% else %}not iterable{% endif %}"
        $context = @{ value = 42 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not iterable"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'mapping' - value is a mapping (hashtable)" {
        $template = "{% if value is mapping %}mapping{% else %}not mapping{% endif %}"
        $context = @{ value = @{ key = "value" } }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "mapping"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'mapping' - value is not a mapping" {
        $template = "{% if value is mapping %}mapping{% else %}not mapping{% endif %}"
        $context = @{ value = @(1, 2, 3) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not mapping"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'sequence' - value is a sequence (array)" {
        $template = "{% if value is sequence %}sequence{% else %}not sequence{% endif %}"
        $context = @{ value = @(1, 2, 3) }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "sequence"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'sequence' - value is a sequence (string)" {
        $template = "{% if value is sequence %}sequence{% else %}not sequence{% endif %}"
        $context = @{ value = "hello" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "sequence"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}

Describe "Is Operator - String Case Tests" {
    It "Should test 'lower' - string is lowercase" {
        $template = "{% if text is lower %}lowercase{% else %}not lowercase{% endif %}"
        $context = @{ text = "hello" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "lowercase"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'lower' - string is not lowercase" {
        $template = "{% if text is lower %}lowercase{% else %}not lowercase{% endif %}"
        $context = @{ text = "Hello" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not lowercase"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'upper' - string is uppercase" {
        $template = "{% if text is upper %}uppercase{% else %}not uppercase{% endif %}"
        $context = @{ text = "HELLO" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "uppercase"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }

    It "Should test 'upper' - string is not uppercase" {
        $template = "{% if text is upper %}uppercase{% else %}not uppercase{% endif %}"
        $context = @{ text = "Hello" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not uppercase"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}

Describe "Is Operator - New Tests (callable, equalto, escaped)" {
    It "Should test 'callable' - scriptblock is callable" {
        $template = "{% if func is callable %}callable{% else %}not callable{% endif %}"
        $context = @{ func = { Write-Output "test" } }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "callable"
    }

    It "Should test 'callable' - string is not callable" {
        $template = "{% if func is callable %}callable{% else %}not callable{% endif %}"
        $context = @{ func = "not a function" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not callable"
    }

    It "Should test 'equalto' - values are equal" {
        $template = "{% if num is equalto(42) %}equal{% else %}not equal{% endif %}"
        $context = @{ num = 42 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "equal"
    }

    It "Should test 'equalto' - values are not equal" {
        $template = "{% if num is equalto(42) %}equal{% else %}not equal{% endif %}"
        $context = @{ num = 43 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not equal"
    }

    It "Should test 'escaped' - string is HTML-escaped" {
        $template = "{% if text is escaped %}escaped{% else %}not escaped{% endif %}"
        $context = @{ text = "&lt;div&gt;" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "escaped"
    }

    It "Should test 'escaped' - string is not HTML-escaped" {
        $template = "{% if text is escaped %}escaped{% else %}not escaped{% endif %}"
        $context = @{ text = "<div>" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not escaped"
    }
}

Describe "Is Operator - Negation Tests" {
    It "Should test 'is not defined' - variable is not defined" {
        $template = "{% if name is not defined %}not defined{% else %}defined{% endif %}"
        $context = @{}
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not defined"
    }

    It "Should test 'is not even' - number is odd" {
        $template = "{% if num is not even %}odd{% else %}even{% endif %}"
        $context = @{ num = 5 }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "odd"
    }

    It "Should test 'is not number' - value is not a number" {
        $template = "{% if value is not number %}not number{% else %}number{% endif %}"
        $context = @{ value = "text" }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "not number"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}

Describe "Is Operator - sameas Test" {
    It "Should test 'sameas' - same object reference" {
        $obj = @{ key = "value" }
        $template = "{% if obj1 is sameas(obj2) %}same{% else %}different{% endif %}"
        $context = @{ obj1 = $obj; obj2 = $obj }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "same"
        # NOTE: Oracle comparison intentionally omitted — object identity cannot
        # survive JSON serialisation. The Oracle deserialises both fields as two
        # separate dict objects, so its 'sameas' (Python 'is') always returns
        # False here, giving "different". Altar's [object]::ReferenceEquals is
        # the correct implementation per the Jinja2 spec for this scenario.
    }

    It "Should test 'sameas' - different object references" {
        $template = "{% if obj1 is sameas(obj2) %}same{% else %}different{% endif %}"
        $context = @{ obj1 = @{ key = "value" }; obj2 = @{ key = "value" } }
        $result = Invoke-AltarTemplate -Template $template -Context $context
        $result | Should -Be "different"
        Confirm-MatchesOracle -Template $template -Context $context -AltarResult $result
    }
}
