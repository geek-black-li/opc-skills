$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ScriptPath = Join-Path $RepositoryRoot "scripts/configure-codex-reminder.ps1"
$PowerShellPath = (Get-Command pwsh -ErrorAction Stop).Source
$TestRoot = Join-Path ([IO.Path]::GetTempPath()) ("opcskills-reminder-" + [guid]::NewGuid().ToString("N"))
$CodexHome = Join-Path $TestRoot "codex"
$OriginalCodexHome = $env:CODEX_HOME
$Checkpoints = [ordered]@{
    Install = $false
    Idempotency = $false
    Status = $false
    Uninstall = $false
    ActiveOverride = $false
    MalformedMarkers = $false
    UnrelatedContent = $false
    Readme = $false
}

function Fail-Test {
    param([string]$Message)
    throw "FAIL: $Message"
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Expected
    )

    if (-not $Text.Contains($Expected)) {
        Fail-Test "expected text was not found: $Expected"
    }
}

function Assert-NotContains {
    param(
        [string]$Text,
        [string]$Unexpected
    )

    if ($Text.Contains($Unexpected)) {
        Fail-Test "unexpected text was found: $Unexpected"
    }
}

function Invoke-Reminder {
    param([ValidateSet("install", "status", "uninstall")][string]$Action)

    $StartInfo = [Diagnostics.ProcessStartInfo]::new()
    $StartInfo.FileName = $PowerShellPath
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    foreach ($Argument in @("-NoProfile", "-File", $ScriptPath, $Action)) {
        $StartInfo.ArgumentList.Add($Argument)
    }
    $StartInfo.Environment["CODEX_HOME"] = $CodexHome

    $Process = [Diagnostics.Process]::new()
    $Process.StartInfo = $StartInfo
    $Process.Start() | Out-Null
    $StdOutTask = $Process.StandardOutput.ReadToEndAsync()
    $StdErrTask = $Process.StandardError.ReadToEndAsync()
    $Process.WaitForExit()
    return [pscustomobject]@{
        Action = $Action
        ExitCode = $Process.ExitCode
        StdOut = $StdOutTask.GetAwaiter().GetResult()
        StdErr = $StdErrTask.GetAwaiter().GetResult()
    }
}

function Assert-ActionSucceeded {
    param(
        [pscustomobject]$Result,
        [string]$ExpectedOutput
    )

    if ($Result.ExitCode -ne 0) {
        Fail-Test "$($Result.Action) exited with $($Result.ExitCode). stderr: $($Result.StdErr)"
    }
    if (-not [string]::IsNullOrWhiteSpace($Result.StdErr)) {
        Fail-Test "$($Result.Action) wrote stderr: $($Result.StdErr)"
    }
    Assert-Contains $Result.StdOut $ExpectedOutput
}

function Assert-ManagedBlockCount {
    param(
        [string]$Content,
        [int]$Expected
    )

    foreach ($Marker in @("<!-- opc-skills-reminder:start -->", "<!-- opc-skills-reminder:end -->")) {
        $Count = ([regex]::Matches($Content, [regex]::Escape($Marker))).Count
        if ($Count -ne $Expected) {
            Fail-Test "marker '$Marker' appeared $Count time(s), expected $Expected"
        }
    }
}

function New-UnrelatedContent {
    param(
        [string]$Before,
        [string]$After
    )

    return @(
        $Before,
        $After,
        ""
    ) -join "`n"
}

