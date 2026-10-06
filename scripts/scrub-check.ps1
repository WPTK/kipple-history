#requires -Version 7
<#
.SYNOPSIS
    Deterministic scrub check: finds text that must not be published.

.DESCRIPTION
    Three modes:
      -Staged  (default) lines added in `git diff --cached`
      -All     every tracked text file
      -Path    the given files (used by the tests)

    Generic rules built in below (see Get-GenericRule): em and en dashes, IPv4
    addresses (except 127.0.0.1, 0.0.0.0 and the documentation ranges), email
    addresses (except example domains) and named reader apps.

    Owner-specific terms come from an untracked file, .scrub-terms.local at the
    repository root (override with -TermsFile): one literal term or regex per
    line, '#' starts a comment. If it is missing, the generic rules still run
    and a warning says the owner terms are not loaded.

    Output is one line per hit, "file:line: rule name". The matched text and the
    text of owner terms are never printed. Owner rules are named after their line
    number in the terms file. Use -Verbose for a step-by-step trace.

    Exit codes: 0 clean, 1 at least one hit, 2 usage or environment error.

.PARAMETER Staged
    Scan lines added in the staged diff. This is the default.

.PARAMETER All
    Scan every tracked text file.

.PARAMETER Path
    Scan these files instead of asking git.

.PARAMETER TermsFile
    Alternative path for the owner terms file.

.EXAMPLE
    pwsh scripts/scrub-check.ps1 -All -Verbose
#>
[CmdletBinding(DefaultParameterSetName = 'Staged')]
param(
    [Parameter(ParameterSetName = 'Staged')]
    [switch]$Staged,

    [Parameter(Mandatory, ParameterSetName = 'All')]
    [switch]$All,

    [Parameter(Mandatory, ParameterSetName = 'Path')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Path,

    [ValidateNotNullOrEmpty()]
    [string]$TermsFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    <#
    .SYNOPSIS
        Returns the top-level directory of the current git repository.
    #>
    [CmdletBinding()]
    param()
    $top = & git rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0) {
        throw 'Step "find repository": not inside a git repository. Run the script from a clone of this repository.'
    }
    return ([string]$top).Trim()
}

function ConvertTo-ScrubRule {
    <#
    .SYNOPSIS
        Builds one rule object. Kind 'ip' gets the extra allow-list check.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][regex]$Pattern,
        [ValidateSet('plain', 'ip')][string]$Kind = 'plain'
    )
    return [pscustomobject]@{ Name = $Name; Pattern = $Pattern; Kind = $Kind }
}

function Get-GenericRule {
    <#
    .SYNOPSIS
        The built-in rules that apply to everyone. To add a generic rule, add
        one ConvertTo-ScrubRule line here and a test case in scrub-check.Tests.ps1.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()
    $options = [System.Text.RegularExpressions.RegexOptions]
    $compiled = $options::Compiled
    $ignoreCase = $options::IgnoreCase -bor $options::Compiled

    # Dash characters are built from code points so this file stays plain ASCII.
    $emDash = [char]0x2014
    $enDash = [char]0x2013
    $dashPattern = "[$emDash$enDash]"
    $ipPattern = '(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])'
    $emailPattern = '[A-Za-z0-9._%+-]+@(?!example\.)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+'
    $readerPattern = 'Reed' + 'er|NetNews' + 'Wire'

    return @(
        ConvertTo-ScrubRule -Name 'generic:dash' -Pattern ([regex]::new($dashPattern, $compiled))
        ConvertTo-ScrubRule -Name 'generic:ipv4' -Pattern ([regex]::new($ipPattern, $compiled)) -Kind 'ip'
        ConvertTo-ScrubRule -Name 'generic:email' -Pattern ([regex]::new($emailPattern, $compiled))
        ConvertTo-ScrubRule -Name 'generic:reader-app' -Pattern ([regex]::new($readerPattern, $ignoreCase))
    )
}

function Read-OwnerRule {
    <#
    .SYNOPSIS
        Reads the untracked terms file into rules. Never prints a term.
    .DESCRIPTION
        An invalid regex is reported by line number and then matched as a literal
        string, so the script keeps running and the term still protects.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory)][string]$TermsPath)

    $rules = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path -LiteralPath $TermsPath -PathType Leaf)) {
        Write-Warning 'Owner terms file not found: owner terms are NOT loaded, only the generic rules run. Create .scrub-terms.local at the repository root (see the README).'
        return $rules.ToArray()
    }

    $options = [System.Text.RegularExpressions.RegexOptions]
    $ignoreCase = $options::IgnoreCase -bor $options::Compiled
    $lineNumber = 0
    foreach ($line in [System.IO.File]::ReadLines($TermsPath)) {
        $lineNumber++
        $term = $line.Trim()
        if ($term -eq '' -or $term.StartsWith('#')) { continue }
        try {
            $pattern = [regex]::new($term, $ignoreCase)
        } catch {
            Write-Warning "Terms file line ${lineNumber}: not a valid regex, matching it as a literal string. Fix the line to remove this warning."
            $pattern = [regex]::new([regex]::Escape($term), $ignoreCase)
        }
        $rules.Add((ConvertTo-ScrubRule -Name "owner-term:line$lineNumber" -Pattern $pattern))
    }
    Write-Verbose "Loaded $($rules.Count) owner rule(s) from the terms file."
    return $rules.ToArray()
}

