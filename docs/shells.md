# Unified Shells Guide: Zsh, Bash, Fish, Nushell & PowerShell (pwsh)

This guide documents the shell architecture across **Linux**, **macOS**, and **Windows** in the **NREDF** dotfiles ecosystem, detailing feature parity, keybindings, aliases, functions, and configuration mechanics for **Zsh**, **Bash**, **Fish**, **Nushell (`nu`)**, and **PowerShell (pwsh)**.

None of the five is the default login shell — install and try any of them without disturbing your existing setup: `fish` or `nu` at a prompt starts an interactive session, and `reload -s fish` (or `-s nu`) hot-swaps the current one. Fish has no Windows build at all (Linux/macOS only); the other four run everywhere.

---

## 🧭 Shell Feature Parity Matrix

All five shells share a unified experience designed around modern developer ergonomics, with a small number of documented exceptions — see "Known Parity Exceptions" below.

| Capability | Zsh | Bash | Fish | Nushell | PowerShell (`pwsh`) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Prompt Engine** | [Oh-My-Posh](https://ohmyposh.dev) (`OneDark-Pro`) | [Oh-My-Posh](https://ohmyposh.dev) (`OneDark-Pro`) | [Oh-My-Posh](https://ohmyposh.dev) (`OneDark-Pro`) | [Oh-My-Posh](https://ohmyposh.dev) (`OneDark-Pro`) | [Oh-My-Posh](https://ohmyposh.dev) (`OneDark-Pro`) |
| **History Sync & Search** | [Atuin](https://atuin.sh) (<kbd>Ctrl</kbd>+<kbd>r</kbd>) | [Atuin](https://atuin.sh) (<kbd>Ctrl</kbd>+<kbd>r</kbd>) | [Atuin](https://atuin.sh) (<kbd>Ctrl</kbd>+<kbd>r</kbd>) | [Atuin](https://atuin.sh) (<kbd>Ctrl</kbd>+<kbd>r</kbd>) | [Atuin](https://atuin.sh) (<kbd>Ctrl</kbd>+<kbd>r</kbd>, <kbd>UpArrow</kbd>) |
| **Fuzzy Finding** | `fzf` (<kbd>Ctrl</kbd>+<kbd>t</kbd>, <kbd>Alt</kbd>+<kbd>c</kbd>) | `fzf` (<kbd>Ctrl</kbd>+<kbd>t</kbd>, <kbd>Alt</kbd>+<kbd>c</kbd>) | `fzf` (<kbd>Ctrl</kbd>+<kbd>t</kbd>, <kbd>Alt</kbd>+<kbd>c</kbd>) | `fzf` (<kbd>Ctrl</kbd>+<kbd>t</kbd>, <kbd>Alt</kbd>+<kbd>c</kbd>, <kbd>Ctrl</kbd>+<kbd>r</kbd>) | `fzf` (<kbd>Ctrl</kbd>+<kbd>t</kbd>, <kbd>Alt</kbd>+<kbd>c</kbd>) |
| **Directory Navigation** | `zoxide` hooked to `cd`, `z`, `zi` | `zoxide` hooked to `cd`, `z`, `zi` | `zoxide` hooked to `cd`, `z`, `zi` | `zoxide` `z`, `zi` only — **not** hooked to `cd` (zoxide has no nushell `cd` integration upstream) | `zoxide` hooked to `cd`, `z`, `zi` |
| **Syntax Highlighting** | `fast-syntax-highlighting` | `ble.sh` (Bash Line Editor) | Built in | Built in | `PSReadLine` |
| **Inline Autosuggestions** | `zsh-autosuggestions` | `ble.sh` inline suggestions | Built in | Built in | `PSReadLine` (`HistoryAndPlugin`) |
| **Tab Completion Engine** | [Carapace](https://carapace.sh) (`carapace-bin` + `fzf-tab`) | [Carapace](https://carapace.sh) (`bash-ble` with descriptions) | [Carapace](https://carapace.sh) + `fzf`-powered <kbd>Ctrl</kbd>+<kbd>Space</kbd> widget | [Carapace](https://carapace.sh) native completion menu only — **no** `fzf`-powered widget (see exceptions) | [Carapace](https://carapace.sh) (native menu + `fzf` modal) |
| **Auto-Pairing Quotes** | `zsh-autopair` | `ble.sh` auto-complete | N/A (fish doesn't need it) | N/A (nu doesn't need it) | Custom `PSReadLine` chord (`"`, `'`) |
| **Plugin Manager** | [Sheldon](https://sheldon.cli.rs) | Git-cloned `ble.sh` | None required | None required | None required (100% native CLI tooling) |
| **Environment Sync** | `reload` (supports `-c`, `-d`, `-f`, `-p`, `-s`) | `reload` (supports `-c`, `-d`, `-f`, `-p`, `-s`) | `reload` (supports `-c`, `-d`, `-f`, `-p`, `-s`) | `reload` (supports `-c`, `-d`, `-f`, `-p`, `-s`) | `reload` (supports `-c`, `-d`, `-f`, `-p`, `-s`) |
| **Startup Profiling** | `reload -p` / `NREDF_PROFILE_STARTUP=1` | `reload -p` / `NREDF_PROFILE_STARTUP=1` | `reload -p` / `NREDF_PROFILE_STARTUP=1` | `reload -p` / `NREDF_PROFILE_STARTUP=1` | `reload -p` / `NREDF_PROFILE_STARTUP=1` |
| **Local overrides** | `~/.config/zsh/{aliases,rc,functions/}` | `~/.config/bash/{aliases,rc,functions/}` | `~/.config/fish/{aliases,rc}` + fish's own native `functions/` autoload | `~/.config/nushell/`: **two files only**, `env.local.nu`, `config.local.nu` (see exceptions) | `~/.config/pwsh/{aliases.ps1,modules.ps1,functions/}` |

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

### 3. Fish Architecture

- **Dotfiles**: [`home/dot_config/fish/config.fish.tmpl`](../home/dot_config/fish/config.fish.tmpl)
- **Framework**: [`home/dot_local/share/nredf/shell/fish/`](../home/dot_local/share/nredf/shell/fish/) — `rc.tmpl` is a single, self-contained entry point (fish has no sibling shell to share a "common" rc with the way bash/zsh do), ported 1:1 from the bash function files since fish is dynamically scoped the same way bash is.
- **Completion Engine**: Managed by **Carapace** (`carapace-bin`) cached for 24 hours via `_nredf_refresh_cached_shell_snippet`, with the same declarative specs in `~/.config/carapace/specs/`.
- **Local overrides**: `~/.config/fish/aliases`, `~/.config/fish/rc`, plus fish's own native `~/.config/fish/functions/*.fish` autoload (nothing this framework implements).

### 4. Nushell Architecture

- **Dotfiles**: thin stubs that just `source` one canonical tree, deployed to every path nu might actually read — `~/.config/nushell/{env,config}.nu` (deployed on **every OS**, not just Linux) plus the OS-native fallback: `~/Library/Application Support/nushell/{env,config}.nu` (macOS) or `~/AppData/Roaming/nushell/{env,config}.nu` (Windows; Linux has no separate native path, XDG *is* its native path). Nu resolves its config directory from the real process environment *before* it reads any of its own files, and — confirmed live — **prioritizes `$XDG_CONFIG_HOME/nushell` over its OS-native default the instant `XDG_CONFIG_HOME` is set**, on every OS, not only Linux. Since every other shell in this repo already exports `XDG_CONFIG_HOME`, launching nu from (or with an environment inherited from) any of them makes nu read `~/.config/nushell` even on macOS/Windows; launching nu with no such prior shell in the chain falls back to the OS-native path instead. Both locations get the same stub content so either path works.
- **Framework**: [`home/dot_local/share/nredf/shell/nushell/`](../home/dot_local/share/nredf/shell/nushell/) — `env.nu.tmpl` (env vars only, safe for non-interactive `nu -l`) and `config.nu.tmpl` (interactive-only setup), mirroring nu's own env.nu/config.nu convention instead of bash's single common rc.
- **Completion Engine**: Managed by **Carapace** (`carapace-bin`), which also stands in for the fzf-powered Ctrl+Space widget nu can't have (see "Known Parity Exceptions" below).
- **Local overrides**: exactly two files, `env.local.nu` and `config.local.nu`, seeded empty by chezmoi and never overwritten again — see "Known Parity Exceptions" below for why nu can't get bash's fuller cascade.
- **Environment model**: nu's `def` is not dynamically scoped — a function only mutates the caller's `$env` if declared `def --env`, and every function in a chain that needs to reach top-level `$env` must be `--env`, all the way up. Every state-mutating command in the nu port follows a "compute in a plain `def`, assign in a thin `--env` wrapper" shape for this reason.

### 5. PowerShell (pwsh) Architecture

- **Dotfiles**:
  - Entry points: [`home/Documents/PowerShell/`](../home/Documents/PowerShell/)
    - Target for PowerShell 7+: `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
    - Target for Windows PowerShell 5.1: `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (dot-sources PowerShell 7 profile)
    - Linux/macOS: `~/.config/powershell` is symlinked directly to `~/Documents/PowerShell`
  - Framework: [`home/dot_local/share/nredf/shell/pwsh/`](../home/dot_local/share/nredf/shell/pwsh/)
    - Deployed to `~/.local/share/nredf/shell/pwsh/` on all platforms, matching the location of all other shells.
- **Module Architecture**:
  - `Defaults.ps1`: XDG paths, Aqua paths, Python paths, UTF-8 output encoding, default formatting.
  - `Modules.ps1`: Zero external PowerShell modules required; hooks local overrides if configured.
  - `Aliases.ps1`: Cross-platform command parity with Bash/Zsh.
  - `PSReadLine.ps1`: Keybindings, prediction source (`HistoryAndPlugin`), native `fzf` integration, smart auto-pairing quotes.
  - `Functions.ps1`: Utility functions (`reload`, `sudo`, `md5`, `sha256`, `NREDF_DailySync`).
  - `Profile.ps1`: High-performance startup orchestration with snippet caching (`NREDF_RefreshCachedShellSnippet`) for Oh-My-Posh, Atuin, Zoxide, and **Carapace** completions (including custom specs in `~/.config/carapace/specs/`).

### 6. Custom Completions (Carapace)

- **Specs**: [`home/dot_config/carapace/specs/`](../home/dot_config/carapace/specs/) holds one YAML spec per command carapace-bin doesn't know: the NREDF functions (`reload`, `yy`, `nredf_ssh`, `nredf_aqua_token_setup`, `nredf-daily-sync`) and aqua tools without a completer (`kubectx`, `kubens`, `lsd`, `lazydocker`, `lazyjournal`).
- **Aliases**: bash can't complete an alias through its target, so every alias in `home/.chezmoidata/aliases.yaml` whose target needs it (`k`, `kctx`/`ctx`, `kns`/`ns`, `lzg`/`lg`, `lzd`, `lzj`/`lj`, `ll`/`la`/`tree`, `pst`) has its own thin spec that bridges to the target with `$carapace.bridge.CarapaceBin([target])`. A spec's `aliases:` field does not help here: it only names subcommand aliases and never registers a top-level command.
- **Cobra bridges**: [`home/dot_config/carapace/choices/`](../home/dot_config/carapace/choices/) makes carapace ask `flux`, `oras`, `stern`, `velero` and `yq` for their own completions (the same files `carapace --choice flux/cobra@bridge` writes).
- **Cache lag**: bash, zsh, fish and PowerShell only complete command names that were listed in carapace's init snippet, which is cached for 24 hours. A **new** spec or choice therefore appears only after `reload -c` (or the next daily refresh); edits to an existing spec apply immediately. Nushell's snippet is a generic external completer, so it picks up new specs at once.

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

### 3. Fish Keyboard Shortcuts

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| <kbd>Tab</kbd> | Fish Pager | Native completion menu with Carapace descriptions |
| <kbd>Ctrl</kbd> + <kbd>Space</kbd> | fzf Tab Completion | Open interactive fzf completion modal with descriptions (`commandline`-based, ported from bash's `READLINE_LINE` widget) |
| <kbd>Ctrl</kbd> + <kbd>r</kbd> | Atuin Search | Interactive fuzzy search across full command history |
| <kbd>Ctrl</kbd> + <kbd>t</kbd> | Fzf File Search | Fuzzy search files in CWD and insert selected path at cursor |
| <kbd>Alt</kbd> + <kbd>c</kbd> / <kbd>Option</kbd>+<kbd>c</kbd> | Fzf CD | Fuzzy search subdirectories and immediately `cd` into selection |
| <kbd>Ctrl</kbd> + <kbd>l</kbd> | Clear Screen | Clear terminal screen |

> [!NOTE]
> On macOS, Option+c produces `ç` or `©` by default, same as zsh/bash — NREDF binds both to the fzf widget in fish too.

---

### 4. Nushell Keyboard Shortcuts

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| <kbd>Tab</kbd> | Reedline Menu | Native completion menu fed by Carapace — nu's only completion-picking UI (see "Known Parity Exceptions" below) |
| <kbd>Ctrl</kbd> + <kbd>r</kbd> | Fzf History Search | `fzf --nushell`'s Ctrl+R history widget |
| <kbd>Ctrl</kbd> + <kbd>t</kbd> | Fzf File Search | `fzf --nushell`'s Ctrl+T file-insert widget |
| <kbd>Alt</kbd> + <kbd>c</kbd> | Fzf CD | `fzf --nushell`'s Alt+C directory-jump widget |
| <kbd>Ctrl</kbd> + <kbd>l</kbd> | Clear Screen | Clear terminal screen |

> [!NOTE]
> There is no Ctrl+Space fuzzy tab-completion widget in nu — Reedline (nu's line editor) has no primitive to replace the edit buffer with an external filter's output, which is what that widget depends on in every other shell here. See "Known Parity Exceptions" below.

---

### 5. PowerShell Keyboard Shortcuts (PSReadLine & fzf)

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

NREDF guarantees that common development commands behave identically regardless of your current shell or operating system, across all five shells:

| Command | Target Tool | Description |
| :--- | :--- | :--- |
| `ls` | `lsd` | Modern file listing with icons and colors |
| `ll` | `lsd -lFh --git` | Long format listing with Git status flags and human-readable sizes |
| `la` | `lsd -lAFh --git` | Detailed listing including hidden files and Git status |
| `tree` | `lsd --tree` | Recursive tree view with icons |
| `cat` | `bat` | Syntax-highlighted output with OneDark-Pro theme |
| `lzg` / `lg` | `lazygit` | Terminal UI for Git |
| `lzd` | `lazydocker` | Terminal UI for Docker and Docker Compose |
| `lzj` / `lj` | `lazyjournal` | Terminal UI for multi-source log viewing & filtering |
| `k` | `kubectl` | Kubernetes CLI shorthand |
| `kctx` / `ctx` | `kubectx` | Fast Kubernetes context switcher |
| `kns` / `ns` | `kubens` | Fast Kubernetes namespace switcher |
| `yy` | Custom Function | Open **Yazi** file manager; changes terminal working directory on exit |
| `cd <path>` | `zoxide` | Smart jump (falls back to standard `cd` if path exists) — **not in Nushell**, see below |
| `z <query>` | `zoxide query` | Jump directly to highest ranked directory matching query |
| `zi` | `zoxide query -i` | Interactive fuzzy search directory selection |

> [!NOTE]
> Nushell's `cd` is never replaced by zoxide (zoxide has no `nushell`-target `cd` integration upstream) — `z`/`zi` still work identically to every other shell here.

---

## 🏠 Local, Machine-Specific Overrides

None of the following files are chezmoi-managed or committed to this repo — they live only on your machine, are yours to create, and `chezmoi apply` never touches or overwrites them. [`~/.config/nredf/README.md`](../home/dot_config/nredf/README.md) is a shorter, on-disk version of this same section.

### `~/.config/nredf/local.yaml` — paths and simple aliases

The same declarative format `.chezmoidata/paths.yaml` and `.chezmoidata/aliases.yaml` use internally. If this file exists, every shell reads and merges it in at `chezmoi apply` time (it is re-read on every apply, so editing it and re-applying picks up changes immediately). chezmoi deploys a copy-and-edit starting point at [`~/.config/nredf/local.yaml.example`](../home/dot_config/nredf/local.yaml.example) — copy it to `local.yaml` in the same directory:

```yaml
# ~/.config/nredf/local.yaml
nredf_paths_local:
  - var: MY_TOOL_HOME # exported as $MY_TOOL_HOME if not already set
    base: HOME # $HOME, or any other var already set by then (e.g. XDG_CONFIG_HOME)
    parts: [".local", "my-tool"] # joined onto base with "/"

nredf_aliases_local:
  - names: ["myalias", "ma"] # one or more names for the same command
    command: "echo hello world" # a single target command; no pipes/flow control
```

Both lists are optional and additive — they never replace the built-in entries. Two things this format deliberately can't express, by design:

- **A `requires`/existence gate** on a local alias. Bash/zsh/fish/PowerShell would happily support one, but Nushell's `alias`/`def` can't be conditionally defined inside an `if` block (see below), so gating isn't offered here at all, to keep one file behaving the same on every shell. Everything in `nredf_aliases_local` is defined unconditionally.
- **A pipeline, condition, or anything needing real control flow.** `command` is a single command line, substituted as-is (bash/fish: `alias`; nu: `alias`; PowerShell: `Set-Alias` or a one-line wrapper function).

For either of those, use the per-shell cascade below instead. A malformed `local.yaml` fails `chezmoi apply` loudly with a YAML parse error pointing at the bad line, rather than silently dropping your entries.

### Per-shell aliases, rc and local-functions directory

For anything `local.yaml` can't express — conditional aliases, real functions, arbitrary startup code — every shell loads its own files from **its own `~/.config/<shell>/` directory**, not from `~/.config/nredf/` at all. This is consistent across every shell including PowerShell (via `XDG_CONFIG_HOME`, set on Windows too — deliberately not `$PROFILE`'s directory, which is `Documents\PowerShell\` on Windows but `~/.config/powershell/` on Linux/macOS). There is deliberately no shared "all shells" or "bash+zsh" tier: a function's syntax is never portable across shells anyway, and `local.yaml` above already covers the one thing that genuinely was shareable (simple aliases/paths).

| Shell | Aliases | Startup code | Functions directory |
| :--- | :--- | :--- | :--- |
| Bash | `~/.config/bash/aliases` | `~/.config/bash/rc` | `~/.config/bash/functions/*.bash` |
| Zsh | `~/.config/zsh/aliases` | `~/.config/zsh/rc` | `~/.config/zsh/functions/*` |
| Fish | `~/.config/fish/aliases` | `~/.config/fish/rc` | `~/.config/fish/functions/*.fish` — fish's own native autoload, nothing this framework implements |
| Nushell | not supported | `~/.config/nushell/env.local.nu`, `~/.config/nushell/config.local.nu` | not supported |
| PowerShell | `~/.config/pwsh/aliases.ps1` | `~/.config/pwsh/modules.ps1` (module imports) | `~/.config/pwsh/functions/*.ps1` |

`~/.config/<shell>/` is deliberately where each shell's local files live: it's already where you'd look for shell-specific config, and fish in particular already autoloads its `functions/` directory as a native feature — putting a second, framework-specific mechanism anywhere else would only duplicate or collide with what the shell already does itself.

Every file in the table above except the functions directories is pre-seeded by chezmoi (`create_`: written once, empty except for a header comment and a commented-out example, never overwritten again) — there's nothing to create, just open and edit. Each `functions/` directory instead has its own `README.md` with a matching example, since anything real dropped there gets sourced (or, for fish, autoloaded) on every shell startup.

### `~/.config/aquaproj-aqua/machine.yaml` — local aqua packages

aqua already supports a second, machine-local config file layered on top of the repo's `aqua.yaml`: if `~/.config/aquaproj-aqua/machine.yaml` exists, every shell's startup appends it to `AQUA_GLOBAL_CONFIG` automatically (see `nredf_aqua.bash`/`.fish`/`.nu`/`Defaults.ps1`). Same `packages:` format as `home/dot_config/aquaproj-aqua/aqua.yaml` — add your own tools there without touching this repo.

### `~/.config/mise/config.local.toml` — local mise tools

mise natively loads `config.local.toml` alongside `config.toml` in the same directory (confirmed: `mise config ls` lists both). Add your own `[tools]` there; it's merged with `home/dot_config/mise/config.toml.tmpl`'s pinned versions with no chezmoi involvement at all.

---

## 🔄 The Unified `reload` Command

Each of the five shells provides a high-performance `reload` function with identical arguments (in Nushell, its typed named flags are generated from the same option set, so `reload --help` documents itself):

```text
Usage: reload [options]

Options:
  -c, --cache       Delete 'Last Run Cache' and init script snippets
  -d, --downloads   Delete aqua pkgs (archives + binaries, keeps bin/ symlinks)
  -f, --full        Full refresh: clear caches + chezmoi / aqua / sheldon
  -l, --last-run    Delete only 'Last Run Cache'
  -p, --profile     Toggle startup profiling (or one-shot if combined with other options)
  -s, --shell NAME  Reload directly into a different shell (e.g. zsh, bash, fish, nu, pwsh)
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
- **Switch to Fish or Nushell from Bash/Zsh**:

  ```bash
  reload -s fish
  reload -s nu
  ```

- **Force clean rebuild of all CLI packages & cached scripts**:

  ```bash
  reload -f
  ```

---

## 📂 Yazi CWD Wrapper (`yy`)

Running standard `yazi` leaves the shell in whatever directory you started in. NREDF includes the `yy` function in all five shells:

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
3. **Dotfiles Remote Sync**: Fetches upstream dotfiles changes, fast-forwards Git, and runs `chezmoi apply --refresh-externals` (skipping secret templates when the password safe is locked).
4. **Aqua Tools**: Updates Aqua (`aqua update-aqua`), ensures tool links (`aqua install -a -l`), and vacuums packages unused for >30 days (`aqua vacuum -d 30`).
5. **Zsh Plugins**: Updates Sheldon plugin locks (`sheldon lock --update`).

All runs are logged to `${XDG_STATE_HOME:-~/.local/state}/nredf/daily-sync.log` (macOS/Linux) and `$LOCALAPPDATA\nredf\daily-sync.log` (Windows). `reload -f` (or `nredf-daily-sync --verbose`) also prints that output to the terminal.

### 3. How Running Shells Pick Up Updates

If you have open terminals when the background sync completes:

- **New & Upgraded Binaries**: CLI tools in `/opt/homebrew/bin` or `~/.local/share/aquaproj-aqua/bin` are immediately accessible in your existing shell.
- **Dotfiles, Aliases & Functions**: Because running shells maintain their own in-memory environment, run `reload` to hot-reload the current session in place.
- **Manual Full Sync**: To trigger a complete maintenance cycle and reload on demand, run `reload -f`.

---

## ⚠️ Known Parity Exceptions

"Five-shell parity" (AGENTS.md) means every command, alias and completion is either implemented identically everywhere, or its gap here is deliberate, understood, and won't silently regress. These are the current gaps:

| Item | Affected shell(s) | Why | Resolution |
| :--- | :--- | :--- | :--- |
| Ctrl+Space fzf-tab completion widget | Nushell | Reedline (nu's line editor) has no primitive to replace the edit buffer with an external filter's output — every other shell's widget depends on exactly that. | Not implemented. Carapace's native Reedline completion menu (Tab) is nu's substitute. |
| `zoxide --cmd cd` (replacing `cd` itself) | Nushell | zoxide itself has no nushell `cd` integration — an upstream gap, not this repo's. | `z`/`zi` aliases only; `cd` is never overridden in nu. |
| Same-session cached tool-init refresh (atuin/zoxide/mise/carapace/fzf) | Nushell | nu's `source` requires the target file to exist on disk *before the file that sources it is even parsed* — true even inside a runtime `if path exists` guard. A cache regenerated this session can only be `source`d starting the *next* shell start. | Chezmoi seeds an empty placeholder (`create_`/`empty_`) for each cache file so a cold `source` never fails outright; a stale-but-present cache is used for the rest of the current session and refreshes for the next one. |
| oh-my-posh's nu integration doesn't use the cached-snippet mechanism at all | Nushell | Unlike every other tool here, `oh-my-posh init nu` prints nothing (confirmed: empty stdout *and* stderr on success) — it writes directly into nu's own vendor-autoload directory (`~/.local/share/nushell/vendor/autoload/`, one of `$nu.vendor-autoload-dirs`), which nu sources automatically on its own next startup. | config.nu just re-runs the generator on the same 24h throttle, with no cache file or `source` line of its own — the same one-restart lag applies, but because nu only rescans vendor-autoload at its own next startup, not because of the `source` restriction above. |
| Fuller local-override files (`aliases`, `rc`, a local-functions directory) | Nushell | Same `source`-needs-the-file-to-already-exist restriction rules out conditionally sourcing a maybe-missing file at all. | Exactly two chezmoi-seeded files, `env.local.nu` and `config.local.nu` (seeded empty, never overwritten again) — one for env vars, one for interactive config, matching nu's own env.nu/config.nu split. |
| Directory-glob fallback when the function bundle is absent | Nushell | The fallback loop would itself need to `source` a runtime-determined file list — same restriction again. | The generated bundle is nu's only load path, not a fast path with a fallback the way bash/zsh/fish have. |
| Caller-name auto-detection for the throttle gate and mkdir-based lock (`_nredf_last_run`, `_nredf_create_lock`) | Fish, Nushell | Neither has an equivalent of bash's `FUNCNAME`/zsh's `funcstack`. | Both take an explicit `key` argument at every call site instead of inferring one. |
| Kitty terminal shell-integration | Nushell | Kitty ships integration scripts for bash/zsh/fish only — no nushell target exists upstream. | Not implemented; not something this repo can fix. |
| pyenv shell integration | Nushell | pyenv has no nushell integration upstream (bash/zsh/fish only). | Not implemented; `pyenv exec`/`pyenv which` still work as plain external commands. |
| `dircolors`/`LS_COLORS` integration | Nushell | nu's own `ls` builtin has its own color theming (`$env.config.color_config`) and never reads `LS_COLORS`, unlike the external-`ls`-based `ls`/`ll`/`la` aliases every other shell here uses. | Not implemented; low value for nu specifically, not a gap in the external-`ls` sense the other shells have. |
| Prompt-with-timeout for the aqua GitHub-token setup wizard | Fish, Nushell | Neither fish's `read` nor nu's `input` has a timeout flag at all (unlike bash's `read -t`). | Shells out to `timeout`/`gtimeout` if one is installed; otherwise falls back to an untimed prompt, still gated on being a real interactive tty so it can never block a non-interactive shell. |
| `zcompile`-equivalent bundle byte-caching | Fish, Nushell | Neither has a bytecode-cache mechanism comparable to zsh's `zcompile`. | Accepted as a minor, unavoidable cold-start cost; the cached-snippet mechanism still covers the genuinely expensive parts (tool inits). |
| PowerShell automatically restoring `$env:SSH_AUTH_SOCK` | PowerShell | Pre-existing gap, unrelated to the fish/nu work above — flagged here so it isn't mistaken for a new one. | Out of scope for this document; PowerShell users configure SSH agent forwarding another way for now. |

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