try {
    [IO.Directory]::CreateDirectory($CodexHome) | Out-Null
    $AgentsFile = Join-Path $CodexHome "AGENTS.md"
    $OverrideFile = Join-Path $CodexHome "AGENTS.override.md"

    [IO.File]::WriteAllText(
        $AgentsFile,
        (New-UnrelatedContent "# Existing global rules`n`n- Keep before." "- Keep after.")
    )
    Assert-ActionSucceeded (Invoke-Reminder install) "OPCSkills completion reminder configured."
    $Content = [IO.File]::ReadAllText($AgentsFile)
    Assert-Contains $Content "# Existing global rules"
    Assert-Contains $Content "- Keep before."
    Assert-Contains $Content "- Keep after."
    Assert-ManagedBlockCount $Content 1
    Assert-Contains $Content '$opc-skills 总结一下当前链路'
    Assert-NotContains $Content '$zx-skills 总结一下当前链路'
    Assert-NotContains $Content 'zx-skills-reminder'
    $Checkpoints.Install = $true
    $Checkpoints.UnrelatedContent = $true

    Assert-ActionSucceeded (Invoke-Reminder install) "OPCSkills completion reminder configured."
    $Content = [IO.File]::ReadAllText($AgentsFile)
    Assert-ManagedBlockCount $Content 1
    $Checkpoints.Idempotency = $true

    Assert-ActionSucceeded (Invoke-Reminder status) "OPCSkills completion reminder is configured."
    $Checkpoints.Status = $true

    Assert-ActionSucceeded (Invoke-Reminder uninstall) "OPCSkills completion reminder removed."
    $Content = [IO.File]::ReadAllText($AgentsFile)
    Assert-Contains $Content "# Existing global rules"
    Assert-Contains $Content "- Keep before."
    Assert-Contains $Content "- Keep after."
    Assert-ManagedBlockCount $Content 0
    $Checkpoints.Uninstall = $true

    [IO.File]::WriteAllText(
        $AgentsFile,
        (New-UnrelatedContent "# Base rules`n`n- Base before." "- Base after.")
    )
    [IO.File]::WriteAllText($OverrideFile, "# Temporary override`n")
    Assert-ActionSucceeded (Invoke-Reminder install) "OPCSkills completion reminder configured."
    $BaseContent = [IO.File]::ReadAllText($AgentsFile)
    Assert-Contains $BaseContent "# Base rules"
    Assert-Contains $BaseContent "- Base before."
    Assert-Contains $BaseContent "- Base after."
    Assert-ManagedBlockCount $BaseContent 0
    $OverrideContent = [IO.File]::ReadAllText($OverrideFile)
    Assert-Contains $OverrideContent "# Temporary override"
    Assert-ManagedBlockCount $OverrideContent 1
    Assert-Contains $OverrideContent '$opc-skills 总结一下当前链路'
    Assert-NotContains $OverrideContent '$zx-skills 总结一下当前链路'
    Assert-NotContains $OverrideContent 'zx-skills-reminder'
    $Checkpoints.ActiveOverride = $true

    Assert-ActionSucceeded (Invoke-Reminder uninstall) "OPCSkills completion reminder removed."
    $OverrideContent = [IO.File]::ReadAllText($OverrideFile)
    Assert-Contains $OverrideContent "# Temporary override"
    Assert-ManagedBlockCount $OverrideContent 0

    [IO.File]::WriteAllText($AgentsFile, "# Active base rules`n")
    [IO.File]::WriteAllText($OverrideFile, "")
    Assert-ActionSucceeded (Invoke-Reminder install) "OPCSkills completion reminder configured."
    $Content = [IO.File]::ReadAllText($AgentsFile)
    Assert-ManagedBlockCount $Content 1
    $OverrideContent = [IO.File]::ReadAllText($OverrideFile)
    Assert-ManagedBlockCount $OverrideContent 0
    Assert-ActionSucceeded (Invoke-Reminder uninstall) "OPCSkills completion reminder removed."

    [IO.File]::WriteAllText($AgentsFile, "<!-- opc-skills-reminder:start -->`n")
    $MalformedResult = Invoke-Reminder install
    if ($MalformedResult.ExitCode -eq 0) {
        Fail-Test "install accepted malformed managed markers"
    }
    Assert-Contains ($MalformedResult.StdOut + $MalformedResult.StdErr) "Malformed OPCSkills reminder markers"
    if ([IO.File]::ReadAllText($AgentsFile) -ne "<!-- opc-skills-reminder:start -->`n") {
        Fail-Test "malformed-marker rejection changed the instructions file"
    }
    $Checkpoints.MalformedMarkers = $true

    $Readme = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "README.md"))
    Assert-Contains $Readme "configure-codex-reminder.ps1 install"
    Assert-Contains $Readme "只提醒，不自动执行"
    $Checkpoints.Readme = $true

    $MissingCheckpoints = @($Checkpoints.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
    if ($MissingCheckpoints.Count -ne 0) {
        Fail-Test "end-of-suite checkpoints were skipped: $($MissingCheckpoints -join ', ')"
    }
    if ($env:CODEX_HOME -ne $OriginalCodexHome) {
        Fail-Test "test changed CODEX_HOME in the parent PowerShell process"
    }
    Write-Host "END-OF-SUITE: OPCSkills PowerShell reminder tests passed (install, idempotency, status, uninstall, active override, malformed markers, unrelated content, README)."
}
finally {
    if ([IO.Directory]::Exists($TestRoot)) {
        [IO.Directory]::Delete($TestRoot, $true)
    }
}
