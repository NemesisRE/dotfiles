# Core Features & Tools Reference Guide

This document provides a comprehensive reference for the developer tools and CLI utilities included and configured within the **NREDF** dotfiles ecosystem across **Linux**, **macOS**, and **Windows**.

---

## 🧰 Builtin Tooling Overview

All core CLI tools are declared centrally in [`home/dot_config/aquaproj-aqua/aqua.yaml`](file:///Users/skurz/Repos/chezmoi/home/dot_config/aquaproj-aqua/aqua.yaml) and installed via **aqua**.

| Category | Primary Tools | Role / Description |
| :--- | :--- | :--- |
| **Dotfiles & Packages** | `chezmoi`, `aqua`, `sheldon` | Declarative system state & tool management |
| **Shell & History** | `oh-my-posh`, `atuin`, `fzf`, `zoxide` | Prompt, encrypted history sync, fuzzy search, smart cd |
| **CLI Replacements** | `lsd`, `bat`, `delta`, `ripgrep`, `fd` | Modern, colored replacements for `ls`, `cat`, `diff`, `grep`, `find` |
| **Multiplexer** | `zellij` | Builtin modern terminal workspace & multiplexer |
| **File Management** | `yazi` (`yy`) | Fast async terminal file manager with custom plugins |
| **Git UI** | `lazygit` (`lg`) | Interactive terminal Git management |
| **System & Containers** | `btop`, `ctop` | System resource & Docker container monitors |
| **Kubernetes** | `kubectl`, `kubectx`, `kubens`, `k9s`, `helm` | Container orchestration, context switching, and TUI |

---

## 🖥️ Builtin Terminal Multiplexer: Zellij

**Zellij** is the default and builtin terminal workspace manager in NREDF. It is configured in [`home/dot_config/zellij/config.kdl.tmpl`](file:///Users/skurz/Repos/chezmoi/home/dot_config/zellij/config.kdl.tmpl) with the unified **OneDark-Pro** theme.

### Zellij Modal Architecture
Zellij uses a modal interface where a shortcut switches you into a specific mode:

```text
Normal Mode ──┬──► Ctrl + p : Pane Mode (split, focus, float, fullscreen)
              ├──► Ctrl + t : Tab Mode (new tab, close tab, rename, sync)
              ├──► Ctrl + n : Resize Mode (increase/decrease dimensions)
              ├──► Ctrl + s : Scroll & Search Mode (search buffer, edit scrollback)
              ├──► Ctrl + o : Session Mode (detach, manage sessions)
              ├──► Ctrl + h : Move Mode (reorder and swap panes)
              ├──► Ctrl + b : Tmux Compatibility Mode
              └──► Ctrl + g : Locked Mode (passes all keys directly to inner apps)
```

---

### Zellij Keyboard Shortcuts Cheatsheet

#### 1. Pane Mode (<kbd>Ctrl</kbd> + <kbd>p</kbd>)
Enter pane mode, then press:
- <kbd>d</kbd>: New pane split **Down**
- <kbd>r</kbd>: New pane split **Right**
- <kbd>n</kbd>: New generic pane
- <kbd>x</kbd>: Close focused pane
- <kbd>f</kbd>: Toggle fullscreen on current pane
- <kbd>w</kbd>: Toggle floating panes
- <kbd>e</kbd>: Toggle pane between embedded and floating
- <kbd>c</kbd>: Rename pane
- <kbd>h</kbd> / <kbd>j</kbd> / <kbd>k</kbd> / <kbd>l</kbd> (or Arrows): Move focus Left / Down / Up / Right
- <kbd>Esc</kbd> or <kbd>Enter</kbd>: Return to Normal mode

#### 2. Tab Mode (<kbd>Ctrl</kbd> + <kbd>t</kbd>)
Enter tab mode, then press:
- <kbd>n</kbd>: New tab
- <kbd>x</kbd>: Close active tab
- <kbd>r</kbd>: Rename tab
- <kbd>s</kbd>: Toggle active sync (broadcast keystrokes to all panes in tab)
- <kbd>h</kbd> / <kbd>k</kbd> (or <kbd>&larr;</kbd>): Go to previous tab
- <kbd>l</kbd> / <kbd>j</kbd> (or <kbd>&rarr;</kbd>): Go to next tab
- <kbd>1</kbd> &ndash; <kbd>9</kbd>: Jump directly to tab 1 &ndash; 9
- <kbd>[</kbd> / <kbd>]</kbd>: Break active pane out into a new tab (left/right)

#### 3. Resize Mode (<kbd>Ctrl</kbd> + <kbd>n</kbd>)
Enter resize mode, then press:
- <kbd>h</kbd> / <kbd>j</kbd> / <kbd>k</kbd> / <kbd>l</kbd>: Increase pane size in that direction
- <kbd>H</kbd> / <kbd>J</kbd> / <kbd>K</kbd> / <kbd>L</kbd>: Decrease pane size in that direction
- <kbd>+</kbd> / <kbd>=</kbd>: Increase overall size
- <kbd>-</kbd>: Decrease overall size

#### 4. Scroll & Search Mode (<kbd>Ctrl</kbd> + <kbd>s</kbd>)
Enter scroll mode, then press:
- <kbd>s</kbd>: Open interactive search prompt
- <kbd>n</kbd> / <kbd>p</kbd>: Search next / previous match
- <kbd>c</kbd>: Toggle case sensitivity
- <kbd>w</kbd>: Toggle whole-word matching
- <kbd>j</kbd> / <kbd>k</kbd>: Scroll down / up line by line
- <kbd>d</kbd> / <kbd>u</kbd>: Half-page scroll down / up
- <kbd>Ctrl</kbd> + <kbd>f</kbd> / <kbd>Ctrl</kbd> + <kbd>b</kbd>: Full page scroll down / up
- <kbd>e</kbd>: **Edit Scrollback**: Open the entire terminal buffer directly in Neovim!

#### 5. Locked Mode (<kbd>Ctrl</kbd> + <kbd>g</kbd>)
Press <kbd>Ctrl</kbd> + <kbd>g</kbd> to lock Zellij. All keystrokes pass directly to inner applications (such as Neovim or remote shells) without collision. Press <kbd>Ctrl</kbd> + <kbd>g</kbd> again to unlock.

---

## 📜 Encrypted Shell History: Atuin

[Atuin](https://atuin.sh) replaces your default shell history with an SQLite database backed by end-to-end encrypted synchronization across machines.

### Daily Usage
- **Search History**: Press <kbd>Ctrl</kbd> + <kbd>r</kbd> in any shell (or <kbd>&uarr;</kbd> in PowerShell).
- **Filter Modes**: While searching, press:
  - <kbd>Ctrl</kbd> + <kbd>r</kbd>: Cycle search modes (`HOST`, `SESSION`, `DIRECTORY`, `GLOBAL`).
  - <kbd>Tab</kbd>: Return selected command to prompt without executing.
  - <kbd>Enter</kbd>: Execute selected command immediately.
  - <kbd>Delete</kbd>: Delete highlighted entry from history.

### Synchronizing Machines
```bash
# First machine: create an account
atuin register -u <username> -e <email>
atuin key  # Back up your encryption key!

# Subsequent machines: log in
atuin login -u <username>
atuin sync
```

---

## 🔍 Interactive Fuzzy Finding: fzf & PSFzf

Configured with custom **OneDark-Pro** theme colors and preview commands:

| Keybinding | Shells | Preview | Action |
| :--- | :--- | :--- | :--- |
| <kbd>Ctrl</kbd> + <kbd>t</kbd> | Zsh, Bash, pwsh | `bat` syntax highlighted preview | Fuzzy search files in workspace |
| <kbd>Alt</kbd> + <kbd>c</kbd> / <kbd>Option</kbd>+<kbd>c</kbd> | Zsh, Bash, pwsh | `lsd --tree` preview | Fuzzy search directories and `cd` |
| <kbd>Ctrl</kbd> + <kbd>/</kbd> | Any fzf window | &mdash; | Toggle preview window (hidden/bottom/right) |
| <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd>| Any fzf window | &mdash; | Multi-select items / move cursor |

### SSH & Network Completions
Typing `ssh **` or `scp **` followed by <kbd>Tab</kbd> automatically fuzzy searches known hosts across:
- `~/.ssh/config` and `/etc/ssh/ssh_config`
- `~/.ssh/known_hosts`
- `~/.ssh/hosts` and `/etc/hosts`

---

## 🧭 Smart Directory Jumping: zoxide

`zoxide` replaces the standard `cd` command across all shells:

- `cd <partial-name>`: Jumps to the most frequently/recently visited match.
- `cd ../..`: Behaves as standard relative directory traversal.
- `z <name>`: Shorthand jump alias.
- `zi`: Interactive fuzzy search directory picker powered by `fzf`.

---

## 📁 Modern File Listing & Viewing: lsd & bat

### `lsd` (Next-Gen `ls`)
- `ls`: Colorized listing with file type icons.
- `ll`: Long format listing with Git modified flags (`--git`) and permissions.
- `la`: Long format including hidden dotfiles.
- `tree`: Full recursive directory tree with icons.

### `bat` (Syntax-Highlighted `cat`)
- Aliased to `cat` in PowerShell and used as the default preview engine in `fzf`.
- Uses the **OneDarkPro** theme (`~/.config/bat/themes/OneDarkPro.tmTheme`).
- Displays line numbers, Git modifications in the gutter, and automatic syntax detection.

---

## 🗂️ Terminal File Manager: Yazi

[Yazi](https://yazi-rs.github.io) is an ultra-fast terminal file manager written in Rust.

### Features & Plugins Configured
NREDF configures Yazi with the following plugins in [`home/dot_config/yazi/keymap.toml.tmpl`](file:///Users/skurz/Repos/chezmoi/home/dot_config/yazi/keymap.toml.tmpl):
- **Smart Enter (`l`)**: Enters directory or opens file in Neovim automatically.
- **Smart Paste (`p`)**: Intelligently pastes into the hovered folder or CWD.
- **Git VCS Changes (`g` `c`)**: Filters and shows only Git modified files.
- **File Permissions (`c` `m`)**: Quick `chmod` on selected files.
- **File Diff (<kbd>Ctrl</kbd> + <kbd>d</kbd>)**: Compare the selected file with hovered file.
- **Smart Filter (`F`)**: Interactive live filter.
- **Zoom (`+` / `-`)**: Zoom in / out on hovered previews.
- **Mount (`M`)**: Interactive mount plugin.

### Shell Working Directory Integration (`yy`)
Use the `yy` alias in any shell to launch Yazi. When you exit with <kbd>q</kbd>, your shell automatically changes directories to the folder you were navigating!

---

## 🌿 Terminal Git UI: LazyGit (`lg`)

Launch interactive Git management with `lg` (or <kbd>Space</kbd> <kbd>g</kbd> <kbd>g</kbd> in Neovim).

| Keybinding | Action |
| :--- | :--- |
| <kbd>1</kbd> &ndash; <kbd>5</kbd> | Jump to panel (Status, Files, Branches, Commits, Stash) |
| <kbd>Space</kbd> | Stage / unstage file or hunk |
| <kbd>c</kbd> | Commit staged changes (opens editor prompt) |
| <kbd>P</kbd> | Push to remote repository |
| <kbd>p</kbd> | Pull from remote repository |
| <kbd>b</kbd> | View branch list / create branch |
| <kbd>w</kbd> | Open commit message menu |
| <kbd>e</kbd> | Edit selected file in Neovim |
| <kbd>/</kbd> | Search / filter items in active panel |
| <kbd>?</kbd> | Show all available keybindings for the current panel |
| <kbd>q</kbd> | Quit LazyGit |

Configured with the **OneDark-Pro** color scheme and integrates with `delta` for side-by-side diff previews.

---

## 📊 System & Container Monitoring: btop & ctop

### `btop`
Real-time system monitor displaying CPU cores, memory, disk I/O, network bandwidth, and process tree:
- <kbd>m</kbd>: Open main menu / settings
- <kbd>e</kbd>: Toggle process tree view
- <kbd>f</kbd>: Filter processes by name
- <kbd>k</kbd>: Send terminate/kill signal to selected process
- <kbd>1</kbd> &ndash; <kbd>4</kbd>: Change sort criteria
- <kbd>q</kbd>: Quit

### `ctop`
Top-like container resource monitoring for Docker:
- Real-time metrics for CPU, memory, network, and disk I/O per container.
- <kbd>Enter</kbd>: Open container menu (view logs, inspect, shell into container).
- <kbd>s</kbd>: Change sort field.
- <kbd>p</kbd>: Pause / unpause container.
- <kbd>q</kbd>: Quit.

---

## ☸️ Kubernetes Tooling Suite

Declarative Kubernetes management configured across all operating systems:

| Command / Tool | Description |
| :--- | :--- |
| `k` | Alias for `kubectl` |
| `kctx` / `ctx` | Shorthand for `kubectx` (interactive context selection) |
| `kns` / `ns` | Shorthand for `kubens` (interactive namespace selection) |
| `k9s` | Rich full-screen terminal UI for Kubernetes clusters |
| `dipls` | Custom function/alias to list all Docker containers with IP addresses and hostnames |

### `k9s` Quick Keys & Plugins
Configured in [`home/dot_config/k9s/`](file:///Users/skurz/Repos/chezmoi/home/dot_config/k9s/):
- **Resource Jump Keys**:
  - <kbd>F1</kbd>: Pods
  - <kbd>F2</kbd>: Contexts
  - <kbd>F3</kbd>: Helm Releases
  - <kbd>F4</kbd>: Deployments
  - <kbd>F5</kbd>: StatefulSets
  - <kbd>F6</kbd>: Services
  - <kbd>F7</kbd>: Endpoints
  - <kbd>F8</kbd>: Ingresses
  - <kbd>F9</kbd>: Secrets
  - <kbd>F10</kbd>: Events
  - <kbd>F11</kbd>: PersistentVolumes
  - <kbd>F12</kbd>: ServiceAccounts
- **Custom Plugins**:
  - <kbd>a</kbd> (in CSR view): Automatically approve certificate signing request (`kubectl certificate approve`).
  - <kbd>l</kbd> (in Backup view): Stream Velero backup logs.
  - <kbd>Ctrl</kbd> + <kbd>l</kbd> (in Backup view): Describe Velero backup.

---

## 🔄 Package & Tool Management: aqua

NREDF uses **aqua** to declaratively install, lock, and manage CLI tools across Linux, macOS, and Windows.

### Common Commands
```bash
aqua install             # Install all packages declared in aqua.yaml
aqua install -a -l       # Install and link all packages to bin/
aqua update              # Update package versions
aqua which <cmd>         # Show which binary aqua executes for <cmd>
aqua vacuum -d 30        # Clean up package versions unused for 30+ days
```

### Avoiding GitHub API Rate Limits
Aqua queries the GitHub API to download binaries. To eliminate rate limit errors:
```bash
# Store GitHub token securely in system keyring
aqua token set
```
Or set the environment variable `AQUA_GITHUB_TOKEN` or `GITHUB_TOKEN`.

