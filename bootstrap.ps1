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
        Write-Info "Installing aqua from GitHub releases..."
        # Download aqua release directly for windows
        $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'arm64' } else { 'amd64' }
        $aquaReleaseUrl = "https://github.com/aquaproj/aqua/releases/latest/download/aqua_windows_${arch}.zip"
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

# ── Link PowerShell Profiles for OneDrive / Redirected Documents ─────────────
$myDocs = [System.Environment]::GetFolderPath('MyDocuments')
if ($myDocs -and ($myDocs.TrimEnd('\/') -ne $homeDocs.TrimEnd('\/'))) {
    # Detect whether Documents is on an SMB / UNC share or a mapped network drive
    $isUnc = $myDocs.StartsWith('\\') -or ([System.Uri]::new($myDocs).IsUnc)
    $isNetworkDrive = $false
    if (-not $isUnc -and $myDocs.Length -ge 2 -and $myDocs[1] -eq ':') {
        try {
            $driveLetter = $myDocs.Substring(0, 1)
            $driveInfo = [System.IO.DriveInfo]::new($driveLetter)
            $isNetworkDrive = ($driveInfo.DriveType -eq [System.IO.DriveType]::Network)
        } catch {}
    }
    $isRemoteDocs = $isUnc -or $isNetworkDrive

    if ($isRemoteDocs) {
        Write-Step "Configuring Network-Redirected Documents (SMB/UNC: $myDocs)"
        Write-Info "NTFS junctions cannot be created across network shares, and remote scripts may be restricted."

        $trampolineSnippet = @'
# NREDF dotfiles profile fallback for network-redirected Documents
$nredfLocalProfile = Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path -LiteralPath $nredfLocalProfile) {
    . $nredfLocalProfile
}
'@.Trim()

        $targets = @()
        $posh7Dir = if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'PowerShell\7' } else { "C:\Program Files\PowerShell\7" }
        if (Test-Path -LiteralPath $posh7Dir) {
            $targets += Join-Path $posh7Dir "Microsoft.PowerShell_profile.ps1"
        } elseif (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
            $pwshDir = Split-Path -Parent (Get-Command pwsh.exe).Source
            $targets += Join-Path $pwshDir "Microsoft.PowerShell_profile.ps1"
        }
        $winPoshDir = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0'
        if (Test-Path -LiteralPath $winPoshDir) {
            $targets += Join-Path $winPoshDir "Microsoft.PowerShell_profile.ps1"
        }

        $needsInstall = $false
        foreach ($target in $targets) {
            if (-not (Test-Path -LiteralPath $target)) {
                $needsInstall = $true
                break
            } else {
                $content = Get-Content -LiteralPath $target -Raw -ErrorAction SilentlyContinue
                if ($content -notlike "*NREDF dotfiles profile fallback*") {
                    $needsInstall = $true
                    break
                }
            }
        }

        if (-not $needsInstall) {
            Write-Info "AllUsers profile trampoline is already installed."
        } else {
            Write-Info "Installing AllUsers profile trampoline to load local profiles..."
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if ($isAdmin) {
                try {
                    foreach ($target in $targets) {
                        $targetDir = Split-Path -Parent $target
                        if (-not (Test-Path -LiteralPath $targetDir)) {
                            New-Item -ItemType Directory -Path $targetDir -Force -ErrorAction Stop | Out-Null
                        }
                        if (Test-Path -LiteralPath $target) {
                            $content = Get-Content -LiteralPath $target -Raw -ErrorAction Stop
                            if ($content -notlike "*NREDF dotfiles profile fallback*") {
                                Add-Content -LiteralPath $target -Value "`n$trampolineSnippet`n" -Force -ErrorAction Stop
                            }
                        } else {
                            Set-Content -LiteralPath $target -Value "$trampolineSnippet`n" -Force -ErrorAction Stop
                        }
                        Write-Info "Configured: $target"
                    }
                } catch {
                    Write-Warn "Failed to configure AllUsers profile: $_"
                }
            } else {
                Write-Info "Requesting administrator elevation (UAC) to configure AllUsers profiles..."
                $encodedSnippet = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($trampolineSnippet))
                $targetsFormatted = ($targets | ForEach-Object { "'$_'" }) -join ','
                $elevatedScript = @"
`$targets = @($targetsFormatted)
`$snippet = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedSnippet'))
foreach (`$target in `$targets) {
    `$targetDir = Split-Path -Parent `$target
    if (-not (Test-Path -LiteralPath `$targetDir)) {
        New-Item -ItemType Directory -Path `$targetDir -Force -ErrorAction Stop | Out-Null
    }
    if (Test-Path -LiteralPath `$target) {
        `$content = Get-Content -LiteralPath `$target -Raw -ErrorAction Stop
        if (`$content -notlike '*NREDF dotfiles profile fallback*') {
            Add-Content -LiteralPath `$target -Value "`n`$snippet`n" -Force -ErrorAction Stop
        }
    } else {
        Set-Content -LiteralPath `$target -Value "`$snippet`n" -Force -ErrorAction Stop
    }
}
"@
                $encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($elevatedScript))
                $shellExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
                try {
                    $proc = Start-Process -FilePath $shellExe -ArgumentList "-NoProfile -NonInteractive -EncodedCommand $encodedCmd" -Verb RunAs -Wait -PassThru -ErrorAction Stop
                    if ($proc.ExitCode -eq 0) {
                        Write-Info "AllUsers profile trampoline successfully installed via elevated prompt."
                    } else {
                        Write-Warn "Elevated installation exited with code $($proc.ExitCode)."
                    }
                } catch {
                    Write-Warn "Elevation was declined or failed: $_"
                    Write-Info "To load your profile without admin rights, configure your Windows Terminal or VS Code profile command line:"
                    Write-Info "pwsh.exe -NoExit -Command `". '`$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'`""
                }
            }
        }
    } else {
        Write-Step "Configuring OneDrive / Local Redirected Documents ($myDocs)"
        $foldersToLink = @('PowerShell', 'WindowsPowerShell')
        foreach ($folder in $foldersToLink) {
            $src = Join-Path $homeDocs $folder
            $dst = Join-Path $myDocs $folder
            if (-not (Test-Path $src)) { continue }

            $isLinked = $false
            if (Test-Path $dst) {
                $item = Get-Item -LiteralPath $dst -Force
                if ($item.LinkType -and (@($item.Target) -contains $src)) {
                    $isLinked = $true
                }
            }

            if (-not $isLinked) {
                if (Test-Path $dst) {
                    $backup = "${dst}.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
                    Write-Info "Backing up existing $folder in OneDrive to $backup..."
                    # Preserve any custom Modules not present in source
                    $targetMods = Join-Path $dst "Modules"
                    $srcMods = Join-Path $src "Modules"
                    if ((Test-Path $targetMods) -and (-not (Test-Path $srcMods))) {
                        Copy-Item -Path $targetMods -Destination $srcMods -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    try {
                        Move-Item -Path $dst -Destination $backup -Force -ErrorAction Stop
                    } catch {
                        Write-Warn "Could not backup existing folder '$dst': $_"
                    }
                }
                Write-Info "Linking $dst -> $src..."
                try {
                    New-Item -ItemType Junction -Path $dst -Target $src -Force -ErrorAction Stop | Out-Null
                    Write-Info "Junction successfully created."
                } catch {
                    Write-Warn "Could not create junction: $_. Attempting symbolic link..."
                    try {
                        New-Item -ItemType SymbolicLink -Path $dst -Target $src -Force -ErrorAction Stop | Out-Null
                        Write-Info "Symbolic link successfully created."
                    } catch {
                        Write-Warn "Could not create symbolic link: $_"
                    }
                }
            } else {
                Write-Info "$folder is already linked to chezmoi."
            }
        }
    }
}

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

