# Core Features & Tools Reference Guide

This document provides a comprehensive reference for the developer tools and CLI utilities included and configured within the **NREDF** dotfiles ecosystem across **Linux**, **macOS**, and **Windows**.

---

## 🧰 Builtin Tooling Overview

All core CLI tools are declared centrally in [`home/dot_config/aquaproj-aqua/aqua.yaml`](../home/dot_config/aquaproj-aqua/aqua.yaml) and installed via **aqua**.

| Category | Primary Tools | Role / Description |
| :--- | :--- | :--- |
| **Dotfiles & Packages** | `chezmoi`, `aqua`, `sheldon` | Declarative system state & tool management |
| **Shell & History** | `oh-my-posh`, `atuin`, `fzf`, `zoxide`, `carapace` | Prompt, encrypted history sync, fuzzy search, smart cd, multi-shell completion |
| **CLI Replacements** | `lsd`, `bat`, `delta`, `ripgrep`, `fd`, `procs` (`pst`) | Modern, colored replacements for `ls`, `cat`, `diff`, `grep`, `find`, `ps auxf` |
| **Multiplexer** | `zellij` | Builtin modern terminal workspace & multiplexer |
| **File Management** | `yazi` (`yy`) | Fast async terminal file manager with custom plugins |
| **Git UI** | `lazygit` (`lzg` / `lg`) | Interactive terminal Git management |
| **Containers & Logs** | `lazydocker` (`lzd`), `lazyjournal` (`lzj` / `lj`), `lnav` | Terminal UIs for Docker management, log aggregation, and SQL log analysis |
| **System Monitoring** | `bottom` (`btm`) | Real-time interactive system resource & process monitor |
| **Kubernetes** | `kubectl`, `kubectx`, `kubens`, `k9s`, `helm` | Container orchestration, context switching, and TUI |
| **Network & Transfers** | `curl`, `wget` | Hardened, XDG-compliant network transfer clients |
| **Developer Ecosystem** | `gh`, `uv`, `ruff`, `mise` | GitHub CLI, Python toolchain, and runtime manager |

---

## 🖥️ Builtin Terminal Multiplexer: Zellij

**Zellij** is the default and builtin terminal workspace manager in NREDF. It is configured in [`home/dot_config/zellij/config.kdl.tmpl`](../home/dot_config/zellij/config.kdl.tmpl) with the unified **OneDark-Pro** theme.

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

### Automatic Startup & Session Attachment

- **Remote SSH Sessions**: When connecting over SSH, NREDF automatically attaches or creates a host-named Zellij session (enabled by default; controlled by `shell.multiplexer` / `NREDF_SHELL_MULTIPLEXER`).
- **WSL Sessions**: On Windows Subsystem for Linux (WSL), automatic multiplexer attachment is **disabled by default** so terminal tabs behave as independent native shells. You can opt in by:
  - Running `chezmoi init --prompt && chezmoi apply` and enabling the WSL multiplexer prompt (or setting `wsl_multiplexer = true` under `[data.shell]` in `~/.config/chezmoi/chezmoi.toml`).
  - Exporting `export NREDF_SHELL_WSL_MULTIPLEXER=true` in `~/.config/bash/rc` or `~/.config/zsh/rc`.

---

## 💲 Prompt: Oh-My-Posh

All five shells render the same theme, [`home/dot_config/oh-my-posh/config.json`](../home/dot_config/oh-my-posh/config.json). Every segment below appears only when it has something to say:

- **Left, line one**: OS icon, a red root indicator, `user@host` (only over SSH), the shell, the path, and git. The git segment shows `*` stashes, `~` conflicts, `+` staged, `!` unstaged, `✘` deleted and `?` untracked files. Submodule worktrees are not scanned (`ignore_submodules: dirty`), which keeps large repositories fast.
- **Right, line one**: exit status, the duration of commands that ran longer than 3s, versions of Node, Go, Python and Rust in matching projects, the Terraform workspace, the Helm version inside a chart or helmfile directory, the Docker context when it points somewhere other than a local daemon, and the time.
- **Line two**: the Kubernetes context and namespace, always visible so that you can see which cluster you are working against.
- **Tooltips** (zsh, fish and PowerShell only): while you type `git`, `lg`, `lzg` or `lazygit`, the right prompt shows the upstream branch and the last commit.

