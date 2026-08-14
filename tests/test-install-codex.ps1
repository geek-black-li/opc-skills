$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ScriptPath = Join-Path $RepositoryRoot "scripts/install-codex.ps1"
$PowerShellPath = (Get-Command pwsh -ErrorAction Stop).Source
$OpcSource = Join-Path $RepositoryRoot "adapters/codex/opc-skills"
$SuiteRoot = Join-Path ([IO.Path]::GetTempPath()) ("opcskills-installer-" + [guid]::NewGuid().ToString("N"))
$OriginalHomeEnvironment = $env:HOME
$OriginalPowerShellHome = $HOME
$IsNativeWindows = $env:OS -eq "Windows_NT"
$PathStringComparison = if ($IsNativeWindows) {
    [StringComparison]::OrdinalIgnoreCase
}
else {
    [StringComparison]::Ordinal
}
$RepositorySourceContracts = @(
    [pscustomobject]@{
        Path = Join-Path $OpcSource "SKILL.md"
        Hash = (Get-FileHash -LiteralPath (Join-Path $OpcSource "SKILL.md") -Algorithm SHA256).Hash
    }
)

function Fail-Test {
    param([string]$Message)
    throw "FAIL: $Message"
}

function Test-PathStringsEqualForCurrentPlatform {
    param(
        [string]$Left,
        [string]$Right
    )

    return [string]::Equals($Left, $Right, $PathStringComparison)
}

function Get-InstallerFunctionDefinition {
    param([string]$Name)

    $Tokens = $null
    $ParseErrors = $null
    $Ast = [Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath,
        [ref]$Tokens,
        [ref]$ParseErrors
    )
    if (@($ParseErrors).Count -ne 0) {
        Fail-Test "installer has PowerShell parse errors: $($ParseErrors -join '; ')"
    }

    $Definitions = @($Ast.FindAll({
        param($Node)
        $Node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $Node.Name -eq $Name
    }, $true))
    if ($Definitions.Count -ne 1) {
        Fail-Test "expected one $Name helper, found $($Definitions.Count)"
    }
    return [scriptblock]::Create($Definitions[0].Extent.Text)
}

function Assert-RepositorySourcesIntact {
    foreach ($Contract in $RepositorySourceContracts) {
        if (-not (Test-Path -LiteralPath $Contract.Path -PathType Leaf)) {
            Fail-Test "repository adapter source was removed: $($Contract.Path)"
        }
        $ActualHash = (Get-FileHash -LiteralPath $Contract.Path -Algorithm SHA256).Hash
        if ($ActualHash -ne $Contract.Hash) {
            Fail-Test "repository adapter source changed during installer tests: $($Contract.Path)"
        }
    }
}

function Get-TestOwnedReparsePoints {
    param([string]$Root)

    if (-not [IO.Directory]::Exists($Root)) {
        return @()
    }

    $Found = [Collections.Generic.List[object]]::new()
    $Pending = [Collections.Generic.Stack[string]]::new()
    $Pending.Push([IO.Path]::GetFullPath($Root))
    while ($Pending.Count -gt 0) {
        $Directory = $Pending.Pop()
        foreach ($Path in [IO.Directory]::EnumerateFileSystemEntries($Directory)) {
            $Attributes = [IO.File]::GetAttributes($Path)
            if ($Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $Found.Add([pscustomobject]@{ Path = $Path; Attributes = $Attributes })
                continue
            }
            if ($Attributes -band [IO.FileAttributes]::Directory) {
                $Pending.Push($Path)
            }
        }
    }
    return @($Found)
}

