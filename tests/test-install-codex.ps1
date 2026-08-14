$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ScriptPath = Join-Path $RepositoryRoot "scripts/install-codex.ps1"
$PowerShellPath = (Get-Command pwsh -ErrorAction Stop).Source
$TestRoot = Join-Path ([IO.Path]::GetTempPath()) ("opcskills-installer-" + [guid]::NewGuid().ToString("N"))
$OriginalSkillsHome = $env:OPCSKILLS_SKILLS_HOME
$OriginalHome = $env:HOME

function Fail-Test {
    param([string]$Message)
    throw "FAIL: $Message"
}

function Invoke-Installer {
    param(
        [ValidateSet("install", "status", "uninstall")][string]$Action,
        [switch]$Quiet
    )

    if ($Quiet) {
        & $PowerShellPath -NoProfile -File $ScriptPath $Action *> $null
    }
    else {
        & $PowerShellPath -NoProfile -File $ScriptPath $Action | Out-Host
    }
    return [int]$LASTEXITCODE
}

function Assert-Success {
    param([int]$ExitCode, [string]$Operation)
    if ($ExitCode -ne 0) {
        Fail-Test "$Operation exited with $ExitCode"
    }
}

function Assert-CurrentLink {
    param([string]$EntryName, [string]$ExpectedSource)

    $Path = Join-Path $env:OPCSKILLS_SKILLS_HOME $EntryName
    $Item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $Item -or -not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Fail-Test "$Path is not a link"
    }

    $LinkTarget = $Item.Target
    if ($LinkTarget -is [array]) {
        $LinkTarget = $LinkTarget[0]
    }
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

function Set-IsolatedCase {
    param([string]$Name)

    $CaseRoot = Join-Path $TestRoot $Name
    $env:HOME = Join-Path $CaseRoot "home"
    $env:OPCSKILLS_SKILLS_HOME = Join-Path $CaseRoot "skills"
    New-Item -ItemType Directory -Path $env:HOME -Force | Out-Null
}

try {
    New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

    Set-IsolatedCase "fresh"
    Assert-Success (Invoke-Installer install) "fresh install"
    Assert-CurrentLink "opc-skills" (Join-Path $RepositoryRoot "adapters/codex/opc-skills")
    Assert-CurrentLink "zx-skills" (Join-Path $RepositoryRoot "adapters/codex/zx-skills")
    $StatusOutput = @(& $PowerShellPath -NoProfile -File $ScriptPath status 2>&1)
    Assert-Success ([int]$LASTEXITCODE) "installed status"
    if ($StatusOutput.Count -ne 2) {
        Fail-Test "status should print exactly one line per entry"
    }
    if ($StatusOutput[0] -notmatch '^opc-skills: current ' -or
        $StatusOutput[1] -notmatch '^zx-skills: current ') {
        Fail-Test "status did not report both entrypoints as current"
    }
    Assert-Success (Invoke-Installer install) "idempotent install"
    Assert-Success (Invoke-Installer uninstall) "uninstall"
    Assert-Absent (Join-Path $env:OPCSKILLS_SKILLS_HOME "opc-skills")
    Assert-Absent (Join-Path $env:OPCSKILLS_SKILLS_HOME "zx-skills")

    Set-IsolatedCase "legacy"
    New-Item -ItemType Directory -Path $env:OPCSKILLS_SKILLS_HOME -Force | Out-Null
    New-Item -ItemType SymbolicLink `
        -Path (Join-Path $env:OPCSKILLS_SKILLS_HOME "zx-skills") `
        -Target (Join-Path $RepositoryRoot "adapters/codex/zx-skills") | Out-Null
    Assert-Success (Invoke-Installer install) "legacy-only upgrade"
    Assert-CurrentLink "opc-skills" (Join-Path $RepositoryRoot "adapters/codex/opc-skills")
    Assert-CurrentLink "zx-skills" (Join-Path $RepositoryRoot "adapters/codex/zx-skills")

    Set-IsolatedCase "conflict"
    New-Item -ItemType Directory -Path $env:OPCSKILLS_SKILLS_HOME -Force | Out-Null
    $ConflictPath = Join-Path $env:OPCSKILLS_SKILLS_HOME "opc-skills"
    Set-Content -LiteralPath $ConflictPath -Value "user-owned content" -NoNewline

    $InstallExit = Invoke-Installer install -Quiet
    if ($InstallExit -eq 0) {
        Fail-Test "install should reject a foreign opc-skills path"
    }
    if ((Get-Content -LiteralPath $ConflictPath -Raw) -ne "user-owned content") {
        Fail-Test "install changed the foreign opc-skills file"
    }
    Assert-Absent (Join-Path $env:OPCSKILLS_SKILLS_HOME "zx-skills")

    New-Item -ItemType SymbolicLink `
        -Path (Join-Path $env:OPCSKILLS_SKILLS_HOME "zx-skills") `
        -Target (Join-Path $RepositoryRoot "adapters/codex/zx-skills") | Out-Null
    $UninstallExit = Invoke-Installer uninstall -Quiet
    if ($UninstallExit -eq 0) {
        Fail-Test "uninstall should reject a foreign opc-skills path"
    }
    if ((Get-Content -LiteralPath $ConflictPath -Raw) -ne "user-owned content") {
        Fail-Test "uninstall changed the foreign opc-skills file"
    }
    Assert-CurrentLink "zx-skills" (Join-Path $RepositoryRoot "adapters/codex/zx-skills")

    Write-Host "PASS: PowerShell Codex installer manages both entrypoints safely"
}
finally {
    $env:OPCSKILLS_SKILLS_HOME = $OriginalSkillsHome
    $env:HOME = $OriginalHome
    if (Test-Path -LiteralPath $TestRoot) {
        Remove-Item -LiteralPath $TestRoot -Recurse -Force
    }
}
