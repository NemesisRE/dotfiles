# macOS Setup & User Guide

This guide covers configuring, optimizing, and troubleshooting your **macOS** workstation with **NREDF dotfiles**, **Homebrew**, **Kitty**, and **aqua** across **Apple Silicon (M1/M2/M3/M4)** and **Intel** Macs.

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

> **Prerequisites:** [Homebrew](https://brew.sh) and Xcode Command Line Tools (`xcode-select --install`).

---

## 🏗️ Apple Silicon vs Intel Architecture

NREDF automatically adapts all paths, compiler flags, and package locations based on your CPU architecture:

| Component | Apple Silicon (`arm64`) | Intel (`x86_64`) |
| :--- | :--- | :--- |
| **Homebrew Prefix** | `/opt/homebrew` | `/usr/local` |
| **Homebrew Binaries** | `/opt/homebrew/bin` | `/usr/local/bin` |
| **Homebrew Bash** | `/opt/homebrew/bin/bash` | `/usr/local/bin/bash` |
| **Aqua Binaries** | `~/.local/share/aquaproj-aqua/bin` | `~/.local/share/aquaproj-aqua/bin` |

Homebrew analytics and cleanup noise are disabled automatically in [`common/rc.tmpl`](../home/dot_local/share/nredf/shell/common/rc.tmpl):

- `HOMEBREW_NO_ANALYTICS=1`
- `HOMEBREW_NO_INSTALL_CLEANUP=1`
- `HOMEBREW_QUIET=1`

---

## 📦 Prerequisites Managed via Homebrew

Chezmoi manages native macOS packages and fonts declared in [`home/.chezmoidata/packages.yaml`](../home/.chezmoidata/packages.yaml) during `chezmoi apply`:

```yaml
packages:
  darwin:
    brews:
      - bash                    # Modern Bash 5.x (replaces Apple's legacy Bash 3.2)
      - bash-completion@2       # Modern programmable completion
      - git                     # Up-to-date Git client
      - curl                    # Latest curl binary
      - diffutils               # GNU diff utilities
      - util-linux              # Linux utilities ported to macOS
    casks:
      - kitty                   # GPU-accelerated terminal emulator
      - font-fira-mono-nerd-font # Primary Nerd Font matching editor & prompt
```

---

## 🐚 Supported Shells on macOS

### 1. Zsh (Default macOS Shell)

- Pre-installed by Apple and configured as the default shell.
- NREDF supercharges Zsh with **Sheldon** plugin management, **Oh-My-Posh** prompt (`OneDark-Pro`), **Atuin** history sync, and **zoxide** navigation.

### 2. Modern Bash (Bash 4.4+ / 5.x)

- Apple ships an obsolete **Bash 3.2** (from 2007) due to GPL licensing.
- **NREDF Solution**: When you start Bash, [`.bashrc.tmpl`](../home/dot_bashrc.tmpl) automatically detects Homebrew Bash (`/opt/homebrew/bin/bash` or `/usr/local/bin/bash`) and seamlessly re-executes into it!
- This unlocks **ble.sh** (Bash Line Editor), giving Bash real-time syntax highlighting, autosuggestions, and modern completion.

### 3. PowerShell (`pwsh`)

- Install via Homebrew:

  ```bash
  brew install --cask powershell
  ```

- NREDF symlinks `~/.config/powershell` to `~/Documents/PowerShell`, providing unified PSReadLine keybindings, PSFzf, Terminal-Icons, and Oh-My-Posh prompt parity.

Switch active shells on the fly anytime:

```bash
reload -s zsh    # Switch to Zsh
reload -s bash   # Switch to modern Bash 5
reload -s pwsh   # Switch to PowerShell
```

---

## ⌨️ macOS Option Key & Alt Keybinding Parity

On macOS, pressing <kbd>Option</kbd> + <kbd>key</kbd> (such as <kbd>Option</kbd>+<kbd>c</kbd>) by default outputs special characters (e.g. `ç` or `©`) instead of sending a standard Meta/Escape sequence (`\ec`).

### How NREDF Solves This

1. **Kitty Terminal**: Configured in `kitty.conf` with:

   ```conf
   macos_option_as_alt both
   ```

   Both Left and Right Option keys act as standard Alt keys.
2. **Shell-Level Keybindings**: If you use Terminal.app, iTerm2, or another terminal where Option still outputs special characters, NREDF binds both `ç` and `©` to directory jumping:
   - **Zsh**: Bound to `fzf-cd-widget`
   - **Bash (ble.sh)**: Bound via `ble-bind -c 'ç' 'eval "$(__fzf_cd__)"'`
   - **PowerShell**: Bound via `Set-PSReadLineKeyHandler -Chord 'ç'`

---

## 🔑 SSH Agent Management (Bitwarden / 1Password)

### 1. Bitwarden Desktop SSH Agent

Bitwarden Desktop on macOS provides a built-in SSH Agent socket. NREDF automatically checks and sets `SSH_AUTH_SOCK` to:

```text
~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock
```

### 2. 1Password SSH Agent

If configured for 1Password, NREDF automatically detects:

```text
~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

---

## 💡 macOS Tips & Tricks

### 1. Change Login Shell to Homebrew Bash or Zsh

If you prefer modern Homebrew Bash or Zsh as your system-wide default login shell:

```bash
# Add Homebrew shell to allowed shells list
sudo sh -c 'echo "/opt/homebrew/bin/bash" >> /etc/shells'

# Change default login shell
chsh -s /opt/homebrew/bin/bash
```

### 2. Fast Directory Jumping with Yazi (`yy`)

Use the `yy` alias to browse folders visually with syntax previews. When you quit Yazi with <kbd>q</kbd>, your terminal immediately switches to that folder!

### 3. Startup Performance Profiling

Wondering why a shell starts slowly? Run:

```bash
reload -p
```

Inspect the exact startup breakdown in milliseconds across Homebrew, Oh-My-Posh, Atuin, and plugins.

### 4. Automated Daily Maintenance (`launchd`)

NREDF installs a native user LaunchAgent (`com.nredf.daily-sync.plist`) that runs daily at 7:00 AM (or immediately upon wake/boot if asleep) in the background (`LowPriorityIO` and `Nice: 10`):

- Upgrades Homebrew formulae and casks (`brew update && brew upgrade && brew cleanup -s`).
- Upgrades `chezmoi` and runs `chezmoi apply --refresh-externals`.
- Updates `aqua` and vacuums packages unused for >30 days.
- Updates Sheldon Zsh plugin locks.
- Logs full output to `~/.local/state/nredf/daily-sync.log`.

Check agent status anytime:

```bash
launchctl list | grep nredf
```

### 5. Quiet Terminal Launches (`.hushlogin`)

macOS by default prints `Last login: <date> on <tty>` on every login shell, causing unnecessary I/O. NREDF installs an empty `~/.hushlogin` to suppress this banner and accelerate terminal rendering.

---

## ❓ FAQ & Troubleshooting

### Q1: "xcode-select: note: install requested for command line developer tools"

**Cause**: Fresh macOS installations require Apple developer command-line tools for C compilers and Git headers.
**Resolution**: Run `xcode-select --install` and complete the Apple dialog prompt.

### Q2: Homebrew permissions error (`/opt/homebrew is not writable`)

**Cause**: Permissions issue often occurring after macOS major OS upgrades.
**Resolution**:

```bash
sudo chown -R $(whoami):admin /opt/homebrew
```

### Q3: Terminal icons appear as broken boxes in Apple Terminal

**Cause**: Apple Terminal does not support third-party font fallback for icons without manual configuration.
**Resolution**:

- Use **Kitty** (installed automatically via Homebrew cask in `.chezmoidata/packages.yaml`).
- Or open Apple Terminal &rarr; **Settings** &rarr; **Profiles** &rarr; **Font** and select **FiraMono Nerd Font Mono**.
