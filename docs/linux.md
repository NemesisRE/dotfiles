# Linux Setup & User Guide

This guide details setting up, using, and troubleshooting **NREDF dotfiles** on **Linux** (Debian/Ubuntu, Arch Linux, Fedora/RHEL, Linuxbrew, and WSL).

---

## 🚀 Quick Install (One-Liners)

Using chezmoi directly:
```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply NemesisRE/chezmoi
```

Or using the bootstrap script:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NemesisRE/chezmoi/main/bootstrap.sh)
```

> **Requirements:** `curl` and `git` (automatically installed if missing on Debian/Ubuntu).

---

## 📦 Package Management Across Distributions

NREDF manages native prerequisite packages automatically via [`home/.chezmoidata/packages.yaml`](file:///Users/skurz/Repos/chezmoi/home/.chezmoidata/packages.yaml) during `chezmoi apply`.

| Distribution | Package Manager | Core Prerequisites Managed |
| :--- | :--- | :--- |
| **Debian / Ubuntu** | `apt` | `git`, `curl`, `zsh`, `fonts-firacode`, `build-essential` (C/C++ compiler for Tree-sitter), `socat` |
| **Arch Linux** | `pacman` | `git`, `curl`, `zsh`, `ttf-firacode-nerd`, `base-devel` (C/C++ compiler for Tree-sitter), `socat` |
| **Fedora / RHEL** | `dnf` | `git`, `curl`, `zsh`, `fira-code-fonts`, `gcc`, `gcc-c++`, `make` (for Tree-sitter), `socat` |
| **Linuxbrew** | `brew` | Standalone Homebrew packages located at `/home/linuxbrew/.linuxbrew` |

All developer CLI tools (such as `neovim`, `zellij`, `atuin`, `fzf`, `zoxide`, `lsd`, `bat`, `yazi`, `lazygit`, `lazydocker`, `lazyjournal`, `lnav`, `btop`, `uv`, `ruff`, `ouch`) are managed declaratively by **aqua** in `~/.config/aquaproj-aqua/aqua.yaml`, keeping system package manager pollution to a minimum (Python is managed standalone via `uv`, and all archive compression/decompression via `ouch`).

---

## 🐚 Supported Shells on Linux

### 1. Zsh
- Default interactive shell for many setups.
- Uses **Sheldon** to manage plugins (`~/.config/sheldon/plugins.toml`) with lazy loading.
- Features **Oh-My-Posh** prompt (`OneDark-Pro`), **Atuin** history sync, **fzf** completions, and **fast-syntax-highlighting**.

### 2. Bash
- Standard shell on almost all Linux distributions.
- Powered by **ble.sh** (Bash Line Editor) located at `~/.local/share/blesh/ble.sh`.
- Adds real-time syntax highlighting, fish-style autosuggestions, vim mode, and menu-completion directly to standard GNU Bash 4.4+.

### 3. PowerShell (`pwsh`)
- Install via Microsoft package repository or `snap install powershell --classic`.
- Symlinks `~/.config/powershell` to `~/Documents/PowerShell`.
- Uses `NREDF-POSH` modular configuration with `PSFzf`, `Terminal-Icons`, `posh-git`, and `Atuin`.

To switch active shells anytime without re-opening your terminal:
```bash
reload -s zsh    # Switch to Zsh
reload -s bash   # Switch to Bash
reload -s pwsh   # Switch to PowerShell
```

---

## 🪟 Terminal Emulation (Kitty)

On Linux desktop environments, **Kitty** is the recommended GPU-accelerated terminal emulator:
- **Upstream Installation**: Managed standalone via the official installer to `~/.local/kitty.app` with binaries linked to `~/.local/bin/` (version pinned in [`.chezmoidata/kitty.yaml`](file:///Users/skurz/Repos/chezmoi/home/.chezmoidata/kitty.yaml) and kept current with Renovate). This avoids severely outdated distribution packages (like Debian/Ubuntu `apt`).
- **Desktop & Icon Integration**: Chezmoi automatically creates and patches `kitty.desktop` and icons in `~/.local/share/applications` and `~/.local/share/icons`.
- **WSL Excluded**: Kitty installation is automatically skipped on WSL environments (where Windows Terminal on the host OS is used).
- **Font**: Configured with `FiraMono Nerd Font Mono` (or `FiraCode Nerd Font`).
- **Theme**: Automatically imports the matching **OneDark-Pro** theme (`~/.config/kitty/current-theme.conf`).
- **Scrollback**: 10,000 lines with smart trailing space stripping.
- **Copy on Select**: Text selected with mouse is copied to system clipboard automatically (`copy_on_select clipboard`).

### Quake-Mode (Quick Access Dropdown Terminal)
NREDF includes pre-configured drop-down terminal settings in [`home/dot_config/kitty/quick-access-terminal.conf.tmpl`](file:///Users/skurz/Repos/chezmoi/home/dot_config/kitty/quick-access-terminal.conf.tmpl) and installs a Wayland-aware wrapper script: `kitty-quake` (aliased to `kitty-quick-access`).

* **Configuration Gate**: You can choose your preferred Quake toggle key (`F12`, `Pause`, or `none`) during `chezmoi init` or in `~/.config/chezmoi/chezmoi.toml`:
  ```toml
  [data.kitty]
      quake_key = "Pause" # Options: "F12" (default), "Pause", or "none"
  ```
* **KDE Plasma (Automatic)**: Chezmoi automatically configures the global shortcut in KDE Plasma using `kwriteconfig` and restarts the shortcut daemon.
* **Wayland Integration**: Automatically exports `WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"` so hotkey daemons and compositors can toggle the window reliably.
* **Manual / Other Compositors**:
  * **KDE Plasma (Manual)**: *System Settings → Keyboard → Shortcuts*, click **Add New** → **Add Application...**, select **Kitty Quake Terminal**, and set the shortcut.
  * **GNOME**: Go to *Settings → Keyboard → View and Customize Shortcuts → Custom Shortcuts*. Add a shortcut with command `kitty-quake` (or select *Kitty Quake Terminal*), e.g. bound to <kbd>Pause</kbd> or <kbd>F12</kbd>.
  * **Sway**: Add to your config: `bindsym Pause exec ~/.local/bin/kitty-quake`
  * **Hyprland**: Add to `hyprland.conf`: `bind = , Pause, exec, ~/.local/bin/kitty-quake`

