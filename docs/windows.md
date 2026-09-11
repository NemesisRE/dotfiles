# Windows Setup & Optimization Guide (HOWTO)

This guide walks you through setting up, configuring, and optimizing your Windows environment with **NREDF dotfiles**, **chezmoi**, **PowerShell 7**, and **aqua**.

---

## 🚀 Quick Install (One-Liner)

Open **PowerShell** (run as Administrator for service and package setups) and run:

```powershell
irm https://raw.githubusercontent.com/NemesisRE/chezmoi/main/bootstrap.ps1 | iex
```

Or using chezmoi directly:

```powershell
# 1. Install chezmoi
winget install twpayne.chezmoi

# 2. Initialize and apply dotfiles
chezmoi init --apply NemesisRE/chezmoi

# 3. Link managed CLI tools
aqua install -a -l
```

---

## 📋 Prerequisites & Recommended Tooling

For the best experience on Windows, install the following packages via `winget`:

```powershell
# Modern Shell & Terminal
winget install Microsoft.PowerShell
winget install Microsoft.WindowsTerminal

# Version Control
winget install Git.Git

# Recommended Default Font: FiraMono Nerd Font (Mono)
# You can install via winget or download from https://www.nerdfonts.com
winget install DEVCOM.FiraCodeFont
# Or install FiraMono NF zip from github.com/ryanoasis/nerd-fonts
```

> [!TIP]
> In Windows Terminal Settings (`Ctrl+,`) &rarr; **Defaults** &rarr; **Appearance** &rarr; **Font face**, set the font to **FiraMono Nerd Font Mono** (or **FiraMono Nerd Font**) to match kitty terminal.

---

## 🔑 SSH & Git Signing Setup (Bitwarden SSH Agent)

### 1. Configure Bitwarden as SSH Agent on Windows

Bitwarden Desktop includes a built-in SSH Agent:
1. Open Bitwarden Desktop &rarr; **Settings** &rarr; **SSH Agent**.
2. Check **Enable SSH Agent**.
3. Under Windows, Bitwarden exposes the OpenSSH named pipe: `\\.\pipe\openssh-ssh-agent`.
4. Our PowerShell profile automatically sets `$env:SSH_AUTH_SOCK = "\\.\pipe\openssh-ssh-agent"`.

### 2. Configure Git Commit Signing with SSH Key

With Bitwarden SSH Agent active, Git uses your SSH key to sign commits seamlessly:

```powershell
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global user.signingkey "$env:USERPROFILE\.ssh\id_ed25519.pub"  # Or your public key string
git config --global gpg.format ssh
git config --global commit.gpgsign true
```

Windows OpenSSH client and Git will automatically query Bitwarden for signing authorization without needing external GPG daemons!

---

## ⚙️ PowerShell & Oh-My-Posh Integration

### Profile Structure

