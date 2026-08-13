param(
    [ValidateSet("install", "status", "uninstall")]
    [string]$Action = "install"
)

$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TemplatePath = Join-Path $RepositoryRoot "templates\codex-agents-reminder.md"
$CodexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    Join-Path $HOME ".codex"
}
else {
    $env:CODEX_HOME
}
$AgentsFile = Join-Path $CodexHome "AGENTS.md"
$OverrideFile = Join-Path $CodexHome "AGENTS.override.md"
$StartMarker = "<!-- zx-skills-reminder:start -->"
$EndMarker = "<!-- zx-skills-reminder:end -->"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
    throw "Reminder template not found: $TemplatePath"
}

function Get-FileContent {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ""
    }
    return [IO.File]::ReadAllText($Path)
}

function Get-MarkerCount {
    param(
        [string]$Content,
        [string]$Marker
    )

    return ([regex]::Matches($Content, "(?m)^" + [regex]::Escape($Marker) + "\r?$")).Count
}

function Assert-ValidMarkers {
    param([string]$Path)

    $Content = Get-FileContent $Path
    $StartCount = Get-MarkerCount $Content $StartMarker
    $EndCount = Get-MarkerCount $Content $EndMarker
    if ($StartCount -ne $EndCount -or $StartCount -gt 1) {
        throw "Malformed ZXSkills reminder markers in $Path; fix them manually before retrying."
    }
}

function Test-ManagedBlock {
    param([string]$Path)

    $Content = Get-FileContent $Path
    return (Get-MarkerCount $Content $StartMarker) -eq 1
}

function Remove-ManagedBlock {
    param([string]$Path)

    if (-not (Test-ManagedBlock $Path)) {
        return
    }

    $Lines = (Get-FileContent $Path) -split "\r?\n"
    $KeptLines = [Collections.Generic.List[string]]::new()
    $Skipping = $false
    foreach ($Line in $Lines) {
        if ($Line -eq $StartMarker) {
            $Skipping = $true
            continue
        }
        if ($Line -eq $EndMarker) {
            $Skipping = $false
            continue
        }
        if (-not $Skipping) {
            $KeptLines.Add($Line)
        }
    }

    while ($KeptLines.Count -gt 0 -and [string]::IsNullOrEmpty($KeptLines[$KeptLines.Count - 1])) {
        $KeptLines.RemoveAt($KeptLines.Count - 1)
    }

    $Result = $KeptLines -join [Environment]::NewLine
    if ($Result.Length -gt 0) {
        $Result += [Environment]::NewLine
    }
    [IO.File]::WriteAllText($Path, $Result, $Utf8NoBom)
}

function Add-ReminderTemplate {
    param([string]$Path)

    $Existing = Get-FileContent $Path
    $Existing = $Existing.TrimEnd("`r", "`n")
    $Template = (Get-FileContent $TemplatePath).TrimEnd("`r", "`n")
    $Result = if ($Existing.Length -gt 0) {
        $Existing + [Environment]::NewLine + [Environment]::NewLine + $Template + [Environment]::NewLine
    }
    else {
        $Template + [Environment]::NewLine
    }
    [IO.File]::WriteAllText($Path, $Result, $Utf8NoBom)
}

$OverrideContent = Get-FileContent $OverrideFile
$ActiveFile = if (-not [string]::IsNullOrWhiteSpace($OverrideContent)) { $OverrideFile } else { $AgentsFile }
Assert-ValidMarkers $AgentsFile
Assert-ValidMarkers $OverrideFile

switch ($Action) {
    "install" {
        New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null

        if ($ActiveFile -eq $OverrideFile -and (Test-ManagedBlock $AgentsFile)) {
            Remove-ManagedBlock $AgentsFile
        }
        elseif ($ActiveFile -eq $AgentsFile -and (Test-ManagedBlock $OverrideFile)) {
            Remove-ManagedBlock $OverrideFile
        }

        if (-not (Test-Path -LiteralPath $ActiveFile)) {
            New-Item -ItemType File -Path $ActiveFile -Force | Out-Null
        }
        Remove-ManagedBlock $ActiveFile
        Add-ReminderTemplate $ActiveFile

        Write-Host "ZXSkills completion reminder configured."
        Write-Host "Global Codex instructions: $ActiveFile"
        Write-Host "Mode: remind only; ZXSkills will not run or modify files automatically."
        Write-Host "Start a new Codex task to load the updated global instructions."
    }

    "status" {
        if (Test-ManagedBlock $ActiveFile) {
            Write-Host "ZXSkills completion reminder is configured."
            Write-Host "Global Codex instructions: $ActiveFile"
            exit 0
        }

        $InactiveFile = if ($ActiveFile -eq $OverrideFile) { $AgentsFile } else { $OverrideFile }
        if (Test-ManagedBlock $InactiveFile) {
            Write-Error "ZXSkills reminder exists in an inactive global instructions file: $InactiveFile. Run this script with install to move it to $ActiveFile."
            exit 1
        }

        Write-Error "ZXSkills completion reminder is not configured. Expected global Codex instructions: $ActiveFile"
        exit 1
    }

    "uninstall" {
        $Removed = $false
        if (Test-ManagedBlock $AgentsFile) {
            Remove-ManagedBlock $AgentsFile
            $Removed = $true
        }
        if (Test-ManagedBlock $OverrideFile) {
            Remove-ManagedBlock $OverrideFile
            $Removed = $true
        }

        if ($Removed) {
            Write-Host "ZXSkills completion reminder removed."
            Write-Host "Other global Codex instructions were preserved."
        }
        else {
            Write-Host "ZXSkills completion reminder is not configured; nothing changed."
        }
    }
}