Shells cache their oh-my-posh init script for 24 hours, and tooltip, transient and secondary prompt settings are part of that script. After changing those settings, run `reload -c` so the script is regenerated.

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
| <kbd>Ctrl</kbd> + <kbd>t</kbd> | Zsh, Bash, Fish, Nushell, pwsh | `bat` syntax highlighted preview | Fuzzy search files in workspace |
| <kbd>Alt</kbd> + <kbd>c</kbd> / <kbd>Option</kbd>+<kbd>c</kbd> | Zsh, Bash, Fish, Nushell, pwsh | `lsd --tree` preview | Fuzzy search directories and `cd` |
| <kbd>Ctrl</kbd> + <kbd>/</kbd> | Any fzf window | &mdash; | Toggle preview window (hidden/bottom/right) |
| <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd> | Any fzf window | &mdash; | Multi-select items / move cursor |

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

## 🔍 Fast Search & File Discovery: ripgrep & fd

### `ripgrep` (`rg`)

Configured via `$RIPGREP_CONFIG_PATH` pointing to [`home/dot_config/ripgrep/config`](../home/dot_config/ripgrep/config):

- **Smart Case**: Case-insensitive searches when queries are lowercase; case-sensitive when uppercase characters are typed.
- **Hidden Files**: Automatically searches dotfiles while ignoring internal `.git` repository trees.
- **Terminal Protection**: Truncates lines longer than 150 columns (`--max-columns=150` and `--max-columns-preview`) to prevent terminal freezing on minified assets.
- **OneDark-Pro Palette**: Matches terminal highlights with bold blue paths (`#61afef`), yellow line numbers (`#e5c07b`), and bold red matches (`#e06c75`).

### `fd`

Configured with global ignore rules in [`home/dot_config/fd/ignore`](../home/dot_config/fd/ignore):

- Automatically excludes noise such as `.git/`, `node_modules/`, `vendor/bundle/`, `__pycache__/`, `.venv/`, `.turbo/`, `.cache/`, `.DS_Store`, and `Thumbs.db`.

---

## 🌐 Network & Transfer Utilities: curl & wget

Both utilities follow strict **XDG Base Directory** specifications to prevent cluttering `$HOME`.

### `curl`

Configured in [`home/dot_config/curlrc.tmpl`](../home/dot_config/curlrc.tmpl) (`$XDG_CONFIG_HOME/curlrc`):

- **HTTPS Enforcement**: Defaults schemeless URLs to HTTPS (`proto-default = "https"`).
- **Automated Redirects**: Automatically follows HTTP 3xx redirects (`location`, `max-redirs = 50`).
- **Compression**: Enables automated gzip/brotli/zstd response decompression (`compressed`).
- **Resilient Timeouts**: Caps connection negotiation at 30 seconds (`connect-timeout = 30`).
- **Error Visibility**: Ensures error details remain visible even when running silent mode (`show-error`).

### `wget`

Configured via `$WGETRC` pointing to [`home/dot_config/wgetrc.tmpl`](../home/dot_config/wgetrc.tmpl) (`$XDG_CONFIG_HOME/wgetrc`):

- **Resilient Downloads**: Resumes interrupted transfers (`continue = on`) with a 3-try limit and 30-second timeout.
- **Timestamping**: Re-downloads files only when remote copies are newer (`timestamping = on`).
- **Security**: Validates TLS certificates by default (`check_certificate = on`).
- **Cache Cleanliness**: Relocates the HSTS tracking database to `~/.cache/wget-hsts`, eliminating home directory clutter.

---

## 🗂️ Terminal File Manager: Yazi