On Windows, chezmoi deploys your profile and dotfiles directly to:
- **PowerShell 7+**: `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` (along with `Aliases.ps1`, `Defaults.ps1`, `Modules.ps1`, etc.)
- **Windows PowerShell 5.1**: `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

Windows PowerShell 5.1 automatically dot-sources the configuration from `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`. On Linux and macOS, `~/.config/powershell` is symlinked to `~/Documents/PowerShell`.

### Key Features Included
- **Atuin**: End-to-end encrypted, searchable shell history (`Ctrl+r`) synchronized across your machines.
- **PSReadLine**: Predictive IntelliSense based on history, Vi exit, custom word movement.
- **PSFzf**: Fuzzy search integration with `Ctrl+t` (files) and `Ctrl+r` (history fallback).
- **Terminal-Icons**: Colorized folder and file icons in directory listings.
- **posh-git**: Rich Git status indicators in the prompt.
- **Oh-My-Posh**: Driven by `~/.config/oh-my-posh/config.json` with the unified **OneDark-Pro** theme.
- **CLI Replacements**: Real CLI tools un-shadowed (`ls` &rarr; `lsd`, `cat` &rarr; `bat`, `grep` &rarr; `rg`, `lg` &rarr; `lazygit`, `hx` &rarr; `helix`).
- **Environment Variables**: Automatic setup of `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_CACHE_HOME`.

---

## 📦 Aqua CLI Tool Manager on Windows

Aqua automatically manages cross-platform developer tools on Windows without needing separate Scoop or Chocolatey manifests:

| Tool | Purpose | Command |
| :--- | :--- | :--- |
| **atuin** | Shell history sync & fuzzy search | `atuin` |
| **fzf** | Interactive fuzzy finder | `fzf` |
| **ripgrep** | Fast recursive regex search | `rg` |
| **bat** | Syntax-highlighting cat | `bat` |
| **lsd** | Modern file listing | `lsd` |
| **lazygit** | Terminal Git UI | `lazygit` |
| **helix** | Modern modal editor | `hx` |
| **yazi** | Blazing fast terminal file manager | `yazi` |
| **btop** | System resource monitor | `btop` |

Aqua tools are linked to `%LOCALAPPDATA%\aquaproj-aqua\bin` which is automatically added to `PATH`. The global config `~/.config/aquaproj-aqua/aqua.yaml` is discovered via `AQUA_GLOBAL_CONFIG`.

### Atuin Shell History Integration
Atuin is managed by Aqua and automatically initialized in PowerShell (`Profile.ps1`):
- **Search History**: Press <kbd>Ctrl</kbd> + <kbd>r</kbd> or <kbd>UpArrow</kbd> to open interactive fuzzy search.
- **Sync History**: Run `atuin register` / `atuin login` to sync shell history across Windows, Linux, and macOS.
- **Diagnostics**: Run `atuin doctor` to verify setup.

### Setting Aqua GitHub Token (Avoid Rate Limits)

```powershell
# Store GitHub token in system keyring for aqua downloads
aqua token set
```

---

## 🛠️ Windows System Tweaks & Optimizations

### 1. Enable Developer Mode (Allow Unprivileged Symlinks)

Enabling Developer Mode allows chezmoi and git to create symbolic links without needing Administrator privileges:

```powershell
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"
```

### 2. Enable Win32 Long Paths

Prevents `MAX_PATH` (260 character) limits in deeply nested repositories (such as `node_modules`):

```powershell
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f
```

### 3. Dual-Boot Clock Fix (UTC Hardware Clock)

If you dual-boot Windows alongside Linux, Windows by default interprets the motherboard hardware clock as local time, causing time drift when switching OSes. Set Windows to use UTC:

```powershell
reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f
```

---

## ❓ Troubleshooting & FAQs

### "File cannot be loaded because running scripts is disabled on this system"
By default, Windows blocks script execution. Update your execution policy for your user account:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### OneDrive Documents Redirection
If OneDrive Known Folder Move redirects your `Documents` folder (e.g. `C:\Users\<user>\OneDrive\Documents` or localized `C:\Users\<user>\OneDrive\Dokumente`), PowerShell resolves `$PROFILE` to the redirected path.

**This is handled automatically.**
- `bootstrap.ps1` and chezmoi's post-apply hook (`.chezmoiscripts/run_after_windows_sync-profiles.ps1.tmpl`) detect when `[System.Environment]::GetFolderPath('MyDocuments')` differs from `$HOME\Documents`.
- They automatically create NTFS directory junctions (`PowerShell` and `WindowsPowerShell`) pointing from OneDrive's Documents folder to `$HOME\Documents\PowerShell`.
- Directory junctions do **not** require Developer Mode or Administrator privileges.
- Any preexisting unlinked profile directory is safely backed up with a timestamp before creating the junction.

You can verify your active profile junction anytime:
```powershell
Get-Item (Split-Path $PROFILE) | Select-Object FullName, LinkType, Target
```

---

## 🔄 Daily Commands

```powershell
chezmoi update                                                         # Pull latest dotfiles and apply
chezmoi edit Documents/PowerShell/Microsoft.PowerShell_profile.ps1      # Edit profile
aqua install                                                           # Update/install managed CLI tools
reload                                                            # Reload current PowerShell session
```

