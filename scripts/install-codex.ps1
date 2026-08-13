param(
    [ValidateSet("install", "status", "uninstall")]
    [string]$Action = "install"
)

$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SourceDir = Join-Path $RepositoryRoot "adapters\codex\zx-skills"
$SourceSkill = Join-Path $SourceDir "SKILL.md"
$TargetParent = Join-Path $HOME ".agents\skills"
$TargetDir = Join-Path $TargetParent "zx-skills"

if (-not (Test-Path -LiteralPath $SourceSkill -PathType Leaf)) {
    throw "Codex entrypoint not found: $SourceSkill"
}

function Test-CurrentInstall {
    $Item = Get-Item -LiteralPath $TargetDir -Force -ErrorAction SilentlyContinue
    if ($null -eq $Item) {
        return $false
    }

    if (-not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        return $false
    }

    try {
        $LinkTarget = $Item.Target
        if ($LinkTarget -is [array]) {
            $LinkTarget = $LinkTarget[0]
        }
        if (-not [IO.Path]::IsPathRooted($LinkTarget)) {
            $LinkTarget = Join-Path $TargetParent $LinkTarget
        }
        $ResolvedTarget = (Resolve-Path -LiteralPath $LinkTarget).Path.TrimEnd("\", "/")
        $ResolvedSource = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd("\", "/")
        return $ResolvedTarget -eq $ResolvedSource
    }
    catch {
        return $false
    }
}

function Test-TargetExists {
    return $null -ne (Get-Item -LiteralPath $TargetDir -Force -ErrorAction SilentlyContinue)
}

switch ($Action) {
    "install" {
        New-Item -ItemType Directory -Path $TargetParent -Force | Out-Null

        if (Test-CurrentInstall) {
            Write-Host "ZXSkills is already installed."
            Write-Host "Codex entrypoint: $TargetDir"
            Write-Host "Repository: $RepositoryRoot"
            exit 0
        }

        if (Test-TargetExists) {
            throw "Refusing to overwrite existing path: $TargetDir"
        }

        if ($env:OS -eq "Windows_NT") {
            $LinkType = "Junction"
        }
        else {
            $LinkType = "SymbolicLink"
        }
        New-Item -ItemType $LinkType -Path $TargetDir -Target $SourceDir | Out-Null
        Write-Host "ZXSkills installed successfully."
        Write-Host "Codex entrypoint: $TargetDir"
        Write-Host "Repository: $RepositoryRoot"
        Write-Host 'Restart Codex if needed, then run: $zx-skills 查看仓库状态'
    }

    "status" {
        if (Test-CurrentInstall) {
            Write-Host "ZXSkills is installed."
            Write-Host "Codex entrypoint: $TargetDir"
            Write-Host "Repository: $RepositoryRoot"
            exit 0
        }

        if (Test-TargetExists) {
            Write-Error "ZXSkills is not installed from this repository. Another path exists at: $TargetDir"
            exit 1
        }

        Write-Error "ZXSkills is not installed. Expected entrypoint: $TargetDir"
        exit 1
    }

    "uninstall" {
        if (Test-CurrentInstall) {
            Remove-Item -LiteralPath $TargetDir -Force
            Write-Host "ZXSkills Codex entrypoint removed."
            Write-Host "Repository preserved: $RepositoryRoot"
            exit 0
        }

        if (Test-TargetExists) {
            throw "Refusing to remove a path not installed from this repository: $TargetDir"
        }

        Write-Host "ZXSkills is not installed; nothing changed."
    }
}