function Test-PublicIpv4 {
    <#
    .SYNOPSIS
        True when the text holds an IPv4 address that is not on the allow-list.
    .DESCRIPTION
        Allowed: 127.0.0.1, 0.0.0.0, and the documentation ranges 192.0.2.x,
        198.51.100.x and 203.0.113.x. Dotted numbers with an octet over 255
        (version strings and similar) are ignored.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][regex]$Pattern,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    $documentationRange = '^(192\.0\.2|198\.51\.100|203\.0\.113)\.'
    foreach ($match in $Pattern.Matches($Text)) {
        $address = $match.Value
        $largest = ($address.Split('.') | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum
        if ($largest -gt 255) { continue }
        if ($address -eq '127.0.0.1' -or $address -eq '0.0.0.0') { continue }
        if ($address -match $documentationRange) { continue }
        return $true
    }
    return $false
}

function Find-RuleHit {
    <#
    .SYNOPSIS
        Checks one line against every rule and returns "file:line: rule name"
        strings. Returns nothing when the line is clean.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][object[]]$Rules,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][int]$LineNumber,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    foreach ($rule in $Rules) {
        if ($rule.Kind -eq 'ip') {
            $isHit = Test-PublicIpv4 -Pattern $rule.Pattern -Text $Text
        } else {
            $isHit = $rule.Pattern.IsMatch($Text)
        }
        if ($isHit) { '{0}:{1}: rule {2}' -f $File, $LineNumber, $rule.Name }
    }
}

function Get-StagedHit {
    <#
    .SYNOPSIS
        Scans only the lines added in `git diff --cached`.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][object[]]$Rules)

    Write-Verbose 'Reading the staged diff.'
    # git emits UTF-8; without this the dash characters are decoded as ANSI and missed.
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $diff = & git -c core.quotepath=off diff --cached -U0 --no-color --diff-filter=ACMR
    if ($LASTEXITCODE -ne 0) {
        throw 'Step "read staged diff": git diff --cached failed. Check that git works in this repository.'
    }
    $file = $null
    $lineNumber = 0
    foreach ($line in $diff) {
        if ($line -match '^\+\+\+ b/(.*)$') { $file = $Matches[1]; continue }
        if ($line.StartsWith('+++ ')) { $file = $null; continue }
        if ($line -match '^@@ -\S+ \+(\d+)') { $lineNumber = [int]$Matches[1]; continue }
        if ($line.StartsWith('+') -and $null -ne $file) {
            Find-RuleHit -Rules $Rules -File $file -LineNumber $lineNumber -Text $line.Substring(1)
            $lineNumber++
        }
    }
}

function Get-TrackedTextFile {
    <#
    .SYNOPSIS
        Lists tracked files that are plain text, by extension.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()
    $textExtension = '\.(md|txt|json|ya?ml|ps1|sh|csv|toml|html|css|js|ts)$'
    $tracked = & git ls-files
    if ($LASTEXITCODE -ne 0) {
        throw 'Step "list tracked files": git ls-files failed. Check that git works in this repository.'
    }
    return @($tracked | Where-Object { $_ -match $textExtension -or $_ -match '(^|/)(\.gitignore|pre-commit)$' })
}

function Get-FileHit {
    <#
    .SYNOPSIS
        Scans whole files line by line. Relative paths resolve against Root.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][object[]]$Rules,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$File
    )
    foreach ($name in $File) {
        $fullPath = if ([System.IO.Path]::IsPathRooted($name)) { $name } else { Join-Path $Root $name }
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw "Step ""read file"": '$name' does not exist. Check the path you passed."
        }
        Write-Verbose "Scanning $name"
        $lineNumber = 0
        foreach ($line in [System.IO.File]::ReadLines($fullPath)) {
            $lineNumber++
            Find-RuleHit -Rules $Rules -File $name -LineNumber $lineNumber -Text $line
        }
    }
}

function Invoke-ScrubCheck {
    <#
    .SYNOPSIS
        Runs the selected mode. Returns an object with ExitCode (0, 1 or 2) and
        Lines (the text to print). Printing is left to the caller so the exit
        code is never mixed into the output stream.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][ValidateSet('Staged', 'All', 'Path')][string]$Mode,
        [string[]]$InputPath,
        [string]$TermsPath
    )
    try {
        $root = Get-RepoRoot
        if (-not $TermsPath) { $TermsPath = Join-Path $root '.scrub-terms.local' }
        $rules = @(Get-GenericRule) + @(Read-OwnerRule -TermsPath $TermsPath)
        Write-Verbose "Mode: $Mode; $($rules.Count) rule(s) active."

        $findings = switch ($Mode) {
            'All' { Get-FileHit -Rules $rules -Root $root -File (Get-TrackedTextFile) }
            'Path' { Get-FileHit -Rules $rules -Root $root -File $InputPath }
            default { Get-StagedHit -Rules $rules }
        }
    } catch {
        [Console]::Error.WriteLine("scrub-check: $($_.Exception.Message)")
        return [pscustomobject]@{ ExitCode = 2; Lines = @() }
    }

    $findings = @($findings)
    if ($findings.Count -gt 0) {
        $summary = "scrub-check: $($findings.Count) hit(s). Matched text is not printed; open the line to see it."
        return [pscustomobject]@{ ExitCode = 1; Lines = $findings + $summary }
    }
    return [pscustomobject]@{ ExitCode = 0; Lines = @('scrub-check: clean.') }
}

$mode = if ($All) { 'All' } elseif ($Path) { 'Path' } else { 'Staged' }
Write-Verbose "Staged switch given: $Staged"
$result = Invoke-ScrubCheck -Mode $mode -InputPath $Path -TermsPath $TermsFile
$result.Lines | Write-Output
exit $result.ExitCode
