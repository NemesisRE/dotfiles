<#
.SYNOPSIS
    Bootstrap nredf dotfiles on a fresh Windows machine.

.DESCRIPTION
    Installs chezmoi, applies the dotfiles repository, sets up aqua and OpenSSH agent,
    and configures your PowerShell environment.

.EXAMPLE
    irm https://raw.githubusercontent.com/NemesisRE/chezmoi/main/bootstrap.ps1 | iex
#>

[CmdletBinding()]
param (
    [string]$DotfilesRepo = $(if ($env:DOTFILES_REPO) { $env:DOTFILES_REPO } else { "NemesisRE/chezmoi" })
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
if (-not (Get-Command aqua -ErrorAction SilentlyContinue)) {
    Write-Step "Installing aqua CLI tool manager"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Installing aqua via winget..."
        winget install --id aquaproj.aqua --silent --accept-source-agreements --accept-package-agreements
    } else {
        Write-Info "Installing aqua via aqua-installer..."
        $aquaInstallerUrl = "https://raw.githubusercontent.com/aquaproj/aqua-installer/v4.0.2/aqua-installer"
        # Download aqua release directly for windows
        $aquaReleaseUrl = "https://github.com/aquaproj/aqua/releases/latest/download/aqua_windows_amd64.zip"
        $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) "aqua.zip"
        $tmpExtract = Join-Path ([System.IO.Path]::GetTempPath()) "aqua_extract"
        Invoke-WebRequest -Uri $aquaReleaseUrl -OutFile $tmpZip
        Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force
        Copy-Item -Path (Join-Path $tmpExtract "aqua.exe") -Destination (Join-Path $localBin "aqua.exe") -Force
        Remove-Item -Path $tmpZip, $tmpExtract -Recurse -Force
    }
}

# ── Apply Dotfiles with chezmoi ──────────────────────────────────────────────
Write-Step "Applying dotfiles ($DotfilesRepo)"
& $chezmoiCmd init --apply $DotfilesRepo

# ── Link Aqua Managed Tools ──────────────────────────────────────────────────
if (Get-Command aqua -ErrorAction SilentlyContinue) {
    Write-Step "Linking aqua-managed tools"
    & aqua install -a -l
}

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

# ── Git Identity Check ───────────────────────────────────────────────────────
$gitEmail = git config --global user.email 2>$null
if (-not $gitEmail) {
    Write-Step "Git identity"
    Write-Warn "Git identity not set. Please configure your Git name and email:"
    Write-Info "  git config --global user.name  'Your Name'"
    Write-Info "  git config --global user.email 'you@example.com'"
}

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Step "Done!"
Write-Info "Open a new PowerShell terminal to activate your new shell environment."
Write-Info ""
Write-Info "Useful commands:"
Write-Info "  chezmoi update                       - pull latest dotfiles and re-apply"
Write-Info "  chezmoi edit ~/.config/powershell/Microsoft.PowerShell_profile.ps1"
Write-Info "  aqua install                         - install/update all managed CLI tools"

