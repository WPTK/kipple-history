#requires -Version 7
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Pester tests for scrub-check.ps1. Fixtures and fake terms only, never real terms.
.DESCRIPTION
    Run: pwsh -Command "Invoke-Pester scripts/scrub-check.Tests.ps1 -Output Detailed"
    Each test follows Arrange, Act, Assert and its name states the intended behavior.
#>
BeforeAll {
    $script:Check = Join-Path $PSScriptRoot 'scrub-check.ps1'
    $script:Dir = Join-Path ([System.IO.Path]::GetTempPath()) ('scrubtest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:Dir | Out-Null

    # Fake terms file: line 2 is a literal, line 3 is an invalid regex.
    $script:Terms = Join-Path $script:Dir 'terms.txt'
    Set-Content -LiteralPath $script:Terms -Value @('# fake terms', 'example-secret-host', '[unclosed')

    function script:Invoke-Check {
        param([string]$Text, [string]$TermsFile = $script:Terms)
        $fixture = Join-Path $script:Dir 'fixture.md'
        Set-Content -LiteralPath $fixture -Value $Text -NoNewline
        $output = & pwsh -NoProfile -File $script:Check -Path $fixture -TermsFile $TermsFile 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:Dir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Generic rules' {
    It 'fails and names the rule when the text contains <Case>' -ForEach @(
        @{ Case = 'an em dash'; Rule = 'generic:dash'; Text = "a $([char]0x2014) b" }
        @{ Case = 'an en dash'; Rule = 'generic:dash'; Text = "a $([char]0x2013) b" }
        @{ Case = 'a public IPv4 address'; Rule = 'generic:ipv4'; Text = 'host at 8.8.' + '4.4 here' }
        @{ Case = 'an email address'; Rule = 'generic:email'; Text = 'mail someone@' + 'corp.test now' }
        @{ Case = 'a reader app name in any case'; Rule = 'generic:reader-app'; Text = 'uses netnews' + 'wire daily' }
    ) {
        # Arrange: the fixture text comes from the case. Act:
        $result = Invoke-Check -Text $Text
        # Assert:
        $result.Code | Should -Be 1
        $result.Output | Should -Match "fixture.md:1: rule $Rule"
    }

    It 'allows loopback, documentation addresses and example email domains' {
        $result = Invoke-Check -Text '127.0.0.1 and 203.0.113.9 and a@example.com'
        $result.Code | Should -Be 0
    }

    It 'passes clean text' {
        $result = Invoke-Check -Text 'plain text only'
        $result.Code | Should -Be 0
        $result.Output | Should -Match 'scrub-check: clean'
    }
}

Describe 'Owner terms file' {
    It 'fails on an owner term but never prints the term' {
        $result = Invoke-Check -Text 'see Example-Secret-Host today'
        $result.Code | Should -Be 1
        $result.Output | Should -Match 'rule owner-term:line2'
        $result.Output | Should -Not -Match 'secret'
    }

    It 'reports an invalid regex by line number without crashing or printing it' {
        $result = Invoke-Check -Text 'clean'
        $result.Output | Should -Match 'line 3'
        $result.Output | Should -Not -Match 'unclosed'
    }

    It 'still runs the generic rules and warns when the terms file is missing' {
        $missing = Join-Path $script:Dir 'absent.txt'
        $result = Invoke-Check -Text ('a@' + 'corp.test') -TermsFile $missing
        $result.Code | Should -Be 1
        $result.Output | Should -Match 'NOT loaded'
        $result.Output | Should -Match 'generic:email'
    }
}

Describe 'Environment errors' {
    It 'exits 2 and names the problem when an input file does not exist' {
        $missing = Join-Path $script:Dir 'nope.md'
        $output = & pwsh -NoProfile -File $script:Check -Path $missing -TermsFile $script:Terms 2>&1 | ForEach-Object { "$_" }
        $LASTEXITCODE | Should -Be 2
        ($output -join "`n") | Should -Match 'does not exist'
    }
}

Describe 'Staged mode' {
    It 'finds an em dash in an added line of a staged file' {
        # Arrange: a throwaway repository with one staged file.
        $repo = Join-Path $script:Dir 'repo'
        New-Item -ItemType Directory -Path $repo | Out-Null
        Push-Location $repo
        try {
            & git init -q
            Set-Content -LiteralPath 'note.md' -Value "ok`na $([char]0x2014) b" -Encoding utf8
            & git add note.md
            # Act:
            $output = & pwsh -NoProfile -File $script:Check -Staged -TermsFile $script:Terms 2>&1 | ForEach-Object { "$_" }
            $code = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        # Assert:
        $code | Should -Be 1
        ($output -join "`n") | Should -Match 'note.md:2: rule generic:dash'
    }
}
