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

Chezmoi automatically manages and installs these core prerequisite packages on Windows via [`home/.chezmoidata/packages.yaml`](../home/.chezmoidata/packages.yaml) and `winget` during `chezmoi apply`.

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

# WSL OpenSSH Agent Bridge
winget install albertony.npiperelay
```

> [!TIP]
> In Windows Terminal Settings (`Ctrl+,`) &rarr; **Defaults** &rarr; **Appearance** &rarr; **Font face**, set the font to **FiraMono Nerd Font Mono** (or **FiraMono Nerd Font**) to match kitty terminal.

### Windows Optional Features & Synchronization

By default, NREDF uses safe defaults (`false`) and will **not** overwrite pre-existing Windows settings or system configurations. You can opt in during `chezmoi init --prompt` or by editing `~/.config/chezmoi/chezmoi.toml`:

```toml
[data.windows.microsoftTerminal]
    sync_settings = true     # Sync Microsoft Terminal settings.json in AppData

[data.windows.winget]
    sync_settings = true     # Sync winget settings.json (telemetry off, rainbow bar)

[data.windows.wsl]
    sync_config = true       # Sync ~/.wslconfig (memory limits, mirrored networking)
    memory = "16GB"
    processors = 8
    networking_mode = "mirrored"
    nested_virtualization = true # Enable nested virtualization (true/false)

[data.windows.explorer]
    apply_tweaks = true      # Show file extensions, hidden files, compact mode

[data.windows.systemTweaks]
    apply_tweaks = true      # Developer Mode (unprivileged symlinks), Long Paths, UTC Clock
```

---

## 🐚 Supported Shells on Windows

NREDF supports multiple shells on Windows with shared aliases, history, and modern tool replacements:

### 1. PowerShell 7+ (`pwsh`) & Windows PowerShell 5.1

- **PowerShell 7+**: `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- **Windows PowerShell 5.1**: `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (dot-sources PowerShell 7 profile)
- 100% native CLI tooling: `fzf` (<kbd>Ctrl</kbd>+<kbd>t</kbd>, <kbd>Alt</kbd>+<kbd>c</kbd>), `lsd`, `bat`, `Atuin` history search, and `MenuComplete`.
- **5.1 limitation**: the NREDF function library (Bitwarden session restore, `reload`, `NREDF_DailySync`, etc.) needs PowerShell 7+ — one of its files uses the `??` operator, a parse error on 5.1 — so it is skipped there with a one-line warning. Everything else (aliases, prompt theme, tool init) still loads.

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

### 4. Automated Daily Maintenance (Task Scheduler)

Chezmoi automatically registers a scheduled task in Windows Task Scheduler:

- **Task Name**: `NREDF-DailySync`
- **Trigger**: Daily at 7:00 AM with `-StartWhenAvailable` (automatically catches up when your PC turns on or wakes from sleep).
- **Settings**: `-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries`.
- **Payload**: Runs `NREDF_DailySync` in a hidden, non-interactive PowerShell process.
- **Tasks**: Upgrades `chezmoi`, pulls dotfiles updates, applies external templates, updates `aqua` tools, and vacuums old packages.
- **Log**: Written to `$env:LOCALAPPDATA\nredf\daily-sync.log`.

To check the task in PowerShell:

```powershell
Get-ScheduledTask -TaskName 'NREDF-DailySync'
```

### 5. High-Performance Profile Startup

To eliminate startup lag on Windows:

- **Update Check Disabled**: `$ENV:POWERSHELL_UPDATECHECK = 'Off'` in `Defaults.ps1` suppresses slow remote GitHub release version polling on startup.
- **Profile Duration Banner Hidden**: `"Microsoft.PowerShell:ShowProfileStartupDuration": false` in `powershell.config.json` disables the native PowerShell startup timing banner.
- **Function Bundling**: All 11 NREDF PowerShell functions are bundled into a single file during `chezmoi apply`, loading in ~6 ms instead of ~100 ms.

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

### 2. PowerShell (PSReadLine & fzf) Shortcuts

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| <kbd>Tab</kbd> | MenuComplete | Interactive terminal completion menu |
| <kbd>Ctrl</kbd> + <kbd>r</kbd> / <kbd>&uarr;</kbd> | Atuin History | Interactive fuzzy history search across all your machines |
| <kbd>Ctrl</kbd> + <kbd>t</kbd> | fzf File Search | Fuzzy find files with syntax-highlighted `bat` preview |
| <kbd>Alt</kbd> + <kbd>c</kbd> | fzf CD | Fuzzy find directories with `lsd --tree` preview and jump |
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
| **bottom** | System resource monitor | `btm` |
| **zellij** | Builtin terminal workspace multiplexer | `zellij` |

Aqua tools are linked to `%LOCALAPPDATA%\aquaproj-aqua\bin` which is automatically added to `PATH`.

### Setting Aqua GitHub Token (Avoid Rate Limits)

```powershell
# Store GitHub token in system keyring for aqua downloads
aqua token set
```

---

## 🛠️ Windows System Tweaks & Optimizations

> [!TIP]
> You can automatically apply these tweaks by setting `apply_tweaks = true` under `[data.windows.systemTweaks]` and `[data.windows.explorer]` in `~/.config/chezmoi/chezmoi.toml`.
> To apply them manually upfront, run the commands below in an elevated (Administrator) PowerShell prompt.

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

### Redirected Documents (OneDrive & Corporate SMB Network Shares)

In Windows environments, your `Documents` folder may be redirected away from `$HOME\Documents`:

1. **OneDrive Known Folder Move** (e.g. `C:\Users\<user>\OneDrive\Documents`):
   - PowerShell resolves `$PROFILE` to the OneDrive path.
   - `bootstrap.ps1` and chezmoi's post-apply hook (`.chezmoiscripts/run_after_windows_sync-profiles.ps1.tmpl`) automatically create NTFS directory junctions (`PowerShell` and `WindowsPowerShell`) pointing from OneDrive's Documents folder to `$HOME\Documents\PowerShell`.
   - Directory junctions are local NTFS reparse points that do not require Administrator privileges.

2. **Corporate Network / SMB Shares** (e.g. `\\server\home$\<user>\Documents` or mapped drive `H:\...`):
   - NTFS junctions and remote symlinks cannot be created across network shares, and corporate file servers (FSRM) frequently block `.ps1` scripts on network shares or trigger "Access is denied".
   - NREDF dotfiles automatically detect UNC / network paths and install an **AllUsers profile trampoline** into `$PROFILE.AllUsersCurrentHost` (`C:\Program Files\PowerShell\7\Microsoft.PowerShell_profile.ps1` and Windows PowerShell 5.1).
   - This trampoline automatically sources your local profile (`$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`) before PowerShell evaluates the remote network profile.
   - **Isolated UAC Elevation**: If running unprivileged, the script requests standard UAC elevation *solely* to install the AllUsers trampoline files without elevating the rest of the dotfiles process.
   - **Non-Admin Fallback**: If you lack administrator rights, you can configure your terminal to load your local profile directly:
     - **Windows Terminal (`settings.json`)**:
       `"commandline": "pwsh.exe -NoExit -Command \". '$env:USERPROFILE\\Documents\\PowerShell\\Microsoft.PowerShell_profile.ps1'\""`
     - **VS Code (`settings.json`)**:
       `"terminal.integrated.profiles.windows": { "PowerShell": { "path": "pwsh.exe", "args": ["-NoExit", "-Command", ". '${env:USERPROFILE}\\Documents\\PowerShell\\Microsoft.PowerShell_profile.ps1'"] } }`

You can verify your active profile anytime:

```powershell
$PROFILE | Format-List *
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

