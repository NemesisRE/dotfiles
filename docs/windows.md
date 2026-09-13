# Windows Setup & Optimization Guide (HOWTO)

This guide walks you through setting up, configuring, and optimizing your Windows workstation with **NREDF dotfiles**, **chezmoi**, **PowerShell 7**, and **aqua**.

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

Chezmoi automatically manages and installs these core prerequisite packages on Windows via [`home/.chezmoidata/packages.yaml`](file:///Users/skurz/Repos/chezmoi/home/.chezmoidata/packages.yaml) and `winget` during `chezmoi apply`.

If you prefer to install them manually upfront:

```powershell
# Modern Shell & Terminal
winget install Microsoft.PowerShell
winget install Microsoft.WindowsTerminal

# Version Control
winget install Git.Git

# Recommended Default Font: FiraMono / FiraCode Nerd Font
winget install DEVCOM.FiraCodeFont

# C/C++ Compiler for Neovim Tree-sitter
winget install LLVM.LLVM
```

> [!TIP]
> In Windows Terminal Settings (`Ctrl+,`) &rarr; **Defaults** &rarr; **Appearance** &rarr; **Font face**, set the font to **FiraMono Nerd Font Mono** (or **FiraMono Nerd Font**) to match kitty terminal.

---

## 🐚 Supported Shells on Windows

NREDF supports multiple shells on Windows with shared aliases, history, and modern tool replacements:

### 1. PowerShell 7+ (`pwsh`) & Windows PowerShell 5.1
- **PowerShell 7+**: `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- **Windows PowerShell 5.1**: `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (dot-sources PowerShell 7 profile)
- Includes `posh-git`, `PSFzf`, `Terminal-Icons`, `GuiCompletion`, and `Atuin` history search.

### 2. Bash & Zsh on Windows
- **WSL (Windows Subsystem for Linux)**: Full Linux environment running native Bash (ble.sh) or Zsh (Sheldon).
- **Git Bash (MSYS2)**: Sources common NREDF shell libraries and aliases.

### 3. Switching Shells On the Fly
Switch between shells without restarting Windows Terminal:
```powershell
reload -s pwsh         # Reload into PowerShell 7
reload -s powershell   # Switch to Windows PowerShell 5.1
reload -s bash         # Switch to Git Bash / WSL Bash
reload -s cmd          # Switch to Command Prompt
```

---

## ⌨️ Windows Keyboard Shortcuts

### 1. Windows Terminal Shortcuts

| Shortcut | Action |
| :--- | :--- |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>t</kbd> | Open new tab |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>w</kbd> | Close active pane / tab |
| <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>+</kbd> | Split pane vertically |
| <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>-</kbd> | Split pane horizontally |
| <kbd>Alt</kbd> + <kbd>&larr;</kbd> / <kbd>&rarr;</kbd> / <kbd>&uarr;</kbd> / <kbd>&darr;</kbd> | Move focus between split panes |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>f</kbd> | Search terminal buffer |
| <kbd>Ctrl</kbd> + <kbd>,</kbd> | Open Settings UI |

---

### 2. PowerShell (PSReadLine & PSFzf) Shortcuts

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| <kbd>Tab</kbd> | GuiCompletion | Rich interactive popup completion menu |
| <kbd>Ctrl</kbd> + <kbd>r</kbd> / <kbd>&uarr;</kbd> | Atuin History | Interactive fuzzy history search across all your machines |
| <kbd>Ctrl</kbd> + <kbd>t</kbd> | PSFzf File Search | Fuzzy find files with syntax-highlighted `bat` preview |
| <kbd>Alt</kbd> + <kbd>c</kbd> | PSFzf CD | Fuzzy find directories with `lsd --tree` preview and jump |
| <kbd>Ctrl</kbd> + <kbd>d</kbd> | ViExit | Exit session if buffer is empty |
| <kbd>Alt</kbd> + <kbd>d</kbd> | ShellKillWord | Delete next word forward |
| <kbd>Alt</kbd> + <kbd>Backspace</kbd> | ShellBackwardKillWord | Delete previous word backward |
| <kbd>Alt</kbd> + <kbd>q</kbd> | SaveInHistory | Stash current line in history and clear buffer |
| <kbd>"</kbd> or <kbd>'</kbd> | SmartInsertQuote | Automatically insert paired quotes and position cursor inside |
| <kbd>&rarr;</kbd> (Right Arrow) | Prediction Accept | Accept IntelliSense prediction candidate |

---

## 🔑 SSH Agent Setup (Bitwarden SSH Agent)

Bitwarden Desktop includes a built-in SSH Agent on Windows:
1. Open Bitwarden Desktop &rarr; **Settings** &rarr; **SSH Agent**.
2. Check **Enable SSH Agent**.
3. Under Windows, Bitwarden exposes the OpenSSH named pipe: `\\.\pipe\openssh-ssh-agent`.
4. The PowerShell profile automatically sets `$env:SSH_AUTH_SOCK = "\\.\pipe\openssh-ssh-agent"`.
5. Windows OpenSSH client and Git will automatically query Bitwarden for authentication without needing external SSH daemons.

---

## 📦 Aqua CLI Tool Manager on Windows

Aqua manages cross-platform developer tools on Windows without needing separate Scoop or Chocolatey manifests:

| Tool | Purpose | Command |
| :--- | :--- | :--- |
| **atuin** | Shell history sync & fuzzy search | `atuin` |
| **fzf** | Interactive fuzzy finder | `fzf` |
| **zoxide** | Smart directory jumper | `cd` / `z` / `zi` |
| **ripgrep** | Fast recursive regex search | `rg` |
| **bat** | Syntax-highlighting cat (OneDarkPro) | `bat` |
| **lsd** | Modern file listing with icons | `lsd` |
| **lazygit** | Terminal Git UI | `lazygit` / `lzg` / `lg` |
| **neovim** | Hyperextensible AstroNvim v6 editor | `nvim` |
| **yazi** | Blazing fast terminal file manager | `yazi` / `yy` |
| **lazydocker** | Terminal Docker & Compose UI | `lazydocker` / `lzd` |
| **lazyjournal** | Multi-source log viewer & TUI | `lazyjournal` / `lzj` / `lj` |
| **lnav** | Advanced log file navigator & SQL analyzer | `lnav` |
| **btop** | System resource monitor | `btop` |
| **zellij** | Builtin terminal workspace multiplexer | `zellij` |

Aqua tools are linked to `%LOCALAPPDATA%\aquaproj-aqua\bin` which is automatically added to `PATH`.

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

## 💡 Windows Tips & Tricks

### 1. Visual File Navigation with CWD Tracking (`yy`)
Run `yy` in PowerShell to launch **Yazi**. Navigate directories with syntax previews, press <kbd>q</kbd>, and PowerShell automatically switches to that directory!

### 2. Profiling Profile Startup Time
```powershell
reload -p
```
Displays millisecond execution time for Oh-My-Posh, Atuin, PSFzf, and custom functions.

### 3. Sudo Privileges in PowerShell
NREDF includes a smart `sudo` command that leverages `sudo.exe` (Windows 11), `gsudo`, or an elevated process window:
```powershell
sudo notepad C:\Windows\System32\drivers\etc\hosts
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

### Aqua: "remove a temporary file: The process cannot access the file because it is being used by another process" (WRN)
When running `reload -d` or installing packages on Windows, you may occasionally see a warning:
```text
WRN remove a temporary file ... error="remove C:\Users\<user>\AppData\Local\Temp\<id>: The process cannot access the file because it is being used by another process."
```

**Root Cause**:
Microsoft Defender's real-time file scanner (`MsMpEng.exe`) immediately opens a read handle on newly unpacked `.exe` binaries in `%TEMP%` to verify their safety. When aqua finishes moving the executable into `aquaproj-aqua\pkgs` and attempts to delete the temporary extraction folder, Defender is still scanning the file, triggering a Windows sharing violation (`ERROR_SHARING_VIOLATION`).

**Impact**:
This is a non-fatal warning (`WRN`). The package extraction and installation is already complete and functional. The residual file in `%TEMP%` is automatically cleaned up by Windows Storage Sense.

**Resolution**:
To eliminate the warning and speed up package downloads, add an exclusion for `aqua.exe` in Microsoft Defender (run PowerShell as Administrator):
```powershell
Add-MpPreference -ExclusionProcess "aqua.exe"
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\aquaproj-aqua"
```

---

## 🔄 Daily Commands

```powershell
chezmoi update                                                         # Pull latest dotfiles and apply
chezmoi edit Documents/PowerShell/Microsoft.PowerShell_profile.ps1      # Edit profile
aqua install                                                           # Update/install managed CLI tools
reload                                                                 # Reload current PowerShell session
```

---

## 📖 Further Documentation

- [Unified Shells Guide (Zsh, Bash, pwsh)](shells.md)
- [Core Features & Tools Guide](tools.md)
- [Dedicated Neovim Guide](neovim.md)
