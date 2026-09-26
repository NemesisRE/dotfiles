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

$homeDocs = Join-Path $HOME "Documents"
if (-not (Test-Path $homeDocs)) {
    New-Item -ItemType Directory -Path $homeDocs -Force | Out-Null
}

# Rebuild PATH from Machine + User so tools a winget install just added resolve in
# this session, keeping this session's own entries (e.g. $localBin above) first.
# (Windows PowerShell 5.1 compatible: this file runs via `irm | iex`.)
function Import-SystemPath {
    $seen = @{}
    $entries = @()
    $all = @($env:PATH -split ';') +
        @([System.Environment]::GetEnvironmentVariable("Path", "Machine") -split ';') +
        @([System.Environment]::GetEnvironmentVariable("Path", "User") -split ';')
    foreach ($entry in $all) {
        if (-not $entry) { continue }
        $key = $entry.TrimEnd('\').ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $entries += $entry
        }
    }
    $env:PATH = $entries -join ';'
}

# winget exits non-zero when there is nothing to do. Codes from
# https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md
function Test-WingetSuccess {
    param([int]$Code)
    # Same code list as run_onchange_before_windows_install-packages.ps1.tmpl's
    # $wingetNothingToDo/$wingetRebootToFinish — kept in sync by hand since this
    # file can't include that template.
    return ($Code -eq 0) -or (@(
            -1978335189 # 0x8A15002B UPDATE_NOT_APPLICABLE
            -1978335135 # 0x8A150061 PACKAGE_ALREADY_INSTALLED
            -1978334963 # 0x8A15010D INSTALL_ALREADY_INSTALLED
            -1978335095 # 0x8A150089 FONT_ALREADY_INSTALLED
            -1978334967 # 0x8A150109 INSTALL_REBOOT_REQUIRED_TO_FINISH
        ) -contains $Code)
}

# ── Install / Verify PowerShell 7 ────────────────────────────────────────────
# chezmoi runs every .ps1 hook under pwsh ([interpreters.ps1] in .chezmoi.toml.tmpl),
# because several use PowerShell 7 syntax. The hook that installs PowerShell 7 is
# itself one of them, so on a fresh machine it has to be here, before the first apply.
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Write-Step "Installing PowerShell 7"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "PowerShell 7 (pwsh) is required and winget is unavailable. Install it from https://aka.ms/powershell and re-run this script."
    }
    winget install --id Microsoft.PowerShell -e --accept-source-agreements --accept-package-agreements
    if (-not (Test-WingetSuccess $LASTEXITCODE)) {
        Write-Warn ("winget install Microsoft.PowerShell exited with code {0} (0x{0:X8})." -f $LASTEXITCODE)
    }
    Import-SystemPath
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        throw "PowerShell 7 (pwsh) is still not on PATH; chezmoi cannot run its hooks without it. Install it (winget install Microsoft.PowerShell), open a new terminal and re-run this script."
    }
}

# ── Install / Verify chezmoi ─────────────────────────────────────────────────
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Step "Installing chezmoi"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Installing chezmoi via winget..."
        # Not version-pinned: the repo has no chezmoi pin. winget checks the installer
        # against the SHA-256 in its reviewed manifest.
        winget install --id twpayne.chezmoi -e --silent --accept-source-agreements --accept-package-agreements
        if (-not (Test-WingetSuccess $LASTEXITCODE)) {
            Write-Warn ("winget install twpayne.chezmoi exited with code {0} (0x{0:X8})." -f $LASTEXITCODE)
        }
    } else {
        Write-Info "Installing chezmoi via get.chezmoi.io ps1..."
        & ([scriptblock]::Create((Invoke-RestMethod -Uri 'https://get.chezmoi.io/ps1'))) -b $localBin
    }

    Import-SystemPath
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

# Pinned release + SHA-256, for winget and the zip fallback alike. This file is fetched
# raw before chezmoi exists, so it cannot read home/.chezmoidata/aqua-bootstrap.yaml;
# these literals must match it (`.github/scripts/pins.py verify` enforces that).
$aquaVersion = "v2.63.0"
$aquaSha256 = @{
    amd64 = "8133527645ead6dc07dbfb70c7760c1372acd0c9895a007d038fca6890c2861f"
    arm64 = "b6be9228ca7a9fd4dc5df2f3df92ca21af1d704ad0defb3de447e5d0c26bc9a4"
}
if (-not (Get-Command aqua -ErrorAction SilentlyContinue)) {
    Write-Step "Installing aqua $aquaVersion"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Installing aqua via winget..."
        $aquaWingetVersion = $aquaVersion.TrimStart('v')
        winget install --id aquaproj.aqua -e --version $aquaWingetVersion --silent --accept-source-agreements --accept-package-agreements
        if (-not (Test-WingetSuccess $LASTEXITCODE)) {
            Write-Warn ("winget install aquaproj.aqua exited with code {0} (0x{0:X8}); trying the pinned GitHub release." -f $LASTEXITCODE)
        }
        Import-SystemPath
    }
    if (-not (Get-Command aqua -ErrorAction SilentlyContinue)) {
        Write-Info "Installing aqua from GitHub releases (pinned, checksum-verified)..."
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'arm64' } else { 'amd64' }
        $aquaReleaseUrl = "https://github.com/aquaproj/aqua/releases/download/${aquaVersion}/aqua_windows_${arch}.zip"
        $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) "aqua.zip"
        $tmpExtract = Join-Path ([System.IO.Path]::GetTempPath()) "aqua_extract"
        try {
            Invoke-WebRequest -Uri $aquaReleaseUrl -OutFile $tmpZip -UseBasicParsing
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
if ($LASTEXITCODE -ne 0) {
    Write-Warn "chezmoi init --apply exited with code $LASTEXITCODE. Fix the error above, then run: chezmoi apply"
}

# ── PowerShell Profile Linking for OneDrive / Redirected Documents ───────
# Deliberately NOT done here. `chezmoi init --apply` above runs
# .chezmoiscripts/run_onchange_after_windows_sync-profiles.ps1, which owns this
# logic. This file used to carry a second ~170-line copy of it; the two had
# already drifted (only the chezmoi one created a missing Documents root before
# creating the junction). One copy, one behaviour.

# ── aqua linking, yazi and HOME environment ──────────────────────────────────
# Also deliberately NOT done here any more: `chezmoi init --apply` above runs the
# hooks that own them on the first apply (run_once_before_windows_install-tools and
# run_onchange_after_windows_aqua for aqua; run_onchange_after_windows_yazi-plugins
# with .chezmoitemplates/yazi-env.ps1 for yazi and HOME). This file carried a third
# copy of each.

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
