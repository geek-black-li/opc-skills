$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ScriptPath = Join-Path $RepositoryRoot "scripts/configure-codex-reminder.ps1"
$TestRoot = Join-Path ([IO.Path]::GetTempPath()) ("zx-skills-reminder-" + [guid]::NewGuid())
$OriginalCodexHome = $env:CODEX_HOME

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Expected
    )

    if (-not $Text.Contains($Expected)) {
        throw "Expected text was not found: $Expected"
    }
}

try {
    $env:CODEX_HOME = Join-Path $TestRoot "codex"
    New-Item -ItemType Directory -Path $env:CODEX_HOME -Force | Out-Null
    $AgentsFile = Join-Path $env:CODEX_HOME "AGENTS.md"
    [IO.File]::WriteAllText($AgentsFile, "# Existing global rules`n`n- Keep this line.`n")

    & $ScriptPath install
    $Content = [IO.File]::ReadAllText($AgentsFile)
    Assert-Contains $Content "# Existing global rules"
    Assert-Contains $Content "<!-- zx-skills-reminder:start -->"
    Assert-Contains $Content '$opc-skills 总结一下当前链路'

    & $ScriptPath install
    $Content = [IO.File]::ReadAllText($AgentsFile)
    $StartCount = ([regex]::Matches($Content, [regex]::Escape("<!-- zx-skills-reminder:start -->"))).Count
    if ($StartCount -ne 1) {
        throw "Install is not idempotent."
    }

    & $ScriptPath status

    & $ScriptPath uninstall
    $Content = [IO.File]::ReadAllText($AgentsFile)
    Assert-Contains $Content "# Existing global rules"
    Assert-Contains $Content "- Keep this line."
    if ($Content.Contains("<!-- zx-skills-reminder:start -->")) {
        throw "Uninstall left the managed block behind."
    }

    [IO.File]::WriteAllText($AgentsFile, "# Base rules`n")
    $OverrideFile = Join-Path $env:CODEX_HOME "AGENTS.override.md"
    [IO.File]::WriteAllText($OverrideFile, "# Temporary override`n")
    & $ScriptPath install
    $Content = [IO.File]::ReadAllText($OverrideFile)
    Assert-Contains $Content "<!-- zx-skills-reminder:start -->"
    $BaseContent = [IO.File]::ReadAllText($AgentsFile)
    if ($BaseContent.Contains("<!-- zx-skills-reminder:start -->")) {
        throw "Install wrote the reminder to inactive AGENTS.md."
    }
    & $ScriptPath uninstall
    $Content = [IO.File]::ReadAllText($OverrideFile)
    Assert-Contains $Content "# Temporary override"

    [IO.File]::WriteAllText($AgentsFile, "# Active base rules`n")
    [IO.File]::WriteAllText($OverrideFile, "")
    & $ScriptPath install
    $Content = [IO.File]::ReadAllText($AgentsFile)
    Assert-Contains $Content "<!-- zx-skills-reminder:start -->"
    $OverrideContent = [IO.File]::ReadAllText($OverrideFile)
    if ($OverrideContent.Contains("<!-- zx-skills-reminder:start -->")) {
        throw "Install made an empty override active and hid AGENTS.md."
    }
    & $ScriptPath uninstall

    [IO.File]::WriteAllText($AgentsFile, "<!-- zx-skills-reminder:start -->`n")
    $FailedAsExpected = $false
    try {
        & $ScriptPath install 2>$null
    }
    catch {
        $FailedAsExpected = $true
    }
    if (-not $FailedAsExpected) {
        throw "Install accepted malformed managed markers."
    }

    $Readme = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "README.md"))
    Assert-Contains $Readme "configure-codex-reminder.ps1 install"
    Assert-Contains $Readme "只提醒，不自动执行"

    Write-Host "OPCSkills PowerShell reminder configuration tests passed."
}
finally {
    $env:CODEX_HOME = $OriginalCodexHome
    if (Test-Path -LiteralPath $TestRoot) {
        Remove-Item -LiteralPath $TestRoot -Recurse -Force
    }
}