function Remove-TestOwnedReparsePoint {
    param(
        [string]$Path,
        [string]$Root
    )

    $FullRoot = [IO.Path]::GetFullPath($Root).TrimEnd("\", "/")
    $FullPath = [IO.Path]::GetFullPath($Path)
    $Comparison = if ($IsNativeWindows) {
        [StringComparison]::OrdinalIgnoreCase
    }
    else {
        [StringComparison]::Ordinal
    }
    $RootPrefix = $FullRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $FullPath.StartsWith($RootPrefix, $Comparison)) {
        Fail-Test "refusing to detach a reparse point outside the suite root: $FullPath"
    }

    try {
        $Attributes = [IO.File]::GetAttributes($FullPath)
    }
    catch [IO.FileNotFoundException] {
        return
    }
    catch [IO.DirectoryNotFoundException] {
        return
    }
    if (-not ($Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Fail-Test "refusing link-only cleanup for a non-reparse path: $FullPath"
    }

    if ($Attributes -band [IO.FileAttributes]::Directory) {
        [IO.Directory]::Delete($FullPath)
    }
    else {
        [IO.File]::Delete($FullPath)
    }
}

function Detach-TestOwnedReparsePoints {
    param([string]$Root)

    foreach ($ReparsePoint in @(Get-TestOwnedReparsePoints $Root)) {
        Remove-TestOwnedReparsePoint $ReparsePoint.Path $Root
    }
    $Remaining = @(Get-TestOwnedReparsePoints $Root)
    if ($Remaining.Count -ne 0) {
        Fail-Test "suite cleanup left $($Remaining.Count) reparse point(s) attached"
    }
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
    if (-not (Test-PathStringsEqualForCurrentPlatform $Actual $Expected)) {
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
        [int]$ExpectedExit
    )

    Assert-ExitCode $Result $ExpectedExit "status"
    $Lines = @($Result.StdOut.TrimEnd() -split "`r?`n")
    if ($Lines.Count -ne 1) {
        Fail-Test "status printed $($Lines.Count) lines, expected 1"
    }
    if ($Lines[0] -notmatch "^opc-skills: $OpcState ") {
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

function Test-PlatformPathComparison {
    $CaseVariantUpper = "/platform-check/OPCSkills/CaseTarget"
    $CaseVariantLower = "/platform-check/opcskills/casetarget"
    $ExpectedCaseVariantEquality = $IsNativeWindows

    $TestComparisonResult = Test-PathStringsEqualForCurrentPlatform $CaseVariantUpper $CaseVariantLower
    if ($TestComparisonResult -ne $ExpectedCaseVariantEquality) {
        Fail-Test "test path comparison does not match the current platform"
    }

    $ComparisonDefinition = Get-InstallerFunctionDefinition "Test-ResolvedPathsEqual"
    . $ComparisonDefinition
    if (-not (Test-ResolvedPathsEqual $CaseVariantUpper $CaseVariantUpper)) {
        Fail-Test "installer path comparison rejected identical strings"
    }
    if (Test-ResolvedPathsEqual "/platform-check/first" "/platform-check/second") {
        Fail-Test "installer path comparison accepted distinct strings"
    }
    if ((Test-ResolvedPathsEqual $CaseVariantUpper $CaseVariantLower) -ne $ExpectedCaseVariantEquality) {
        Fail-Test "installer path comparison does not match the current platform"
    }

    $ProbeContext = New-CaseContext "case-sensitivity-probe"
    $ProbeRoot = Join-Path $ProbeContext.Root "empty-probe"
    [IO.Directory]::CreateDirectory($ProbeRoot) | Out-Null
    $UpperProbe = Join-Path $ProbeRoot "CaseTarget"
    $LowerProbe = Join-Path $ProbeRoot "casetarget"
    [IO.Directory]::CreateDirectory($UpperProbe) | Out-Null
    [IO.Directory]::CreateDirectory($LowerProbe) | Out-Null
    $SupportsCaseDistinctPaths = @([IO.Directory]::EnumerateDirectories($ProbeRoot)).Count -eq 2

    if ($SupportsCaseDistinctPaths -and -not $IsNativeWindows) {
        $Context = New-CaseContext "case-variant-foreign-link"
        $FixtureRepository = Join-Path $Context.Root "FixtureRepository"
        $FixtureScriptDirectory = Join-Path $FixtureRepository "scripts"
        $FixtureAdapterParent = Join-Path $FixtureRepository "adapters/codex"
        $FixtureSource = Join-Path $FixtureAdapterParent "opc-skills"
        $ForeignTarget = Join-Path $FixtureAdapterParent "OPC-SKILLS"
        $FixtureScript = Join-Path $FixtureScriptDirectory "install-codex.ps1"
        [IO.Directory]::CreateDirectory($FixtureScriptDirectory) | Out-Null
        [IO.Directory]::CreateDirectory($FixtureSource) | Out-Null
        [IO.Directory]::CreateDirectory($ForeignTarget) | Out-Null
        [IO.File]::Copy($ScriptPath, $FixtureScript)
        [IO.File]::WriteAllText((Join-Path $FixtureSource "SKILL.md"), "fixture source`n")
        $MarkerPath = Join-Path $ForeignTarget "marker.txt"
        [IO.File]::WriteAllText($MarkerPath, "case-variant foreign target`n")

        $OpcPath = Join-Path $Context.Skills "opc-skills"
        New-CurrentLink $OpcPath $ForeignTarget
        $RawTarget = Get-RawLinkTarget $OpcPath
        $Uninstall = Invoke-TestProcess @("-NoProfile", "-File", $FixtureScript, "uninstall") $Context "Override"
        Assert-Nonzero $Uninstall "uninstall with a case-variant foreign target"
        if ($null -eq (Get-Item -LiteralPath $OpcPath -Force -ErrorAction SilentlyContinue)) {
            Fail-Test "uninstall removed a case-variant foreign link"
        }
        if (-not (Test-PathStringsEqualForCurrentPlatform (Get-RawLinkTarget $OpcPath) $RawTarget)) {
            Fail-Test "uninstall changed a case-variant foreign link target"
        }
        if ([IO.File]::ReadAllText($MarkerPath) -ne "case-variant foreign target`n") {
            Fail-Test "uninstall changed case-variant foreign target content"
        }
        return
    }

    if ($IsNativeWindows) {
        return
    }

    $Context = New-CaseContext "case-variant-comparison-fallback"
    $ForeignTarget = Join-Path $Context.Root "foreign-target"
    [IO.Directory]::CreateDirectory($ForeignTarget) | Out-Null
    $MarkerPath = Join-Path $ForeignTarget "marker.txt"
    [IO.File]::WriteAllText($MarkerPath, "foreign target`n")
    $OpcPath = Join-Path $Context.Skills "opc-skills"
    New-CurrentLink $OpcPath $ForeignTarget
    $RawTarget = Get-RawLinkTarget $OpcPath

    $TargetStateDefinition = Get-InstallerFunctionDefinition "Get-TargetState"
    . $TargetStateDefinition
    function Resolve-Path {
        param([string]$LiteralPath)

        if ([string]::Equals($LiteralPath, $ForeignTarget, [StringComparison]::Ordinal)) {
            return [pscustomobject]@{ Path = $CaseVariantUpper }
        }
        if ([string]::Equals($LiteralPath, $OpcSource, [StringComparison]::Ordinal)) {
            return [pscustomobject]@{ Path = $CaseVariantLower }
        }
        return Microsoft.PowerShell.Management\Resolve-Path -LiteralPath $LiteralPath
    }

    $Entry = [pscustomobject]@{
        Source = $OpcSource
        Target = $OpcPath
    }
    if ((Get-TargetState $Entry) -ne "conflict") {
        Fail-Test "case-variant foreign link was treated as current on a non-Windows platform"
    }
    if ($null -eq (Get-Item -LiteralPath $OpcPath -Force -ErrorAction SilentlyContinue)) {
        Fail-Test "case-variant comparison removed the foreign link"
    }
    if (-not (Test-PathStringsEqualForCurrentPlatform (Get-RawLinkTarget $OpcPath) $RawTarget) -or
        [IO.File]::ReadAllText($MarkerPath) -ne "foreign target`n") {
        Fail-Test "case-variant comparison changed the foreign link or its target"
    }

    $Uninstall = Invoke-Installer $Context uninstall
    Assert-Nonzero $Uninstall "uninstall with a real foreign target after case-variant comparison"
    if ($null -eq (Get-Item -LiteralPath $OpcPath -Force -ErrorAction SilentlyContinue)) {
        Fail-Test "uninstall removed the real foreign link"
    }
    if (-not (Test-PathStringsEqualForCurrentPlatform (Get-RawLinkTarget $OpcPath) $RawTarget) -or
        [IO.File]::ReadAllText($MarkerPath) -ne "foreign target`n") {
        Fail-Test "uninstall changed the real foreign link or its target"
    }
}

function Test-FreshLifecycle {
    $Context = New-CaseContext "fresh"
    $Install = Invoke-Installer $Context install
    Assert-ExitCode $Install 0 "fresh install"
    Assert-CurrentLink (Join-Path $Context.Skills "opc-skills") $OpcSource
    Assert-Status (Invoke-Installer $Context status) current 0

    $OpcPath = Join-Path $Context.Skills "opc-skills"
    $OpcRaw = Get-RawLinkTarget $OpcPath
    $Reinstall = Invoke-Installer $Context install
    Assert-ExitCode $Reinstall 0 "idempotent install"
    if (-not (Test-PathStringsEqualForCurrentPlatform (Get-RawLinkTarget $OpcPath) $OpcRaw)) {
        Fail-Test "idempotent install replaced a current entry"
    }

    $Uninstall = Invoke-Installer $Context uninstall
    Assert-ExitCode $Uninstall 0 "uninstall"
    Assert-Absent $OpcPath
}

function Test-ForeignZxNonInterference {
    $Context = New-CaseContext "foreign-zx-non-interference"
    $ForeignZx = Join-Path $Context.Skills "zx-skills"
    [IO.Directory]::CreateDirectory($Context.Skills) | Out-Null
    [IO.File]::WriteAllText($ForeignZx, "foreign`n")
    $Install = Invoke-Installer $Context "install"
    Assert-ExitCode $Install 0 "install beside foreign zx-skills file"
    Assert-CurrentLink (Join-Path $Context.Skills "opc-skills") $OpcSource
    if ([IO.File]::ReadAllText($ForeignZx) -ne "foreign`n") {
        Fail-Test "installer modified unrelated zx-skills path"
    }

    $Uninstall = Invoke-Installer $Context "uninstall"
    Assert-ExitCode $Uninstall 0 "uninstall beside foreign zx-skills file"
    Assert-Absent (Join-Path $Context.Skills "opc-skills")
    if ([IO.File]::ReadAllText($ForeignZx) -ne "foreign`n") {
        Fail-Test "uninstaller modified unrelated zx-skills path"
    }
}

function Test-StatusMatrix {
    $Context = New-CaseContext "status-absent"
    Assert-Status (Invoke-Installer $Context status) absent 1
    if (Test-Path -LiteralPath $Context.Skills) {
        Fail-Test "absent status created the target parent"
    }

    $Context = New-CaseContext "status-current"
    $OpcPath = Join-Path $Context.Skills "opc-skills"
    New-CurrentLink $OpcPath $OpcSource -Relative
    $Raw = Get-RawLinkTarget $OpcPath
    Assert-Status (Invoke-Installer $Context status) current 0
    Assert-CurrentLink $OpcPath $OpcSource
    if (-not (Test-PathStringsEqualForCurrentPlatform (Get-RawLinkTarget $OpcPath) $Raw)) {
        Fail-Test "status replaced opc-skills"
    }
}

function Test-Fallback {
    $Context = New-CaseContext "fallback"
    $FallbackSkills = Join-Path $Context.Home ".agents\skills"
    Assert-ExitCode (Invoke-Installer $Context install -Fallback) 0 "fallback install"
    Assert-CurrentLink (Join-Path $FallbackSkills "opc-skills") $OpcSource
    if (-not (Test-PathStringsEqualForCurrentPlatform $env:HOME $OriginalHomeEnvironment) -or
        -not (Test-PathStringsEqualForCurrentPlatform $HOME $OriginalPowerShellHome)) {
        Fail-Test "test changed HOME in the parent PowerShell process"
    }
    Assert-ExitCode (Invoke-Installer $Context uninstall -Fallback) 0 "fallback uninstall"
    Assert-Absent (Join-Path $FallbackSkills "opc-skills")
}

function Test-RelativeIdempotency {
    $Context = New-CaseContext "relative-idempotency"
    $OpcPath = Join-Path $Context.Skills "opc-skills"
    New-CurrentLink $OpcPath $OpcSource -Relative
    $OpcRaw = Get-RawLinkTarget $OpcPath
    $OpcCreated = (Get-Item -LiteralPath $OpcPath -Force).CreationTimeUtc

    Assert-ExitCode (Invoke-Installer $Context install) 0 "relative idempotent install 1"
    Assert-ExitCode (Invoke-Installer $Context install) 0 "relative idempotent install 2"
    Assert-CurrentLink $OpcPath $OpcSource
    if (-not (Test-PathStringsEqualForCurrentPlatform (Get-RawLinkTarget $OpcPath) $OpcRaw)) {
        Fail-Test "relative current entries were replaced"
    }
    if ((Get-Item -LiteralPath $OpcPath -Force).CreationTimeUtc -ne $OpcCreated) {
        Fail-Test "current entries were recreated"
    }
}

function Write-RemovalGuardHarness {
    $HarnessPath = Join-Path $SuiteRoot "invoke-uninstall-with-remove-item-guard.ps1"
    $Harness = @'
param(
    [string]$InstallerPath,
    [string]$SkillsHome
)

$ErrorActionPreference = "Stop"
$env:OPCSKILLS_SKILLS_HOME = $SkillsHome

function Remove-Item {
    param(
        [string]$LiteralPath,
        [switch]$Force,
        [switch]$Recurse
    )

    $Item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $Item -and ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "unsafe Remove-Item call for managed reparse point: $LiteralPath"
    }

    $Arguments = @{ LiteralPath = $LiteralPath }
    if ($Force) { $Arguments.Force = $true }
    if ($Recurse) { $Arguments.Recurse = $true }
    Microsoft.PowerShell.Management\Remove-Item @Arguments
}

try {
    & $InstallerPath uninstall
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 98
}
'@
    [IO.File]::WriteAllText($HarnessPath, $Harness)
    return $HarnessPath
}

function Test-LinkOnlyUninstall {
    $Context = New-CaseContext "link-only-uninstall"
    Assert-ExitCode (Invoke-Installer $Context install) 0 "link-only uninstall setup"

    $HarnessPath = Write-RemovalGuardHarness
    $Result = Invoke-TestProcess @(
        "-NoProfile", "-File", $HarnessPath,
        "-InstallerPath", $ScriptPath,
        "-SkillsHome", $Context.Skills
    ) $Context "Override"

    Assert-ExitCode $Result 0 "link-only uninstall"
    if (-not [string]::IsNullOrWhiteSpace($Result.StdErr)) {
        Fail-Test "link-only uninstall wrote stderr: $($Result.StdErr)"
    }
    Assert-Absent (Join-Path $Context.Skills "opc-skills")
    Assert-RepositorySourcesIntact
}

function Test-SuiteCleanupContract {
    $Context = New-CaseContext "suite-cleanup-contract"
    $LiveLink = Join-Path $Context.Skills "live-source-link"
    New-CurrentLink $LiveLink $OpcSource

    $BrokenTarget = Join-Path $Context.Root "deleted-link-target"
    [IO.Directory]::CreateDirectory($BrokenTarget) | Out-Null
    $BrokenLink = Join-Path $Context.Skills "broken-source-link"
    New-CurrentLink $BrokenLink $BrokenTarget
    [IO.Directory]::Delete($BrokenTarget)

    $Before = @(Get-TestOwnedReparsePoints $Context.Root)
    if ($Before.Count -ne 2) {
        Fail-Test "cleanup contract discovered $($Before.Count) reparse points, expected 2"
    }
    Detach-TestOwnedReparsePoints $Context.Root
    Assert-Absent $LiveLink
    Assert-Absent $BrokenLink
    Assert-RepositorySourcesIntact
}

function Test-NativeWindowsLinkRemovalContract {
    # macOS cannot execute a native Windows Junction. Keep this narrow AST
    # contract beside the real link-removal tests so a Junction-incompatible
    # File.Delete/Remove-Item regression is still caught here.
    $Tokens = $null
    $ParseErrors = $null
    $Ast = [Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath,
        [ref]$Tokens,
        [ref]$ParseErrors
    )
    if (@($ParseErrors).Count -ne 0) {
        Fail-Test "installer has PowerShell parse errors: $($ParseErrors -join '; ')"
    }

    $Helpers = @($Ast.FindAll({
        param($Node)
        $Node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $Node.Name -eq "Remove-CurrentEntrypointLink"
    }, $true))
    if ($Helpers.Count -ne 1) {
        Fail-Test "expected one link-only removal helper, found $($Helpers.Count)"
    }

    $Helper = $Helpers[0]
    $DirectoryDeleteCalls = @($Helper.Body.FindAll({
        param($Node)
        $Node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
            $Node.Static -and
            $Node.Expression.Extent.Text -eq "[IO.Directory]" -and
            $Node.Member.Extent.Text -eq "Delete"
    }, $true))
    if ($DirectoryDeleteCalls.Count -ne 1) {
        Fail-Test "link-only helper must call the Junction-safe IO.Directory.Delete API exactly once"
    }
    if ($DirectoryDeleteCalls[0].Arguments.Count -ne 1) {
        Fail-Test "link-only helper must use the non-recursive IO.Directory.Delete overload"
    }

    $UnsafeCommands = @($Helper.Body.FindAll({
        param($Node)
        $Node -is [Management.Automation.Language.CommandAst] -and
            $Node.GetCommandName() -eq "Remove-Item"
    }, $true))
    if ($UnsafeCommands.Count -ne 0) {
        Fail-Test "link-only helper must not call Remove-Item for a directory reparse point"
    }

    $OwnershipRechecks = @($Helper.Body.FindAll({
        param($Node)
        $Node -is [Management.Automation.Language.CommandAst] -and
            $Node.GetCommandName() -eq "Get-TargetState"
    }, $true))
    if ($OwnershipRechecks.Count -ne 1) {
        Fail-Test "link-only helper must recheck current-install ownership exactly once before deletion"
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
            if (-not (Test-PathStringsEqualForCurrentPlatform (Get-RawLinkTarget $Conflict.Path) $Conflict.Expected)) {
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
        $Context = New-CaseContext "conflict-$Kind-opc-skills"
        $ConflictPath = Join-Path $Context.Skills "opc-skills"
        $Conflict = New-Conflict $Kind $ConflictPath $Context "opc-skills"

        Assert-Status (Invoke-Installer $Context status) conflict 1
        Assert-ConflictIntact $Conflict

        $Install = Invoke-Installer $Context install
        Assert-Nonzero $Install "install with $Kind at opc-skills"
        Assert-ConflictIntact $Conflict

        $Uninstall = Invoke-Installer $Context uninstall
        Assert-Nonzero $Uninstall "uninstall with $Kind at opc-skills"
        Assert-ConflictIntact $Conflict
    }
}

function Write-FaultHarness {
    $HarnessPath = Join-Path $SuiteRoot "invoke-install-with-post-create-failure.ps1"
    $Harness = @'
param(
    [string]$InstallerPath,
    [string]$SkillsHome,
    [string]$CreationMarker
)

$ErrorActionPreference = "Stop"
$env:OPCSKILLS_SKILLS_HOME = $SkillsHome

function New-Item {
    param([string]$ItemType, [string]$Path, [object]$Target, [switch]$Force)

    $Arguments = @{ ItemType = $ItemType; Path = $Path }
    if ($PSBoundParameters.ContainsKey("Target")) { $Arguments.Target = $Target }
    if ($Force) { $Arguments.Force = $true }
    $CreatedItem = Microsoft.PowerShell.Management\New-Item @Arguments
    if ($ItemType -in @("SymbolicLink", "Junction")) {
        $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if (-not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "fault harness did not create a real reparse point: $Path"
        }
        [IO.File]::WriteAllText($CreationMarker, "created`n")
    }
    return $CreatedItem
}

function Remove-Item {
    param(
        [string]$LiteralPath,
        [switch]$Force,
        [switch]$Recurse
    )

    $Item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $Item -and ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "unsafe Remove-Item call during rollback: $LiteralPath"
    }

    $Arguments = @{ LiteralPath = $LiteralPath }
    if ($Force) { $Arguments.Force = $true }
    if ($Recurse) { $Arguments.Recurse = $true }
    Microsoft.PowerShell.Management\Remove-Item @Arguments
}

try {
    & $InstallerPath install -TestFailAfterLinkCreate
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
    param([pscustomobject]$Context, [string]$HarnessPath, [string]$CreationMarker)
    return Invoke-TestProcess @(
        "-NoProfile", "-File", $HarnessPath,
        "-InstallerPath", $ScriptPath,
        "-SkillsHome", $Context.Skills,
        "-CreationMarker", $CreationMarker
    ) $Context "Override"
}

function Test-Rollback {
    $HarnessPath = Write-FaultHarness

    $Context = New-CaseContext "rollback-post-create"
    $CreationMarker = Join-Path $Context.Root "link-created.txt"
    $Result = Invoke-FaultInstaller $Context $HarnessPath $CreationMarker
    Assert-Nonzero $Result "post-create fault injection"
    if (-not [IO.File]::Exists($CreationMarker) -or
        [IO.File]::ReadAllText($CreationMarker) -ne "created`n") {
        Fail-Test "post-create fault injection never created the owned link"
    }
    if ($Result.StdErr -notmatch "rolled back" -or
        $Result.StdErr -notmatch "injected post-create failure") {
        Fail-Test "post-create fault did not exercise installer rollback path: $($Result.StdErr)"
    }
    Assert-Absent (Join-Path $Context.Skills "opc-skills")
}

try {
    [IO.Directory]::CreateDirectory($SuiteRoot) | Out-Null
    Test-FreshLifecycle
    Test-ForeignZxNonInterference
    Test-StatusMatrix
    Test-PlatformPathComparison
    Test-Fallback
    Test-RelativeIdempotency
    Test-SuiteCleanupContract
    Test-NativeWindowsLinkRemovalContract
    Test-LinkOnlyUninstall
    Test-ConflictMatrix
    Test-Rollback

    if (-not (Test-PathStringsEqualForCurrentPlatform $env:HOME $OriginalHomeEnvironment) -or
        -not (Test-PathStringsEqualForCurrentPlatform $HOME $OriginalPowerShellHome)) {
        Fail-Test "test changed HOME in the parent PowerShell process"
    }
    Write-Host "PASS: PowerShell Codex installer covers the opc-skills lifecycle, status, conflicts, fallback, idempotency, non-interference, and rollback"
}
finally {
    try {
        if (Test-Path -LiteralPath $SuiteRoot) {
            Detach-TestOwnedReparsePoints $SuiteRoot
            Remove-Item -LiteralPath $SuiteRoot -Recurse -Force
        }
    }
    finally {
        Assert-RepositorySourcesIntact
    }
}
