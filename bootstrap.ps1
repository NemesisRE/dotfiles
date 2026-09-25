<#
.SYNOPSIS
    Bootstrap nredf dotfiles on a fresh Windows machine.

.DESCRIPTION
    Installs chezmoi, applies the dotfiles repository, sets up aqua and OpenSSH agent,
    and configures your PowerShell environment.

.EXAMPLE
    irm https://raw.githubusercontent.com/NemesisRE/dotfiles/main/bootstrap.ps1 | iex
#>

[CmdletBinding()]
param (
    [string]$DotfilesRepo = $(if ($env:DOTFILES_REPO) { $env:DOTFILES_REPO } else { "NemesisRE/dotfiles" })
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Gray
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    WARNING: $Message" -ForegroundColor Yellow
}

# ── Execution Policy Check ──────────────────────────────────────────────────
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -notin @('RemoteSigned', 'Unrestricted', 'Bypass')) {
    Write-Step "Setting execution policy to RemoteSigned for CurrentUser"
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

# ── Ensure local directories ────────────────────────────────────────────────
$localBin = Join-Path $HOME ".local\bin"
if (-not (Test-Path $localBin)) {
    New-Item -ItemType Directory -Path $localBin -Force | Out-Null
}
if ($env:PATH -notlike "*$localBin*") {
    $env:PATH = "$localBin;$env:PATH"
}

$homeDocs = Join-Path $HOME "Documents"
if (-not (Test-Path $homeDocs)) {
    New-Item -ItemType Directory -Path $homeDocs -Force | Out-Null
}

# ── Install / Verify chezmoi ─────────────────────────────────────────────────
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Step "Installing chezmoi"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Installing chezmoi via winget..."
        winget install --id twpayne.chezmoi --silent --accept-source-agreements --accept-package-agreements
    } else {
        Write-Info "Installing chezmoi via get.chezmoi.io ps1..."
        & ([scriptblock]::Create((Invoke-RestMethod -Uri 'https://get.chezmoi.io/ps1'))) -b $localBin
    }

    # Refresh PATH in current session
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Warn "chezmoi not found in PATH after install. Falling back to explicit check in $localBin"
    if (Test-Path (Join-Path $localBin "chezmoi.exe")) {
        $chezmoiCmd = Join-Path $localBin "chezmoi.exe"
    } else {
        throw "chezmoi installation failed or executable not located."
    }
} else {
    $chezmoiCmd = "chezmoi"
}

# ── Install / Verify aqua ────────────────────────────────────────────────────
$aquaBin = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "aquaproj-aqua\bin" } else { Join-Path $HOME ".local\share\aquaproj-aqua\bin" }
if ($env:PATH -notlike "*$aquaBin*") {
    $env:PATH = "$aquaBin;$env:PATH"
}
if (-not (Get-Command aqua -ErrorAction SilentlyContinue)) {
    Write-Step "Installing aqua CLI tool manager"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Installing aqua via winget..."
        winget install --id aquaproj.aqua --silent --accept-source-agreements --accept-package-agreements
    } else {
        Write-Info "Installing aqua from GitHub releases (pinned, checksum-verified)..."
        # Pinned release + SHA-256 instead of `releases/latest`. This file is fetched raw
        # before chezmoi exists, so it cannot read home/.chezmoidata/aqua-bootstrap.yaml;
        # these literals must match it (`.github/scripts/pins.py verify` enforces that).
        $aquaVersion = "v2.63.0"
        $aquaSha256 = @{
            amd64 = "8133527645ead6dc07dbfb70c7760c1372acd0c9895a007d038fca6890c2861f"
            arm64 = "b6be9228ca7a9fd4dc5df2f3df92ca21af1d704ad0defb3de447e5d0c26bc9a4"
        }
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'arm64' } else { 'amd64' }
        $aquaReleaseUrl = "https://github.com/aquaproj/aqua/releases/download/${aquaVersion}/aqua_windows_${arch}.zip"
        $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) "aqua.zip"
        $tmpExtract = Join-Path ([System.IO.Path]::GetTempPath()) "aqua_extract"
        try {
            Invoke-WebRequest -Uri $aquaReleaseUrl -OutFile $tmpZip
            $actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $tmpZip).Hash
            if ($actualSha256 -ne $aquaSha256[$arch]) {
                throw "aqua $aquaVersion checksum mismatch (expected $($aquaSha256[$arch]), got $actualSha256); refusing to install"
            }
            Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force
            Copy-Item -Path (Join-Path $tmpExtract "aqua.exe") -Destination (Join-Path $localBin "aqua.exe") -Force
        } catch {
            Write-Warn "Could not install aqua from GitHub releases: $_"
        } finally {
            Remove-Item -Path $tmpZip, $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ── Apply Dotfiles with chezmoi ──────────────────────────────────────────────
Write-Step "Applying dotfiles ($DotfilesRepo)"
& $chezmoiCmd init --apply $DotfilesRepo

# ── PowerShell Profile Linking for OneDrive / Redirected Documents ───────
# Deliberately NOT done here. `chezmoi init --apply` above runs
# .chezmoiscripts/run_onchange_after_windows_sync-profiles.ps1, which owns this
# logic. This file used to carry a second ~170-line copy of it; the two had
# already drifted (only the chezmoi one created a missing Documents root before
# creating the junction). One copy, one behaviour.

# ── Link Aqua Managed Tools ──────────────────────────────────────────────────
if (Get-Command aqua -ErrorAction SilentlyContinue) {
    Write-Step "Linking aqua-managed tools"
    $aquaConfig = Join-Path $HOME ".config\aquaproj-aqua\aqua.yaml"
    $aquaPolicy = Join-Path $HOME ".config\aquaproj-aqua\aqua-policy.yaml"
    if (Test-Path $aquaConfig) {
        $env:AQUA_GLOBAL_CONFIG = $aquaConfig
        $env:AQUA_CONFIG = $aquaConfig
        [System.Environment]::SetEnvironmentVariable("AQUA_GLOBAL_CONFIG", $aquaConfig, [System.EnvironmentVariableTarget]::User)
    }
    if (Test-Path $aquaPolicy) {
        $env:AQUA_POLICY_CONFIG = $aquaPolicy
        [System.Environment]::SetEnvironmentVariable("AQUA_POLICY_CONFIG", $aquaPolicy, [System.EnvironmentVariableTarget]::User)
    }
    if ($env:PATH -notlike "*$aquaBin*") {
        $env:PATH = "$aquaBin;$env:PATH"
    }

    # Ensure aqua bin is in User PATH
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
    if ($userPath -notlike "*$aquaBin*") {
        $newUserPath = if ($userPath) { "$aquaBin;$userPath" } else { $aquaBin }
        [System.Environment]::SetEnvironmentVariable("PATH", $newUserPath, [System.EnvironmentVariableTarget]::User)
    }

    # Configure Microsoft Defender exclusions to prevent file locking issues during package downloads
    if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Info "Configuring Microsoft Defender exclusions for aqua..."
        Add-MpPreference -ExclusionProcess "aqua.exe" -ErrorAction SilentlyContinue
        $aquaRoot = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "aquaproj-aqua" } else { Join-Path $HOME ".local\share\aquaproj-aqua" }
        Add-MpPreference -ExclusionPath $aquaRoot -ErrorAction SilentlyContinue
    }

    & aqua install -a -l
}