[Yazi](https://yazi-rs.github.io) is an ultra-fast terminal file manager written in Rust.

### Features & Plugins Configured

NREDF configures Yazi with the following plugins in [`home/dot_config/yazi/keymap.toml.tmpl`](../home/dot_config/yazi/keymap.toml.tmpl):

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

## 🌿 Terminal Git UI: LazyGit (`lzg` / `lg`)

Launch interactive Git management with `lzg` or `lg` (or <kbd>Space</kbd> <kbd>g</kbd> <kbd>g</kbd> in Neovim).

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

## 🔧 Git & SSH Configuration

Git reads [`home/dot_config/git/config.tmpl`](../home/dot_config/git/config.tmpl) from `~/.config/git/config`. It sets `delta` as the pager, `zdiff3` conflicts, histogram diffs, `rerere`, `fetch.prune`, `push.autoSetupRemote`, rebase-on-pull and a set of short aliases (`git st`, `git lg`, `git gone`, ...).

- **Local overrides**: chezmoi rewrites `~/.config/git/config` on every apply, so a `git config --global` edit does not last. Put machine-local settings in `~/.config/git/config.local` (for example `git config --file ~/.config/git/config.local user.email work@example.com`). It is included last, so it overrides everything, and git skips it if it does not exist.
- **Commit & tag signing**: with a signing key configured (see the [Secrets Guide](secrets.md)), commits are signed. Tags are signed only on request (`git tag -s`), so a scripted `git tag <name>` still makes a lightweight tag instead of opening an editor. For `gpg.format = ssh`, `~/.config/git/allowed_signers` is rendered from your email and public key so `git log --show-signature` and `git verify-commit` can verify your own signatures.
- **Global ignore**: [`~/.config/git/ignore`](../home/dot_config/git/ignore) ignores OS and editor junk (`.DS_Store`, `Thumbs.db`, `*.swp`, `.idea/`, `.direnv/`, ...) in every repository.
- **SSH**: [`~/.ssh/config`](../home/private_dot_ssh/private_config.tmpl) loads `~/.ssh/config.d/*` first, then `~/.ssh/config.override` (created once, never overwritten), then the `Host *` defaults (agent, keep-alive, connection multiplexing). OpenSSH uses the first value it finds for each option, so the earlier files win.

---

## 🐳 Container Management: lazydocker (`lzd`)

[lazydocker](https://github.com/jesseduffield/lazydocker) is an interactive terminal UI for both Docker and Docker Compose environments, aliased to `lzd`:

| Keybinding | Action |
| :--- | :--- |
| <kbd>1</kbd> &ndash; <kbd>4</kbd> | Jump panels (Services/Containers, Images, Volumes, System) |
| <kbd>Space</kbd> | Pause / Unpause container |
| <kbd>r</kbd> | Restart container / service |
| <kbd>s</kbd> | Stop container / service |
| <kbd>d</kbd> | Remove container, image, or volume |
| <kbd>m</kbd> | View logs (stream container logs in dedicated viewer) |
| <kbd>e</kbd> | Exec into container (opens interactive shell) |
| <kbd>[</kbd> / <kbd>]</kbd> | Previous / next tab in detailed panel (Logs, Stats, Config, Top) |
| <kbd>b</kbd> | Open bulk commands menu (stop all, clean all, prune) |
| <kbd>/</kbd> | Filter items in active list |
| <kbd>?</kbd> | Open keybindings and help menu |
| <kbd>q</kbd> | Quit lazydocker |

---

## 🪵 Log Analysis & Navigation: lazyjournal (`lzj` / `lj`) & lnav

### 1. `lazyjournal` (`lzj` / `lj`)

[lazyjournal](https://github.com/Lifailon/lazyjournal) is an all-in-one TUI for querying and navigating logs across multiple sources, aliased to `lzj` (and `lj`):

- **Supported Sources**: Systemd `journald`, `auditd`, local log files, Docker/Podman containers, Docker Compose stacks, and Kubernetes pods.
- **Key Features**: Live streaming, multi-level log syntax highlighting, regex filtering, and custom search queries.
- **Keybindings**:
  - <kbd>/</kbd>: Start search / regex query
  - <kbd>f</kbd>: Open filter menu
  - <kbd>h</kbd>: Toggle log highlighting
  - <kbd>r</kbd>: Refresh / reload logs
  - <kbd>?</kbd>: Open help cheat sheet
  - <kbd>q</kbd>: Quit

### 2. `lnav` (Log File Navigator)

[lnav](https://lnav.org) is an advanced log viewer with an embedded SQLite query engine:

- **Format Auto-Detection**: Automatically parses syslog, Apache, nginx, JSON logs, systemd, and more without manual setup.
- **Timeline & Zoom**: Press <kbd>t</kbd> to view logs on a timeline; press <kbd>z</kbd> / <kbd>Z</kbd> to zoom in / out.
- **Error Navigation**: Jump directly to errors with <kbd>e</kbd> (next error) and <kbd>E</kbd> (previous error), or warnings with <kbd>w</kbd> / <kbd>W</kbd>.
- **Interactive Filtering**:
  - <kbd>&amp;</kbd> `<pattern>`: Filter in (show only matching lines)
  - <kbd>-</kbd> `<pattern>`: Filter out (hide matching lines)
- **SQL Queries**: Query your structured log data in real time:

  ```sql
  ;SELECT log_time, log_level, log_message FROM log WHERE log_level = 'error' ORDER BY log_time DESC
  ```

---

## 📊 System Resource Monitoring: bottom (btm)

[bottom](https://github.com/ClementTsang/bottom) is an interactive, cross-platform graphical system and process monitor displaying CPU cores, memory, disk I/O, network bandwidth, and a process tree themed with **OneDark-Pro**:

- <kbd>?</kbd>: Open help / keybindings
- <kbd>Tab</kbd>: Cycle through active widgets
- <kbd>/</kbd>: Search and filter processes
- <kbd>t</kbd>: Toggle process tree view
- <kbd>d</kbd> / <kbd>k</kbd>: Send terminate/kill signal to selected process
- <kbd>s</kbd>: Change process sort criteria
- <kbd>q</kbd> / <kbd>Ctrl</kbd> + <kbd>c</kbd>: Quit

---

## 📖 Markdown, System Info & Disk Usage: glow, fastfetch & dust

### `glow`

Configured in [`home/dot_config/glow/glow.yml.tmpl`](../home/dot_config/glow/glow.yml.tmpl):

- Terminal Markdown reader configured with dark styling, mouse scrolling, and pager support.

### `fastfetch`

Configured in [`home/dot_config/fastfetch/config.jsonc.tmpl`](../home/dot_config/fastfetch/config.jsonc.tmpl):

- Clean, structured system information dashboard themed with **OneDarkPro** accent colors.

### `dust`

Configured in [`home/dot_config/dust/config.toml.tmpl`](../home/dot_config/dust/config.toml.tmpl):

- Interactive disk usage tool configured with `reverse = true` (largest directories positioned at the bottom next to the prompt) and right-aligned progress bars.

---

## ☸️ Kubernetes Tooling Suite

Declarative Kubernetes management configured across all operating systems:

| Command / Tool | Description |
| :--- | :--- |
| `k` | Alias for `kubectl` |
| `kctx` / `ctx` | Shorthand for `kubectx` (interactive context selection) |
| `kns` / `ns` | Shorthand for `kubens` (interactive namespace selection) |
| `k9s` | Rich full-screen terminal UI for Kubernetes clusters |

### `k9s` Quick Keys & Plugins

Configured in [`home/dot_config/k9s/`](../home/dot_config/k9s/):

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

## 🛠️ Developer Ecosystem: gh, uv, ruff & mise

### `gh` (GitHub CLI)

Configured via `$GH_CONFIG_DIR` pointing to [`home/dot_config/private_gh/config.yml.tmpl`](../home/dot_config/private_gh/config.yml.tmpl):

- Configured to use SSH Git protocol, Neovim (`editor: nvim`), and `delta` as the default diff pager.

### `uv` & `ruff` (Python Toolchain)

- **`uv`**: Configured in [`home/dot_config/uv/uv.toml.tmpl`](../home/dot_config/uv/uv.toml.tmpl) to prefer managed Python versions (`python-preference = "managed"`).
- **`ruff`**: Configured in [`home/dot_config/ruff/ruff.toml.tmpl`](../home/dot_config/ruff/ruff.toml.tmpl) with 88-character line length, Python 3.12 target, and standard flake8/isort rule selection.

### `mise`

Configured in [`home/dot_config/mise/config.toml.tmpl`](../home/dot_config/mise/config.toml.tmpl) to automatically detect legacy version files (`.nvmrc`, `.python-version`, etc.) and auto-install missing tool runtimes. Also manages default global runtimes and tools (such as Node.js, Microsoft's `apm`, and Microsoft's `inshellisense` / `is` on-demand autocomplete).

---

## 🤖 AI Coding CLIs: Claude Code & Antigravity

Both are installed and version-pinned by aqua (`claude` from `anthropics/claude-code`, `agy` from `google-antigravity/antigravity-cli`), so Renovate bumps them like every other tool.

Their user-level `settings.json` files are written by the tools themselves (`/config`, "always allow" grants), so chezmoi **merges** into them instead of replacing them. The defaults live in data files, and the merge rules in [`merge-json-settings.tmpl`](../home/.chezmoitemplates/merge-json-settings.tmpl):

| Tool | Deployed to | Defaults |
| :--- | :--- | :--- |
| Claude Code | `~/.claude/settings.json` | [`claude.yaml`](../home/.chezmoidata/claude.yaml) |
| Antigravity CLI | `~/.gemini/antigravity-cli/settings.json` | [`antigravity.yaml`](../home/.chezmoidata/antigravity.yaml) |

Each data file has up to three sections:

- **`settings`**: top-level keys chezmoi **owns**. They are reset on every apply, so change them in the data file, not in the tool.
- **`merge`**: an object merged key by key. Your own keys under it survive.
- **`union`**: list entries are added and never removed, so permission rules you approved while working are kept.

Everything else in the file (allow rules, hooks, model, ...) is left alone. Invalid JSON aborts the apply instead of being overwritten.

What Claude Code gets by default: background auto-update off (aqua owns the version; `claude update` still works), no survey or spinner tips, and deny rules for secrets. The deny rules cover `.env` files, `~/.ssh`, the vault-fed `~/.config/nredf/mcp.json`, and `bw get`/`list`/`export`/`unlock`, since `BW_SESSION` is present in every child process. To drop a deny rule, remove it from `claude.yaml` **and** from `~/.claude/settings.json`.

### `zclaude`: Persistent Claude Supervisor with Keep-Alive & Auto-Retry

`zclaude` is a cross-platform supervisor for Claude Code that integrates natively with Zellij, keeping sessions active across system idle sleep and automatically resuming long-running tasks when rate limits reset:

- **Multiplexer Integration**: Uses Zellij's native CLI (`dump-screen`, `write-chars`, `send-keys`) instead of `tmux`, working identically on Linux, macOS, and Windows.
- **Dedicated AI Layout (`zclaude`)**: Features a 72% primary Claude pane flanked by a command terminal and suspended `lazygit`, secondary tabs for code editing and `bottom` monitoring, and dynamic swap layouts.
- **System Keep-Alive**: Prevents system and idle sleep while Claude is active and while waiting out limits (`caffeinate` on macOS, Win32 `SetThreadExecutionState` on Windows, and `systemd-inhibit` on Linux).
- **Auto-Resumption**: Accurately parses limit reset times (e.g. `resets 3:15 PM` or relative duration) from viewport dumps and transcripts, safely dismisses any interactive `/rate-limit-options` dialog with `Esc`, and injects `continue` once the reset time (+ safety margin) arrives. Handles transient 529/503 overloads with progressive backoff.
- **Claude CLI Option Parity**: Forwards common Claude Code flags seamlessly:
  - `-r, --resume [ID]`: Resume an existing session or open the interactive picker.
  - `-c, --continue`: Continue the latest session in the directory.
  - `-p, --print`: Run non-interactively and stream response.
  - `-m, --model <MODEL>`: Switch model (`sonnet`, `opus`, `haiku`).
  - `--dangerously-skip-permissions`: Bypass permission prompts for unattended execution.
  - `--effort <low|medium|high|max>`: Control reasoning effort depth.
  - `-w, --worktree [NAME]`: Branch off into an isolated git worktree.
- **Dual Execution Modes**:
  - **Integrated run**: `zclaude [args...]` wraps Claude directly in the current Zellij pane (or starts a Zellij session if run outside).
  - **Watcher mode**: `zclaude -W/--watch [pane_id]` monitors an existing Claude pane in Zellij as a sidecar or companion pane.

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

- **Automatic Secret Store Sync (Recommended)**: Use the builtin [Secrets Management Guide](secrets.md) to automatically resolve and populate `AQUA_GITHUB_TOKEN` from Bitwarden, KeePassXC, or 1Password.
- **System Keyring / Local File Fallback**: Run `nredf_aqua_token_setup` to store a token in your OS keyring (or in `~/.config/nredf/aqua.env` on headless/WSL systems where no secret service is available).
- **Manual Environment Variable**: Export `AQUA_GITHUB_TOKEN` or `GITHUB_TOKEN` in your environment.
