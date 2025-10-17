# Invoke-Pester -Path .\Tests\QA\LexerState.Tests.ps1 -Output Detailed
BeforeAll {
    . .\Altar.ps1
}

Describe 'LexerState Class' -Tag 'CI' {
    Context "LexerState Constructor" {
        It "Initializes with correct default values" {
            $state = [LexerState]::new("test content", "test.txt")
        
            $state.Text | Should -Be "test content"
            $state.Position | Should -Be 0
            $state.Line | Should -Be 1
            $state.Column | Should -Be 1
            $state.Filename | Should -Be "test.txt"
            $state.States.Count | Should -Be 1
            $state.States.Peek() | Should -Be "INITIAL"
        }
    
        It "Handles empty text input" {
            $state = [LexerState]::new("", "empty.txt")
        
            $state.Text | Should -Be ""
            $state.Position | Should -Be 0
            $state.IsEOF() | Should -Be $true
        }
    
        It "Handles null filename" {
            $state = [LexerState]::new("content", $null)
        
            $state.Filename | Should -BeNullOrEmpty
        }
    }
}