# ── Configure Yazi File MIME-type Detector (Git for Windows) ─────────────────
$yaziFileCandidates = @(
    $env:YAZI_FILE_ONE
    (Join-Path $env:ProgramFiles "Git\usr\bin\file.exe")
    (Join-Path ${env:ProgramFiles(x86)} "Git\usr\bin\file.exe")
    (Join-Path $env:LOCALAPPDATA "Programs\Git\usr\bin\file.exe")
    "C:\Program Files\Git\usr\bin\file.exe"
)
if (Get-Command git -ErrorAction SilentlyContinue) {
    try {
        $gitDir = Split-Path (Split-Path (Get-Command git).Source)
        $yaziFileCandidates += (Join-Path $gitDir "usr\bin\file.exe")
    } catch {}
}
foreach ($candidate in $yaziFileCandidates) {
    if ($candidate -and (Test-Path $candidate)) {
        $env:YAZI_FILE_ONE = $candidate
        [System.Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $candidate, [System.EnvironmentVariableTarget]::User)
        Write-Info "Configured YAZI_FILE_ONE: $candidate"
        break
    }
}

# ── Configure Yazi Config Directory & AppData Junction ───────────────────────
$yaziConfigDir = "$HOME\.config\yazi"
$env:YAZI_CONFIG_HOME = $yaziConfigDir
[System.Environment]::SetEnvironmentVariable("YAZI_CONFIG_HOME", $yaziConfigDir, [System.EnvironmentVariableTarget]::User)
Write-Info "Configured YAZI_CONFIG_HOME: $yaziConfigDir"

$yaziAppDataDir = Join-Path $env:APPDATA "yazi"
$yaziAppDataConfig = Join-Path $yaziAppDataDir "config"
if (-not (Test-Path $yaziAppDataConfig)) {
    if (-not (Test-Path $yaziAppDataDir)) {
        New-Item -ItemType Directory -Path $yaziAppDataDir -Force -ErrorAction SilentlyContinue | Out-Null
    }
    New-Item -ItemType Junction -Path $yaziAppDataConfig -Target $yaziConfigDir -Force -ErrorAction SilentlyContinue | Out-Null
}

# ── Normalize HOME Environment Variable ──────────────────────────────────────
if (-not $env:HOME) { $env:HOME = $HOME }
[System.Environment]::SetEnvironmentVariable("HOME", $HOME, [System.EnvironmentVariableTarget]::User)
Write-Info "Configured HOME: $HOME"

# ── Configure SSH Agent (Bitwarden / OpenSSH) ─────────────────────────────────
Write-Step "Checking SSH Agent"
$bwPipe = "\\.\pipe\openssh-ssh-agent"
if (Test-Path $bwPipe) {
    Write-Info "Bitwarden SSH Agent detected ($bwPipe)."
    $env:SSH_AUTH_SOCK = $bwPipe
} else {
    try {
        $sshAgentService = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
        if ($sshAgentService) {
            if ($sshAgentService.StartType -ne 'Automatic') {
                Set-Service -Name ssh-agent -StartupType Automatic -ErrorAction SilentlyContinue
            }
            if ($sshAgentService.Status -ne 'Running') {
                Start-Service -Name ssh-agent -ErrorAction SilentlyContinue
            }
            Write-Info "Windows OpenSSH Agent service configured and running."
        }
    } catch {
        Write-Warn "Could not configure Windows ssh-agent service automatically."
    }
}


# ── Done ─────────────────────────────────────────────────────────────────────
Write-Step "Done!"
Write-Info "Open a new PowerShell terminal to activate your new shell environment."
Write-Info ""
Write-Info "Useful commands:"
Write-Info "  chezmoi update                       - pull latest dotfiles and re-apply"
Write-Info "  chezmoi edit Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
Write-Info "  aqua install                         - install/update all managed CLI tools"

