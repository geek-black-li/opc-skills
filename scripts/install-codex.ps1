param(
    [ValidateSet("install", "status", "uninstall")]
    [string]$Action = "install",

    [Parameter(DontShow = $true)]
    [switch]$TestFailAfterLinkCreate
)

$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TargetParent = if ([string]::IsNullOrWhiteSpace($env:OPCSKILLS_SKILLS_HOME)) {
    Join-Path $HOME ".agents\skills"
}
else {
    $env:OPCSKILLS_SKILLS_HOME
}

$Entries = @(
    [pscustomobject]@{
        Name = "opc-skills"
        Source = Join-Path $RepositoryRoot "adapters\codex\opc-skills"
        Target = Join-Path $TargetParent "opc-skills"
    }
)

foreach ($Entry in $Entries) {
    $SourceSkill = Join-Path $Entry.Source "SKILL.md"
    if (-not (Test-Path -LiteralPath $SourceSkill -PathType Leaf)) {
        throw "Codex entrypoint not found: $SourceSkill"
    }
}

function Test-ResolvedPathsEqual {
    param(
        [string]$Left,
        [string]$Right
    )

    $Comparison = if ($env:OS -eq "Windows_NT") {
        [StringComparison]::OrdinalIgnoreCase
    }
    else {
        [StringComparison]::Ordinal
    }
    return [string]::Equals($Left, $Right, $Comparison)
}

function Get-TargetState {
    param([pscustomobject]$Entry)

    $Item = Get-Item -LiteralPath $Entry.Target -Force -ErrorAction SilentlyContinue
    if ($null -eq $Item) {
        return "absent"
    }
    if (-not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        return "conflict"
    }

    try {
        $LinkTarget = $Item.Target
        if ($LinkTarget -is [array]) {
            $LinkTarget = $LinkTarget[0]
        }
        if ([string]::IsNullOrWhiteSpace($LinkTarget)) {
            return "conflict"
        }
        if (-not [IO.Path]::IsPathRooted($LinkTarget)) {
            $LinkTarget = Join-Path (Split-Path -Parent $Entry.Target) $LinkTarget
        }
        $ResolvedTarget = (Resolve-Path -LiteralPath $LinkTarget).Path.TrimEnd("\", "/")
        $ResolvedSource = (Resolve-Path -LiteralPath $Entry.Source).Path.TrimEnd("\", "/")
        if (Test-ResolvedPathsEqual $ResolvedTarget $ResolvedSource) {
            return "current"
        }
    }
    catch {
        return "conflict"
    }
    return "conflict"
}

function Get-PreflightStates {
    return @($Entries | ForEach-Object {
        [pscustomobject]@{
            Entry = $_
            State = Get-TargetState $_
        }
    })
}

function Assert-NoConflicts {
    param([object[]]$States)

    $Conflicts = @($States | Where-Object { $_.State -eq "conflict" })
    if ($Conflicts.Count -gt 0) {
        foreach ($Conflict in $Conflicts) {
            Write-Error "Refusing to modify existing path: $($Conflict.Entry.Target)" -ErrorAction Continue
        }
        throw "No entrypoints were changed."
    }
}

function Remove-CurrentEntrypointLink {
    param([pscustomobject]$Entry)

    if ((Get-TargetState $Entry) -ne "current") {
        throw "Refusing to remove entrypoint that is no longer owned by this installation: $($Entry.Target)"
    }

    $Item = Get-Item -LiteralPath $Entry.Target -Force -ErrorAction SilentlyContinue
    if ($null -eq $Item -or -not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Refusing link-only removal for a non-reparse path: $($Entry.Target)"
    }

    [IO.Directory]::Delete($Entry.Target)
}

function Write-EntryStates {
    param([object[]]$States)
    foreach ($State in $States) {
        Write-Host "$($State.Entry.Name): $($State.State) ($($State.Entry.Target))"
    }
}

switch ($Action) {
    "install" {
        $States = Get-PreflightStates
        Assert-NoConflicts $States

        New-Item -ItemType Directory -Path $TargetParent -Force | Out-Null
        $Created = [Collections.Generic.List[object]]::new()
        try {
            foreach ($State in $States) {
                if ($State.State -ne "absent") {
                    continue
                }
                $LinkType = if ($env:OS -eq "Windows_NT") { "Junction" } else { "SymbolicLink" }
                New-Item -ItemType $LinkType -Path $State.Entry.Target -Target $State.Entry.Source | Out-Null
                $Created.Add($State.Entry)
                if ($TestFailAfterLinkCreate) {
                    throw "injected post-create failure for $($State.Entry.Name)"
                }
            }
        }
        catch {
            for ($Index = $Created.Count - 1; $Index -ge 0; $Index--) {
                $CreatedEntry = $Created[$Index]
                if ((Get-TargetState $CreatedEntry) -eq "current") {
                    Remove-CurrentEntrypointLink $CreatedEntry
                }
            }
            throw "Installation failed; newly created entrypoints were rolled back. $($_.Exception.Message)"
        }

        Write-Host "OPCSkills installed successfully."
        Write-EntryStates @($Entries | ForEach-Object {
            [pscustomobject]@{ Entry = $_; State = "current" }
        })
        Write-Host "Repository: $RepositoryRoot"
        Write-Host 'Restart Codex if needed, then run: $opc-skills 查看仓库状态'
        Write-Host 'Optional completion reminder: powershell -ExecutionPolicy Bypass -File .\scripts\configure-codex-reminder.ps1 install'
    }

    "status" {
        $States = Get-PreflightStates
        Write-EntryStates $States
        if (@($States | Where-Object { $_.State -ne "current" }).Count -eq 0) {
            exit 0
        }
        exit 1
    }

    "uninstall" {
        $States = Get-PreflightStates
        Assert-NoConflicts $States
        foreach ($State in $States) {
            if ($State.State -eq "current") {
                Remove-CurrentEntrypointLink $State.Entry
            }
        }
        Write-Host "OPCSkills Codex entrypoint removed."
        Write-Host "Repository preserved: $RepositoryRoot"
    }
}
