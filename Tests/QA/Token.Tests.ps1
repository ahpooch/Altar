# Invoke-Pester -Path .\Tests\QA\Token.Tests.ps1 -Output Detailed
BeforeAll {
    . .\Altar.ps1
}

Describe 'Token Class' -Tag 'CI' {
    Context 'Constructor and properties' {
        It 'Correctly initializes all properties' {
            # Prepare test data
            $expectedType = [TokenType]::IDENTIFIER
            $expectedValue = 'testVar'
            $expectedLine = 10
            $expectedColumn = 5
            $expectedFilename = 'script.ps1'

            # Create class instance
            $token = [Token]::new($expectedType, $expectedValue, $expectedLine, $expectedColumn, $expectedFilename)

            # Assertions
            $token.Type | Should -Be $expectedType
            $token.Value | Should -Be $expectedValue
            $token.Line | Should -Be $expectedLine
            $token.Column | Should -Be $expectedColumn
            $token.Filename | Should -Be $expectedFilename
        }
    }

    Context 'ToString Method' {
        It 'Formats string with correct details' {
            # Setup
            $token = [Token]::new([TokenType]::String, 'Hello World', 1, 2, 'test.ps1')
            $expectedString = "Token(String, 'Hello World', line=1, col=2)"

            # Action and assertion
            $token.ToString() | Should -Be $expectedString
        }
    }

    Context 'Handling different token types and values' -Tag 'CI' {
        It "Creates token of type '<TokenType>' with value '<InputValue>'" -TestCases @(
            @{ TokenType = [TokenType]::Number; InputValue = '42' }
            @{ TokenType = [TokenType]::Operator; InputValue = '+' }
            @{ TokenType = [TokenType]::String; InputValue = ''; Description = 'Empty string' }
            @{ TokenType = [TokenType]::Identifier; InputValue = 'veryLongVariableName' }
        ) {
            param($TokenType, $InputValue)
            $token = [Token]::new($TokenType, $InputValue, 1, 1, 'test.ps1')
            $token.Type | Should -Be $TokenType
            $token.Value | Should -Be $InputValue
        }
    }
}

