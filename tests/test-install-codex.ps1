$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ScriptPath = Join-Path $RepositoryRoot "scripts/install-codex.ps1"
$PowerShellPath = (Get-Command pwsh -ErrorAction Stop).Source
$OpcSource = Join-Path $RepositoryRoot "adapters/codex/opc-skills"
$ZxSource = Join-Path $RepositoryRoot "adapters/codex/zx-skills"
$SuiteRoot = Join-Path ([IO.Path]::GetTempPath()) ("opcskills-installer-" + [guid]::NewGuid().ToString("N"))
$OriginalHomeEnvironment = $env:HOME
$OriginalPowerShellHome = $HOME
$IsNativeWindows = $env:OS -eq "Windows_NT"

function Fail-Test {
    param([string]$Message)
    throw "FAIL: $Message"
}

function New-CaseContext {
    param([string]$Name)

    $Root = Join-Path $SuiteRoot $Name
    $HomePath = Join-Path $Root "home"
    [IO.Directory]::CreateDirectory($HomePath) | Out-Null
    return [pscustomobject]@{
        Root = $Root
        Home = $HomePath
        Skills = Join-Path $Root "skills"
    }
}

function Invoke-TestProcess {
    param(
        [string[]]$Arguments,
        [pscustomobject]$Context,
        [ValidateSet("Override", "Fallback")][string]$SkillsHomeMode = "Override"
    )

    $StartInfo = [Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $PowerShellPath
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    foreach ($Argument in $Arguments) {
        $StartInfo.ArgumentList.Add($Argument)
    }
    $StartInfo.Environment["HOME"] = $Context.Home
    $StartInfo.Environment["USERPROFILE"] = $Context.Home
    if ($SkillsHomeMode -eq "Fallback") {
        $StartInfo.Environment.Remove("OPCSKILLS_SKILLS_HOME") | Out-Null
    }
    else {
        $StartInfo.Environment["OPCSKILLS_SKILLS_HOME"] = $Context.Skills
    }

    $Process = [Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo
    $Process.Start() | Out-Null
    $StdOutTask = $Process.StandardOutput.ReadToEndAsync()
    $StdErrTask = $Process.StandardError.ReadToEndAsync()
    $Process.WaitForExit()
    return [pscustomobject]@{
        ExitCode = $Process.ExitCode
        StdOut = $StdOutTask.GetAwaiter().GetResult()
        StdErr = $StdErrTask.GetAwaiter().GetResult()
    }
}

function Invoke-Installer {
    param(
        [pscustomobject]$Context,
        [ValidateSet("install", "status", "uninstall")][string]$Action,
        [switch]$Fallback
    )

    $Mode = if ($Fallback) { "Fallback" } else { "Override" }
    return Invoke-TestProcess @("-NoProfile", "-File", $ScriptPath, $Action) $Context $Mode
}

function Assert-ExitCode {
    param([pscustomobject]$Result, [int]$Expected, [string]$Operation)
    if ($Result.ExitCode -ne $Expected) {
        Fail-Test "$Operation exited with $($Result.ExitCode), expected $Expected. stderr: $($Result.StdErr)"
    }
}

function Assert-Nonzero {
    param([pscustomobject]$Result, [string]$Operation)
    if ($Result.ExitCode -eq 0) {
        Fail-Test "$Operation unexpectedly succeeded"
    }
}

function Get-RawLinkTarget {
    param([string]$Path)
    $Target = (Get-Item -LiteralPath $Path -Force).Target
    if ($Target -is [array]) {
        return [string]$Target[0]
    }
    return [string]$Target
}

function Assert-CurrentLink {
    param([string]$Path, [string]$ExpectedSource)

    $Item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $Item -or -not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Fail-Test "$Path is not a link"
    }
    $LinkTarget = Get-RawLinkTarget $Path
    if (-not [IO.Path]::IsPathRooted($LinkTarget)) {
        $LinkTarget = Join-Path (Split-Path -Parent $Path) $LinkTarget
    }
    $Actual = (Resolve-Path -LiteralPath $LinkTarget).Path.TrimEnd("\", "/")
    $Expected = (Resolve-Path -LiteralPath $ExpectedSource).Path.TrimEnd("\", "/")
    if ($Actual -ne $Expected) {
        Fail-Test "$Path resolves to $Actual, expected $Expected"
    }
}

function Assert-Absent {
    param([string]$Path)
    if ($null -ne (Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue)) {
        Fail-Test "$Path should be absent"
    }
}

function Assert-Status {
    param(
        [pscustomobject]$Result,
        [string]$OpcState,
        [string]$ZxState,
        [int]$ExpectedExit
    )

    Assert-ExitCode $Result $ExpectedExit "status"
    $Lines = @($Result.StdOut.TrimEnd() -split "`r?`n")
    if ($Lines.Count -ne 2) {
        Fail-Test "status printed $($Lines.Count) lines, expected 2"
    }
    if ($Lines[0] -notmatch "^opc-skills: $OpcState " -or
        $Lines[1] -notmatch "^zx-skills: $ZxState ") {
        Fail-Test "unexpected status output: $($Result.StdOut)"
    }
}

function Get-RelativeTarget {
    param([string]$Parent, [string]$Source)
    $Value = & python3 -c 'import os,sys; print(os.path.relpath(os.path.realpath(sys.argv[2]), os.path.realpath(sys.argv[1])))' $Parent $Source
    if ($LASTEXITCODE -ne 0) {
        Fail-Test "could not compute relative link target"
    }
    return [string]$Value
}

function New-CurrentLink {
    param(
        [string]$Path,
        [string]$Source,
        [switch]$Relative
    )

    $Parent = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($Parent) | Out-Null
    $LinkType = if ($IsNativeWindows) { "Junction" } else { "SymbolicLink" }
    $Target = if ($Relative -and -not $IsNativeWindows) {
        Get-RelativeTarget $Parent $Source
    }
    else {
        $Source
    }
    Microsoft.PowerShell.Management\New-Item -ItemType $LinkType -Path $Path -Target $Target | Out-Null
}

function Test-FreshLifecycle {
    $Context = New-CaseContext "fresh"
    $Install = Invoke-Installer $Context install
    Assert-ExitCode $Install 0 "fresh install"
    Assert-CurrentLink (Join-Path $Context.Skills "opc-skills") $OpcSource
    Assert-CurrentLink (Join-Path $Context.Skills "zx-skills") $ZxSource
    Assert-Status (Invoke-Installer $Context status) current current 0

    $OpcPath = Join-Path $Context.Skills "opc-skills"
    $ZxPath = Join-Path $Context.Skills "zx-skills"
    $OpcRaw = Get-RawLinkTarget $OpcPath
    $ZxRaw = Get-RawLinkTarget $ZxPath
    $Reinstall = Invoke-Installer $Context install
    Assert-ExitCode $Reinstall 0 "idempotent install"
    if ((Get-RawLinkTarget $OpcPath) -ne $OpcRaw -or (Get-RawLinkTarget $ZxPath) -ne $ZxRaw) {
        Fail-Test "idempotent install replaced a current entry"
    }

    $Uninstall = Invoke-Installer $Context uninstall
    Assert-ExitCode $Uninstall 0 "uninstall"
    Assert-Absent $OpcPath
    Assert-Absent $ZxPath
}

function Test-LegacyUpgrade {
    $Context = New-CaseContext "legacy"
    $ZxPath = Join-Path $Context.Skills "zx-skills"
    New-CurrentLink $ZxPath $ZxSource
    $LegacyRaw = Get-RawLinkTarget $ZxPath

    Assert-ExitCode (Invoke-Installer $Context install) 0 "legacy-only upgrade"
    Assert-CurrentLink (Join-Path $Context.Skills "opc-skills") $OpcSource
    Assert-CurrentLink $ZxPath $ZxSource
    if ((Get-RawLinkTarget $ZxPath) -ne $LegacyRaw) {
        Fail-Test "legacy alias was replaced"
    }
}

function Test-StatusMatrix {
    $Context = New-CaseContext "status-absent"
    Assert-Status (Invoke-Installer $Context status) absent absent 1
    if (Test-Path -LiteralPath $Context.Skills) {
        Fail-Test "absent status created the target parent"
    }

    $Context = New-CaseContext "status-partial"
    $OpcPath = Join-Path $Context.Skills "opc-skills"
    New-CurrentLink $OpcPath $OpcSource -Relative
    $Raw = Get-RawLinkTarget $OpcPath
    Assert-Status (Invoke-Installer $Context status) current absent 1
    Assert-CurrentLink $OpcPath $OpcSource
    if ((Get-RawLinkTarget $OpcPath) -ne $Raw) {
        Fail-Test "partial status replaced opc-skills"
    }
    Assert-Absent (Join-Path $Context.Skills "zx-skills")
}

function Test-Fallback {
    $Context = New-CaseContext "fallback"
    $FallbackSkills = Join-Path $Context.Home ".agents\skills"
    Assert-ExitCode (Invoke-Installer $Context install -Fallback) 0 "fallback install"
    Assert-CurrentLink (Join-Path $FallbackSkills "opc-skills") $OpcSource
    Assert-CurrentLink (Join-Path $FallbackSkills "zx-skills") $ZxSource
    if ($env:HOME -ne $OriginalHomeEnvironment -or $HOME -ne $OriginalPowerShellHome) {
        Fail-Test "test changed HOME in the parent PowerShell process"
    }
    Assert-ExitCode (Invoke-Installer $Context uninstall -Fallback) 0 "fallback uninstall"
    Assert-Absent (Join-Path $FallbackSkills "opc-skills")
    Assert-Absent (Join-Path $FallbackSkills "zx-skills")
}

function Test-RelativeIdempotency {
    $Context = New-CaseContext "relative-idempotency"
    $OpcPath = Join-Path $Context.Skills "opc-skills"
    $ZxPath = Join-Path $Context.Skills "zx-skills"
    New-CurrentLink $OpcPath $OpcSource -Relative
    New-CurrentLink $ZxPath $ZxSource -Relative
    $OpcRaw = Get-RawLinkTarget $OpcPath
    $ZxRaw = Get-RawLinkTarget $ZxPath
    $OpcCreated = (Get-Item -LiteralPath $OpcPath -Force).CreationTimeUtc
    $ZxCreated = (Get-Item -LiteralPath $ZxPath -Force).CreationTimeUtc

    Assert-ExitCode (Invoke-Installer $Context install) 0 "relative idempotent install 1"
    Assert-ExitCode (Invoke-Installer $Context install) 0 "relative idempotent install 2"
    Assert-CurrentLink $OpcPath $OpcSource
    Assert-CurrentLink $ZxPath $ZxSource
    if ((Get-RawLinkTarget $OpcPath) -ne $OpcRaw -or (Get-RawLinkTarget $ZxPath) -ne $ZxRaw) {
        Fail-Test "relative current entries were replaced"
    }
    if ((Get-Item -LiteralPath $OpcPath -Force).CreationTimeUtc -ne $OpcCreated -or
        (Get-Item -LiteralPath $ZxPath -Force).CreationTimeUtc -ne $ZxCreated) {
        Fail-Test "current entries were recreated"
    }
}

function New-Conflict {
    param(
        [string]$Kind,
        [string]$Path,
        [pscustomobject]$Context,
        [string]$EntryName
    )

    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    switch ($Kind) {
        "foreign-link" {
            $ForeignTarget = Join-Path $Context.Root "foreign-target"
            [IO.Directory]::CreateDirectory($ForeignTarget) | Out-Null
            [IO.File]::WriteAllText((Join-Path $ForeignTarget "marker.txt"), "foreign-link-content")
            $LinkType = if ($IsNativeWindows) { "Junction" } else { "SymbolicLink" }
            Microsoft.PowerShell.Management\New-Item -ItemType $LinkType -Path $Path -Target $ForeignTarget | Out-Null
            return [pscustomobject]@{
                Kind = $Kind
                Path = $Path
                Expected = Get-RawLinkTarget $Path
                ContentPath = Join-Path $ForeignTarget "marker.txt"
                ExpectedContent = "foreign-link-content"
            }
        }
        "broken-link" {
            $BrokenTarget = Join-Path $Context.Root "deleted-target-$EntryName"
            [IO.Directory]::CreateDirectory($BrokenTarget) | Out-Null
            $LinkType = if ($IsNativeWindows) { "Junction" } else { "SymbolicLink" }
            Microsoft.PowerShell.Management\New-Item -ItemType $LinkType -Path $Path -Target $BrokenTarget | Out-Null
            $Raw = Get-RawLinkTarget $Path
            [IO.Directory]::Delete($BrokenTarget)
            return [pscustomobject]@{ Kind = $Kind; Path = $Path; Expected = $Raw }
        }
        "ordinary-directory" {
            [IO.Directory]::CreateDirectory($Path) | Out-Null
            [IO.File]::WriteAllText((Join-Path $Path "marker.txt"), "ordinary-directory-content")
            return [pscustomobject]@{ Kind = $Kind; Path = $Path; Expected = "ordinary-directory-content" }
        }
        "repository-directory" {
            [IO.Directory]::CreateDirectory((Join-Path $Path ".git")) | Out-Null
            [IO.File]::WriteAllText((Join-Path $Path ".git/config"), "repository-owned-content")
            return [pscustomobject]@{ Kind = $Kind; Path = $Path; Expected = "repository-owned-content" }
        }
        "business-skill-directory" {
            [IO.Directory]::CreateDirectory($Path) | Out-Null
            [IO.File]::WriteAllText((Join-Path $Path "SKILL.md"), "business-skill-owned-content")
            return [pscustomobject]@{ Kind = $Kind; Path = $Path; Expected = "business-skill-owned-content" }
        }
    }
    Fail-Test "unknown conflict kind: $Kind"
}

function Assert-ConflictIntact {
    param([pscustomobject]$Conflict)
    switch ($Conflict.Kind) {
        { $_ -in @("foreign-link", "broken-link") } {
            $Item = Get-Item -LiteralPath $Conflict.Path -Force -ErrorAction SilentlyContinue
            if ($null -eq $Item -or -not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                Fail-Test "$($Conflict.Kind) was removed"
            }
            if ((Get-RawLinkTarget $Conflict.Path) -ne $Conflict.Expected) {
                Fail-Test "$($Conflict.Kind) target changed"
            }
            if ($Conflict.Kind -eq "foreign-link" -and
                [IO.File]::ReadAllText($Conflict.ContentPath) -ne $Conflict.ExpectedContent) {
                Fail-Test "foreign link content changed"
            }
        }
        "ordinary-directory" {
            if ([IO.File]::ReadAllText((Join-Path $Conflict.Path "marker.txt")) -ne $Conflict.Expected) {
                Fail-Test "ordinary directory content changed"
            }
        }
        "repository-directory" {
            if ([IO.File]::ReadAllText((Join-Path $Conflict.Path ".git/config")) -ne $Conflict.Expected) {
                Fail-Test "repository directory content changed"
            }
        }
        "business-skill-directory" {
            if ([IO.File]::ReadAllText((Join-Path $Conflict.Path "SKILL.md")) -ne $Conflict.Expected) {
                Fail-Test "business Skill directory content changed"
            }
        }
    }
}

function Test-ConflictMatrix {
    foreach ($Kind in @("foreign-link", "broken-link", "ordinary-directory", "repository-directory", "business-skill-directory")) {
        foreach ($ConflictEntry in @("opc-skills", "zx-skills")) {
            $Context = New-CaseContext "conflict-$Kind-$ConflictEntry"
            $ConflictPath = Join-Path $Context.Skills $ConflictEntry
            if ($ConflictEntry -eq "opc-skills") {
                $OtherEntry = "zx-skills"
                $OtherSource = $ZxSource
                $ExpectedOpc = "conflict"
                $ExpectedZx = "absent"
            }
            else {
                $OtherEntry = "opc-skills"
                $OtherSource = $OpcSource
                $ExpectedOpc = "absent"
                $ExpectedZx = "conflict"
            }
            $OtherPath = Join-Path $Context.Skills $OtherEntry
            $Conflict = New-Conflict $Kind $ConflictPath $Context $ConflictEntry

            Assert-Status (Invoke-Installer $Context status) $ExpectedOpc $ExpectedZx 1
            Assert-ConflictIntact $Conflict
            Assert-Absent $OtherPath

            $Install = Invoke-Installer $Context install
            Assert-Nonzero $Install "install with $Kind at $ConflictEntry"
            Assert-ConflictIntact $Conflict
            Assert-Absent $OtherPath

            New-CurrentLink $OtherPath $OtherSource -Relative
            $OtherRaw = Get-RawLinkTarget $OtherPath
            $Uninstall = Invoke-Installer $Context uninstall
            Assert-Nonzero $Uninstall "uninstall with $Kind at $ConflictEntry"
            Assert-ConflictIntact $Conflict
            Assert-CurrentLink $OtherPath $OtherSource
            if ((Get-RawLinkTarget $OtherPath) -ne $OtherRaw) {
                Fail-Test "uninstall replaced $OtherEntry beside $Kind conflict"
            }
        }
    }
}

function Write-FaultHarness {
    $HarnessPath = Join-Path $SuiteRoot "invoke-install-with-link-failure.ps1"
    $Harness = @'
param(
    [string]$InstallerPath,
    [string]$SkillsHome,
    [int]$FailAt
)

$ErrorActionPreference = "Stop"
$env:OPCSKILLS_SKILLS_HOME = $SkillsHome
$script:LinkCreationCount = 0

function New-Item {
    param([string]$ItemType, [string]$Path, [object]$Target, [switch]$Force)

    if ($ItemType -in @("SymbolicLink", "Junction")) {
        $script:LinkCreationCount++
        if ($script:LinkCreationCount -eq $FailAt) {
            throw "injected link failure at creation $FailAt"
        }
    }
    $Arguments = @{ ItemType = $ItemType; Path = $Path }
    if ($PSBoundParameters.ContainsKey("Target")) { $Arguments.Target = $Target }
    if ($Force) { $Arguments.Force = $true }
    Microsoft.PowerShell.Management\New-Item @Arguments
}

try {
    & $InstallerPath install
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 97
}
'@
    [IO.File]::WriteAllText($HarnessPath, $Harness)
    return $HarnessPath
}

function Invoke-FaultInstaller {
    param([pscustomobject]$Context, [int]$FailAt, [string]$HarnessPath)
    return Invoke-TestProcess @(
        "-NoProfile", "-File", $HarnessPath,
        "-InstallerPath", $ScriptPath,
        "-SkillsHome", $Context.Skills,
        "-FailAt", [string]$FailAt
    ) $Context "Override"
}

function Test-Rollback {
    $HarnessPath = Write-FaultHarness

    $Context = New-CaseContext "rollback-second"
    $Result = Invoke-FaultInstaller $Context 2 $HarnessPath
    Assert-Nonzero $Result "second-link fault injection"
    if ($Result.StdErr -notmatch "rolled back" -or $Result.StdErr -notmatch "injected link failure") {
        Fail-Test "second-link fault did not exercise installer rollback: $($Result.StdErr)"
    }
    Assert-Absent (Join-Path $Context.Skills "opc-skills")
    Assert-Absent (Join-Path $Context.Skills "zx-skills")

    $Context = New-CaseContext "rollback-preserve-current"
    $OpcPath = Join-Path $Context.Skills "opc-skills"
    New-CurrentLink $OpcPath $OpcSource -Relative
    $OpcRaw = Get-RawLinkTarget $OpcPath
    $Result = Invoke-FaultInstaller $Context 1 $HarnessPath
    Assert-Nonzero $Result "missing-alias fault injection"
    if ($Result.StdErr -notmatch "rolled back" -or $Result.StdErr -notmatch "injected link failure") {
        Fail-Test "missing-alias fault did not exercise installer rollback: $($Result.StdErr)"
    }
    Assert-CurrentLink $OpcPath $OpcSource
    if ((Get-RawLinkTarget $OpcPath) -ne $OpcRaw) {
        Fail-Test "rollback replaced the pre-existing current primary link"
    }
    Assert-Absent (Join-Path $Context.Skills "zx-skills")
}

try {
    [IO.Directory]::CreateDirectory($SuiteRoot) | Out-Null
    Test-FreshLifecycle
    Test-LegacyUpgrade
    Test-StatusMatrix
    Test-Fallback
    Test-RelativeIdempotency
    Test-ConflictMatrix
    Test-Rollback

    if ($env:HOME -ne $OriginalHomeEnvironment -or $HOME -ne $OriginalPowerShellHome) {
        Fail-Test "test changed HOME in the parent PowerShell process"
    }
    Write-Host "PASS: PowerShell Codex installer covers dual-entry lifecycle, status, conflicts, fallback, idempotency, and rollback"
}
finally {
    if (Test-Path -LiteralPath $SuiteRoot) {
        Remove-Item -LiteralPath $SuiteRoot -Recurse -Force
    }
}