### Useful Kitty Shortcuts
- <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Enter</kbd>: New window split
- <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>t</kbd>: New tab
- <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>w</kbd>: Close window
- <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Left</kbd> / <kbd>Right</kbd>: Next / previous window
- <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Up</kbd> / <kbd>Down</kbd>: Scroll line up / down
- <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>PageUp</kbd> / <kbd>PageDown</kbd>: Scroll page up / down

---

## 🔑 SSH Agent Management

NREDF features an intelligent SSH Agent detection engine in [`nredf_set_ssh_agent.bash`](file:///Users/skurz/Repos/chezmoi/home/dot_local/share/nredf/shell/common/functions/nredf_set_ssh_agent.bash):

### 1. Supported Providers on Linux
- **Systemd User SSH Agent**: `$XDG_RUNTIME_DIR/ssh-agent.socket`
- **GNOME Keyring**: `$XDG_RUNTIME_DIR/gcr/ssh` or `$XDG_RUNTIME_DIR/keyring/ssh`
- **Bitwarden Desktop**: `~/.bitwarden-ssh-agent.sock` (or Snap/Flatpak container sockets)
- **1Password**: `~/.1password/agent.sock` or `~/.config/1Password/agent.sock`
- **GnuPG Agent**: Uses `gpgconf --list-dirs agent-ssh-socket` when GPG agent mode is configured.

### 2. WSL (Windows Subsystem for Linux) Integration
In WSL 1/2, NREDF can bridge your Windows SSH Agent (e.g. Bitwarden Desktop or Windows OpenSSH Service) into WSL automatically:
- Uses `socat` and `npiperelay.exe` to bridge `//./pipe/openssh-ssh-agent` to `~/.ssh/auth_sock`.
- To enable:
  ```powershell
  # On Windows host:
  winget install albertony.npiperelay
  ```
  In WSL, NREDF automatically detects `npiperelay.exe` and establishes the relay socket.

---

## 💡 Linux Tips & Tricks

### 1. Fast Package Maintenance (`aptall`)
On Debian/Ubuntu systems, use the built-in alias:
```bash
aptall
# Runs: sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove --purge -y && sudo apt autoclean
```

### 2. Sudo Shell with User Environment (`root`)
Switch to root while preserving your user environment variables:
```bash
root
# Runs: sudo -E "HOME=${HOME}" su -m
```

### 3. Inspect Running Docker Container IPs (`dipls`)
Instantly view a sorted table of all running Docker container IP addresses and names:
```bash
dipls
```

### 4. Interactive File Manager with Directory Change (`yy`)
```bash
yy
# Opens Yazi. Navigating to a folder and exiting with 'q' changes your terminal directory!
```

---

## ❓ FAQ & Troubleshooting

### Q1: Locale warnings (`perl: warning: Setting locale failed...`)
**Cause**: The current environment has an ungenerated or invalid UTF-8 locale set.
**Resolution**:
NREDF automatically checks available locales via `locale -a` and defaults to `en_US.UTF-8` or `C.UTF-8`. To generate standard locales on Debian/Ubuntu:
```bash
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8
```

### Q2: Clipboard copy doesn't work over remote SSH or Zellij
**Cause**: Missing terminal OSC 52 passthrough or missing clipboard binary on headless Linux.
**Resolution**:
- NREDF configures Neovim, Zellij, and Kitty with OSC 52 clipboard passthrough, which copies text to your desktop clipboard directly across SSH.
- On desktop Linux, ensure `wl-clipboard` (Wayland) or `xclip` / `xsel` (X11) is installed:
  ```bash
  sudo apt install wl-clipboard xclip  # Debian/Ubuntu
  sudo pacman -S wl-clipboard xclip    # Arch
  ```

### Q3: Aqua GitHub API Rate Limits
If `aqua install` warns about GitHub API limits:
```bash
aqua token set
```
Follow the prompt to enter a personal GitHub token (no permissions needed for public repos).

