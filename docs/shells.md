# Unified Shells Guide: Zsh, Bash & PowerShell (pwsh)

This guide documents the shell architecture across **Linux**, **macOS**, and **Windows** in the **NREDF** dotfiles ecosystem, detailing feature parity, keybindings, aliases, functions, and configuration mechanics for **Zsh**, **Bash**, and **PowerShell (pwsh)**.

---

## 🧭 Shell Feature Parity Matrix

All three shells share a unified experience designed around modern developer ergonomics:

| Capability | Zsh | Bash | PowerShell (`pwsh`) |
| :--- | :--- | :--- | :--- |
| **Prompt Engine** | [Oh-My-Posh](https://ohmyposh.dev) (`OneDark-Pro`) | [Oh-My-Posh](https://ohmyposh.dev) (`OneDark-Pro`) | [Oh-My-Posh](https://ohmyposh.dev) (`OneDark-Pro`) |
| **History Sync & Search** | [Atuin](https://atuin.sh) (<kbd>Ctrl</kbd>+<kbd>r</kbd>) | [Atuin](https://atuin.sh) (<kbd>Ctrl</kbd>+<kbd>r</kbd>) | [Atuin](https://atuin.sh) (<kbd>Ctrl</kbd>+<kbd>r</kbd>, <kbd>UpArrow</kbd>) |
| **Fuzzy Finding** | `fzf` (<kbd>Ctrl</kbd>+<kbd>t</kbd>, <kbd>Alt</kbd>+<kbd>c</kbd>) | `fzf` (<kbd>Ctrl</kbd>+<kbd>t</kbd>, <kbd>Alt</kbd>+<kbd>c</kbd>) | `fzf` (<kbd>Ctrl</kbd>+<kbd>t</kbd>, <kbd>Alt</kbd>+<kbd>c</kbd>) |
| **Directory Navigation** | `zoxide` hooked to `cd`, `z`, `zi` | `zoxide` hooked to `cd`, `z`, `zi` | `zoxide` hooked to `cd`, `z`, `zi` |
| **Syntax Highlighting** | `fast-syntax-highlighting` | `ble.sh` (Bash Line Editor) | `PSReadLine` |
| **Inline Autosuggestions** | `zsh-autosuggestions` | `ble.sh` inline suggestions | `PSReadLine` (`HistoryAndPlugin`) |
| **Tab Completion Engine** | [Carapace](https://carapace.sh) (`carapace-bin` + `fzf-tab`) | [Carapace](https://carapace.sh) (`bash-ble` with descriptions) | [Carapace](https://carapace.sh) (native menu + `fzf` modal) |
| **Auto-Pairing Quotes** | `zsh-autopair` | `ble.sh` auto-complete | Custom `PSReadLine` chord (`"`, `'`) |
| **Plugin Manager** | [Sheldon](https://sheldon.cli.rs) | Git-cloned `ble.sh` | None required (100% native CLI tooling) |
| **Environment Sync** | `reload` (supports `-c`, `-d`, `-f`, `-p`, `-s`) | `reload` (supports `-c`, `-d`, `-f`, `-p`, `-s`) | `reload` (supports `-c`, `-d`, `-f`, `-p`, `-s`) |
| **Startup Profiling** | `reload -p` / `NREDF_PROFILE_STARTUP=1` | `reload -p` / `NREDF_PROFILE_STARTUP=1` | `reload -p` / `NREDF_PROFILE_STARTUP=1` |

---

## ⚙️ Shell Implementations & Initialization

### 1. Zsh Architecture

- **Dotfiles**: [`.zshenv.tmpl`](../home/dot_zshenv.tmpl), [`.zprofile.tmpl`](../home/dot_zprofile.tmpl), [`.zshrc.tmpl`](../home/dot_zshrc.tmpl)
- **Plugin Management**: Managed by **Sheldon** via [`~/.config/sheldon/plugins.toml`](../home/dot_config/sheldon/plugins.toml.tmpl)
  - Loads Oh-My-Zsh core libraries (`completion.zsh`, `functions.zsh`, `history.zsh`, `misc.zsh`, `spectrum.zsh`, `termsupport.zsh`, `theme-and-appearance.zsh`)
  - Curated plugins: `npm`, `rvm`, `extract`, `colored-man-pages`, `colorize`, `cp`, `git-extras`, `systemadmin`, `fzf-tab`, `fzf-zsh-completions`, `zsh-autopair`, `calc`, `zsh-autosuggestions`, `fast-syntax-highlighting`
  - **Lazy Loading**: Plugins are lazy-loaded on the first prompt display via `add-zsh-hook precmd` to guarantee sub-millisecond shell startup.
- **Completion Engine**: Managed by **Carapace** (`carapace-bin`) cached for 24 hours via `_nredf_refresh_cached_shell_snippet`, with custom declarative specs in `~/.config/carapace/specs/`.

### 2. Bash Architecture

- **Dotfiles**: [`.bash_profile.tmpl`](../home/dot_bash_profile.tmpl), [`.bashrc.tmpl`](../home/dot_bashrc.tmpl), [`.blerc.tmpl`](../home/dot_blerc.tmpl)
- **Engine**: Modern **Bash 4.4+ / 5.x** with [ble.sh](https://github.com/akinomyoga/ble.sh) (Bash Line Editor)
  - On macOS, automatically detects and invokes Homebrew Bash (`/opt/homebrew/bin/bash` or `/usr/local/bin/bash`), bypassing Apple's legacy Bash 3.2.
  - `ble.sh` sources at the top of `.bashrc` (`--attach=none`) and attaches at the very end (`ble-attach`), providing syntax highlighting, fish-like autosuggestions, vim-mode support, and menu completion in standard Bash.
- **Completion Engine**: Managed by **Carapace** (`carapace-bin`) running after system `bash_completion` and cached for 24 hours via `_nredf_refresh_cached_shell_snippet`, with custom declarative specs in `~/.config/carapace/specs/`.

### 3. PowerShell (pwsh) Architecture

- **Dotfiles**: [`home/Documents/PowerShell/`](../home/Documents/PowerShell/)
  - Target for PowerShell 7+: `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
  - Target for Windows PowerShell 5.1: `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (dot-sources PowerShell 7 profile)
  - Linux/macOS: `~/.config/powershell` is symlinked directly to `~/Documents/PowerShell`
- **Module Architecture (`NREDF-POSH`)**:
  - `Defaults.ps1`: XDG paths, Aqua paths, Python paths, UTF-8 output encoding, default formatting.
  - `Modules.ps1`: Zero external PowerShell modules required; hooks local overrides if configured.
  - `Aliases.ps1`: Cross-platform command parity with Bash/Zsh.
  - `PSReadLine.ps1`: Keybindings, prediction source (`HistoryAndPlugin`), native `fzf` integration, smart auto-pairing quotes.
  - `Functions.ps1`: Utility functions (`reload`, `sudo`, `md5`, `sha256`, `NREDF_DailySync`).
  - `Profile.ps1`: High-performance startup orchestration with snippet caching (`NREDF_RefreshCachedShellSnippet`) for Oh-My-Posh, Atuin, Zoxide, and **Carapace** completions (including custom specs in `~/.config/carapace/specs/`).

---

## ⌨️ Shell Keyboard Shortcuts

### 1. Zsh Keyboard Shortcuts

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| <kbd>Tab</kbd> | Completion Menu | Interactive tab completion with descriptions via fzf-tab |
| <kbd>Shift</kbd> + <kbd>Tab</kbd> | Backward Cycle | Cycle backward through completion candidates in fzf-tab |
| <kbd>Ctrl</kbd> + <kbd>Space</kbd> | fzf Tab Completion | Open interactive fzf completion modal with descriptions |
| <kbd>Ctrl</kbd> + <kbd>r</kbd> | Atuin Search | Interactive fuzzy search across full command history |
| <kbd>Ctrl</kbd> + <kbd>t</kbd> | Fzf File Search | Fuzzy search files in CWD and insert selected path at cursor |
| <kbd>Alt</kbd> + <kbd>c</kbd> / <kbd>Option</kbd>+<kbd>c</kbd> | Fzf CD | Fuzzy search subdirectories and immediately `cd` into selection |
| <kbd>&rarr;</kbd> (Right Arrow) | Autosuggestion Accept | Accept full ghost-text autosuggestion |
| <kbd>Ctrl</kbd> + <kbd>e</kbd> | Autosuggestion / EOL | Accept autosuggestion or jump to end of line |
| <kbd>Ctrl</kbd> + <kbd>a</kbd> | Beginning of Line | Move cursor to beginning of command line |
| <kbd>Ctrl</kbd> + <kbd>u</kbd> | Backward Kill Line | Clear line before cursor |
| <kbd>Ctrl</kbd> + <kbd>k</kbd> | Forward Kill Line | Clear line after cursor |
| <kbd>Ctrl</kbd> + <kbd>w</kbd> | Backward Kill Word | Delete word before cursor |
| <kbd>Ctrl</kbd> + <kbd>l</kbd> | Clear Screen | Clear terminal screen |

> [!NOTE]
> On macOS, Option+c produces `ç` or `©` by default. NREDF automatically binds `ç` and `©` to `fzf-cd-widget` in Zsh so directory fuzzy jumping works seamlessly without changing Terminal settings.

---

### 2. Bash Keyboard Shortcuts (with ble.sh)

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| <kbd>Tab</kbd> | Menu Completion | Open interactive ble.sh completion menu with Carapace descriptions |
| <kbd>Shift</kbd> + <kbd>Tab</kbd> | Backward Cycle | Cycle backward through completion candidates |
| <kbd>Ctrl</kbd> + <kbd>Space</kbd> | fzf Tab Completion | Open fzf fuzzy modal with completion candidates and descriptions |
| <kbd>Ctrl</kbd> + <kbd>r</kbd> | Atuin Search | Interactive fuzzy history search via `__atuin_history` |
| <kbd>Ctrl</kbd> + <kbd>t</kbd> | Fzf File Search | Fuzzy search files with live `bat` syntax preview |
| <kbd>Alt</kbd> + <kbd>c</kbd> / <kbd>Option</kbd>+<kbd>c</kbd> | Fzf CD | Fuzzy search directories with live `lsd` tree preview |
| <kbd>&rarr;</kbd> (Right Arrow) | ble.sh Complete | Accept highlighted completion candidate or inline autosuggestion |
| <kbd>Ctrl</kbd> + <kbd>x</kbd> <kbd>Ctrl</kbd> + <kbd>e</kbd> | Edit in $EDITOR | Open current command in Neovim/Vim, save to execute |
| <kbd>Ctrl</kbd> + <kbd>c</kbd> | Cancel / Interrupt | Abort current input or running process |
| <kbd>Ctrl</kbd> + <kbd>l</kbd> | Clear Screen | Clear terminal screen and redraw prompt |

---

### 3. PowerShell Keyboard Shortcuts (PSReadLine & fzf)

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| <kbd>Tab</kbd> | MenuComplete | Interactive terminal completion menu with Carapace descriptions |
| <kbd>Shift</kbd> + <kbd>Tab</kbd> | TabCompletePrevious | Cycle backward through completion candidates |
| <kbd>Ctrl</kbd> + <kbd>Space</kbd> | fzf Tab Completion | Open fzf fuzzy modal with completion candidates and descriptions |
| <kbd>Ctrl</kbd> + <kbd>r</kbd> / <kbd>&uarr;</kbd> | Atuin History Search | Full-screen interactive history search powered by Atuin |
| <kbd>Ctrl</kbd> + <kbd>t</kbd> | fzf File Search | Fuzzy search files with `bat` syntax preview |
| <kbd>Alt</kbd> + <kbd>c</kbd> / <kbd>Option</kbd>+<kbd>c</kbd> | fzf CD | Fuzzy search directories with `lsd` tree preview and jump |
| <kbd>Ctrl</kbd> + <kbd>d</kbd> | ViExit | Exit session if buffer is empty |
| <kbd>Alt</kbd> + <kbd>d</kbd> | ShellKillWord | Delete next word forward |
| <kbd>Alt</kbd> + <kbd>Backspace</kbd> | ShellBackwardKillWord | Delete previous word backward |
| <kbd>Alt</kbd> + <kbd>q</kbd> | SaveInHistory | Stash current line in history and clear buffer for a quick command |
| <kbd>"</kbd> or <kbd>'</kbd> | SmartInsertQuote | Automatically insert paired quotes and place cursor inside |
| <kbd>&rarr;</kbd> (Right Arrow) | Prediction Accept | Accept predictive IntelliSense suggestion from history/plugins |

---

## 🛠️ Unified Aliases & Functions

NREDF guarantees that common development commands behave identically regardless of your current shell or operating system:

| Command | Target Tool | Description |
| :--- | :--- | :--- |
| `ls` | `lsd` | Modern file listing with icons and colors |
| `ll` | `lsd -lFh --git` | Long format listing with Git status flags and human-readable sizes |
| `la` | `lsd -lAFh --git` | Detailed listing including hidden files and Git status |
| `tree` | `lsd --tree` | Recursive tree view with icons |
| `cat` | `bat` | Syntax-highlighted output with OneDark-Pro theme |
| `grep` | `rg` / `grep --color=auto` | Fast recursive ripgrep search |
| `lzg` / `lg` | `lazygit` | Terminal UI for Git |
| `lzd` | `lazydocker` | Terminal UI for Docker and Docker Compose |
| `lzj` / `lj` | `lazyjournal` | Terminal UI for multi-source log viewing & filtering |
| `k` | `kubectl` | Kubernetes CLI shorthand |
| `kctx` / `ctx` | `kubectx` | Fast Kubernetes context switcher |
| `kns` / `ns` | `kubens` | Fast Kubernetes namespace switcher |
| `dipls` | Custom Function | Output table of running Docker containers with IP addresses and names |
| `yy` | Custom Function | Open **Yazi** file manager; changes terminal working directory on exit |
| `cd <path>` | `zoxide` | Smart jump (falls back to standard `cd` if path exists) |
| `z <query>` | `zoxide query` | Jump directly to highest ranked directory matching query |
| `zi` | `zoxide query -i` | Interactive fuzzy search directory selection |

---

## 🔄 The Unified `reload` Command

Each shell provides a high-performance `reload` function with identical arguments:

```text
Usage: reload [options]

Options:
  -c, --cache       Delete 'Last Run Cache' and init script snippets
  -d, --downloads   Delete aqua pkgs (archives + binaries, keeps bin/ symlinks)
  -f, --full        Full refresh: clear caches + chezmoi / aqua / sheldon
  -l, --last-run    Delete only 'Last Run Cache'
  -p, --profile     Toggle startup profiling (or one-shot if combined with other options)
  -s, --shell NAME  Reload directly into a different shell (e.g. zsh, bash, pwsh)
  -h, --help        Show usage help
```

### Examples

- **Fast shell refresh**:

  ```bash
  reload
  ```

- **Measure shell startup latency**:

  ```bash
  reload -p
  ```

  *Prints step-by-step millisecond timings for Oh-My-Posh, Atuin, plugins, and custom functions.*
- **Switch to PowerShell from Bash/Zsh**:

  ```bash
  reload -s pwsh
  ```

- **Force clean rebuild of all CLI packages & cached scripts**:

  ```bash
  reload -f
  ```

---

## 📂 Yazi CWD Wrapper (`yy`)

Running standard `yazi` leaves the shell in whatever directory you started in. NREDF includes the `yy` function in **Zsh**, **Bash**, and **PowerShell**:

```bash
yy
```

When you navigate to a directory inside Yazi and quit with <kbd>q</kbd>, your shell automatically changes its working directory to the directory you were viewing in Yazi!

---

## 🔄 Automated Daily Maintenance & Hot-Reloading

NREDF decouples all periodic maintenance and network-heavy upgrade tasks from interactive shell startup. Interactive shells start in milliseconds without waiting on network checks, git pulls, or package managers.

### 1. Native Background Schedulers

Daily maintenance is scheduled natively per operating system via chezmoi:

- **macOS (`launchd`)**: `com.nredf.daily-sync.plist` (managed via `home/private_Library/private_LaunchAgents/com.nredf.daily-sync.plist.tmpl`).
- **Linux (`systemd --user`)**: `nredf-daily-sync.timer` & `nredf-daily-sync.service` in `~/.config/systemd/user/`.
- **Windows (Task Scheduler)**: `NREDF-DailySync` registered with `StartWhenAvailable` to catch up after sleep.

### 2. What Daily Maintenance Executes

The unified payload (`nredf-daily-sync` on POSIX, `NREDF_DailySync` on PowerShell) runs once daily in the background with low CPU and I/O priority:

1. **Package Upgrades**: Homebrew (`brew update && brew upgrade && brew cleanup -s` on macOS).
2. **Chezmoi Upgrade**: Upgrades the chezmoi binary.
3. **Dotfiles Remote Sync**: Fetches upstream dotfiles changes, fast-forwards Git, and runs `chezmoi apply --refresh-externals`.
4. **Aqua Tools**: Updates Aqua (`aqua update-aqua`), ensures tool links (`aqua install -a -l`), and vacuums packages unused for >30 days (`aqua vacuum -d 30`).
5. **Zsh Plugins**: Updates Sheldon plugin locks (`sheldon lock --update`).

All runs are logged to `${XDG_STATE_HOME:-~/.local/state}/nredf/daily-sync.log` (macOS/Linux) and `$LOCALAPPDATA\nredf\daily-sync.log` (Windows).

### 3. How Running Shells Pick Up Updates

If you have open terminals when the background sync completes:

- **New & Upgraded Binaries**: CLI tools in `/opt/homebrew/bin` or `~/.local/share/aquaproj-aqua/bin` are immediately accessible in your existing shell.
- **Dotfiles, Aliases & Functions**: Because running shells maintain their own in-memory environment, run `reload` to hot-reload the current session in place.
- **Manual Full Sync**: To trigger a complete maintenance cycle and reload on demand, run `reload -f`.

---

## ❓ FAQ & Troubleshooting

### Q1: How are runtime versions (Node.js, Python, Ruby, Go) managed?

NREDF uses **`mise`** as the polyglot runtime and tool manager across all platforms and shells. `mise activate` is automatically hooked and cached during shell startup, allowing directory-based tool switching (`.tool-versions`, `mise.toml`).

### Q2: PowerShell shows script execution error on Windows

**Error**: `File ... cannot be loaded because running scripts is disabled on this system`.
**Resolution**: Run this command once in PowerShell:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Q3: How do I test shell startup performance?

Run `reload -p`. The output will display exact timing metrics for each component:

```text
  [  +4ms] oh-my-posh init
  [ +12ms] NREDF_DailySync
  [ +28ms] PowerShell modules & PSFzf
  [  +6ms] Atuin init
  [  +4ms] zoxide init
  [  +3ms] carapace completions
  [ +57ms] Total profile startup time
```

Run `reload -p` a second time to turn off persistent profiling.