### Yazi: MIME Detection and Configuration Discovery on Windows

**1. "Cannot find `file` to detect the file's MIME type"**

- **Root Cause**: Yazi relies on the Unix `file` utility to detect file MIME types for previews and openers. On Windows, `file.exe` is distributed with Git for Windows (`Git\usr\bin\file.exe`).
- **Resolution**: NREDF automatically detects Git for Windows and exports `YAZI_FILE_ONE` in [`Defaults.ps1`](../home/dot_local/share/nredf/shell/pwsh/Defaults.ps1) as well as persisting it to the User environment during `chezmoi apply`. If running Yazi outside of NREDF PowerShell, ensure Git is installed (`winget install Git.Git`) and set the user variable:

  ```powershell
  [System.Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", "C:\Program Files\Git\usr\bin\file.exe", "User")
  ```

**2. Yazi Opens Files with VS Code Instead of Neovim**

- **Root Cause**: On Windows, Yazi looks for configuration in `%APPDATA%\yazi\config\` unless `$env:YAZI_CONFIG_HOME` is set. Without this, Yazi ran with compiled-in preset defaults which map Windows `edit` to `code %s`.
- **Resolution**: NREDF automatically sets `YAZI_CONFIG_HOME` to `$HOME\.config\yazi`, creates a directory junction from `%APPDATA%\yazi\config` to `$HOME\.config\yazi`, and configures explicit `[open]` prepend rules in [`yazi.toml.tmpl`](../home/dot_config/yazi/yazi.toml.tmpl) so all dotfiles (`.*`), source code, and text files route to `nvim`.

### Neovim: AstroCommunity Packs & Tool Installation on Windows

**1. Chezmoi Pack: "attempt to concatenate a nil value"**

- **Root Cause**: `astrocommunity.pack.chezmoi` concatenates `os.getenv "HOME" .. "/.local/share/chezmoi"`. Because Windows defaults to `USERPROFILE` rather than `HOME`, `HOME` was unset (`nil`), causing a Lua runtime failure during lazy spec loading.
- **Resolution**: NREDF automatically normalizes `vim.env.HOME = vim.env.USERPROFILE` at the top of Neovim's `init.lua`, persists `$env:HOME = $HOME` to Windows User environment variables, and configures Windows-compatible source paths (`%LOCALAPPDATA%\chezmoi`) in [`lua/plugins/chezmoi.lua`](../home/dot_config/nvim/lua/plugins/chezmoi.lua).

**2. Mason: "Installation failed for ansible-lint: Platform not supported"**

- **Root Cause**: `ansible-lint` is an Ansible/Python CLI tool that requires POSIX APIs and does not natively support Windows. Mason's package registry explicitly restricts it to `supported_platforms: [unix]`.
- **Resolution**: NREDF automatically filters `ansible-lint` out of Mason's automatic installer on Windows in [`lua/plugins/mason.lua`](../home/dot_config/nvim/lua/plugins/mason.lua). The Ansible Language Server (`ansible-language-server` via npm) and syntax highlighting continue to work seamlessly on Windows, while `ansible-lint` is used when running in Linux/macOS/WSL.

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

- [Unified Shells Guide (Zsh, Bash, Fish, Nushell, pwsh)](shells.md) — note: Fish has no Windows build; Nushell does
- [Core Features & Tools Guide](tools.md)
- [Dedicated Neovim Guide](neovim.md)
