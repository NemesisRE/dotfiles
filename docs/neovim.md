# Neovim Guide (AstroNvim v6)

This document provides a comprehensive guide to the **Neovim** setup in the **NREDF** dotfiles ecosystem. The configuration is built on [AstroNvim](https://astronvim.com) (v6), customized with the unified **OneDark-Pro** theme, XDG-compliant state directories, full LSP & Treesitter integration, and terminal Git tooling.

---

## 🏗️ Architecture & Configuration Layout

Neovim configuration resides in [`home/dot_config/nvim/`](../home/dot_config/nvim/) and follows the modular AstroNvim structure:

```text
~/.config/nvim/
├── init.lua                   # Bootstraps lazy.nvim and loads lazy_setup & polish
├── lua/
│   ├── lazy_setup.lua         # Lazy.nvim configuration & AstroNvim options
│   ├── community.lua          # AstroCommunity module imports (colorschemes, language packs)
│   ├── polish.lua             # Post-init hooks & automatic XDG state directory creation
│   └── plugins/
│       ├── astrocore.lua.tmpl # Core options (numbers, undofile, swap), mappings, autocommands
│       ├── astroui.lua        # UI theme configuration (OneDark-Pro)
│       ├── chezmoi.lua.tmpl   # chezmoi.vim: highlights and edits chezmoi-managed source files
│       ├── heirline.lua       # Heirline statusline & winbar configuration
│       └── mason.lua          # Mason automatic tool & LSP installer configuration
```

Any additional `*.lua` file you add under `lua/plugins/` is picked up automatically (see [Custom User Plugins](#4-custom-user-plugins-luapluginsuserlua)).

### Key Architectural Highlights

1. **Plugin Manager**: Managed with [lazy.nvim](https://github.com/folke/lazy.nvim) for fast, asynchronous, lockfile-backed plugin loading.
2. **Community Ecosystem**: Extensible via [AstroCommunity](https://github.com/AstroNvim/astrocommunity) in `lua/community.lua`.
3. **Unified Colorscheme**: Styled with **OneDark-Pro** (`astrocommunity.colorscheme.onedarkpro-nvim`) to maintain visual consistency across Kitty, Windows Terminal, Bat, and Oh-My-Posh.
4. **XDG State Compliance**: Persistent file undo, swap, and backup directories are strictly confined to `~/.local/state/nvim/` (or `%LOCALAPPDATA%\nvim-data\state` on Windows), preventing clutter in edited working directories.
5. **Global Statusline**: `laststatus = 3` and `showtabline = 2` are enforced with startup autocommands, ensuring consistent editor status visibility at all times.

---

## ⌨️ Keyboard Shortcuts & Cheat Sheet

The leader key is set to <kbd>Space</kbd> and the local leader is set to <kbd>,</kbd>.

### 📁 File & Buffer Management

| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| <kbd>Space</kbd> <kbd>f</kbd> <kbd>f</kbd> | Normal | **Find Files**: Search workspace files via fuzzy finder |
| <kbd>Space</kbd> <kbd>f</kbd> <kbd>w</kbd> | Normal | **Find Words**: Live grep search across workspace files |
| <kbd>Space</kbd> <kbd>f</kbd> <kbd>o</kbd> | Normal | **Recent Files**: Fuzzy search previously opened files |
| <kbd>Space</kbd> <kbd>f</kbd> <kbd>b</kbd> | Normal | **Find Buffers**: Fuzzy search active open buffers |
| <kbd>Space</kbd> <kbd>f</kbd> <kbd>n</kbd> | Normal | **New File**: Prompt for a new file name and open |
| <kbd>Space</kbd> <kbd>e</kbd> | Normal | **Toggle Explorer**: Open or close the sidebar file tree |
| <kbd>Space</kbd> <kbd>o</kbd> | Normal | **Focus Explorer**: Switch focus to the file tree |
| <kbd>Space</kbd> <kbd>w</kbd> | Normal | **Save File**: Write current buffer (`:w`) |
| <kbd>Space</kbd> <kbd>c</kbd> / <kbd>Space</kbd> <kbd>q</kbd> | Normal | **Close Buffer**: Safely close active buffer without closing split window |
| <kbd>[</kbd> <kbd>b</kbd> | Normal | **Previous Buffer**: Switch to previous buffer tab |
| <kbd>]</kbd> <kbd>b</kbd> | Normal | **Next Buffer**: Switch to next buffer tab |
| <kbd>Space</kbd> <kbd>b</kbd> <kbd>c</kbd> | Normal | **Close Other Buffers**: Close all buffers except the current one |

---

### 🧠 LSP & Code Intelligence

| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| <kbd>g</kbd> <kbd>d</kbd> | Normal | **Go to Definition**: Jump to symbol definition |
| <kbd>g</kbd> <kbd>D</kbd> | Normal | **Go to Declaration**: Jump to declaration |
| <kbd>g</kbd> <kbd>r</kbd> | Normal | **Find References**: List all references to symbol under cursor |
| <kbd>g</kbd> <kbd>I</kbd> | Normal | **Go to Implementation**: Jump to implementation of interface/trait |
| <kbd>g</kbd> <kbd>y</kbd> | Normal | **Go to Type Definition**: Jump to type definition |
| <kbd>K</kbd> | Normal | **Hover Documentation**: Display hover popup with function/type signature |
| <kbd>Space</kbd> <kbd>l</kbd> <kbd>a</kbd> | Normal / Visual | **Code Action**: Open LSP quickfix and refactoring code actions |
| <kbd>Space</kbd> <kbd>l</kbd> <kbd>r</kbd> | Normal | **Rename Symbol**: Project-wide rename of the symbol under cursor |
| <kbd>Space</kbd> <kbd>l</kbd> <kbd>f</kbd> | Normal / Visual | **Format Document**: Format active buffer using attached LSP or formatter |
| <kbd>Space</kbd> <kbd>l</kbd> <kbd>d</kbd> | Normal | **Line Diagnostics**: Open float displaying diagnostics for current line |
| <kbd>[</kbd> <kbd>d</kbd> | Normal | **Previous Diagnostic**: Jump to previous warning/error |
| <kbd>]</kbd> <kbd>d</kbd> | Normal | **Next Diagnostic**: Jump to next warning/error |
| <kbd>Space</kbd> <kbd>l</kbd> <kbd>I</kbd> | Normal | **LSP Information**: Display attached language servers and capabilities |

---

### 🔀 Git & Version Control

| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| <kbd>Space</kbd> <kbd>g</kbd> <kbd>g</kbd> | Normal | **Lazygit**: Launch full-screen floating LazyGit terminal UI |
| <kbd>Space</kbd> <kbd>g</kbd> <kbd>l</kbd> | Normal | **Git Log**: View Git commit history in fuzzy finder |
| <kbd>Space</kbd> <kbd>g</kbd> <kbd>b</kbd> | Normal | **Git Branches**: Switch or manage Git branches |
| <kbd>]</kbd> <kbd>g</kbd> | Normal | **Next Git Hunk**: Jump to next modified git hunk |
| <kbd>[</kbd> <kbd>g</kbd> | Normal | **Previous Git Hunk**: Jump to previous modified git hunk |
| <kbd>Space</kbd> <kbd>g</kbd> <kbd>p</kbd> | Normal | **Preview Hunk**: Popup preview of the changes in current hunk |
| <kbd>Space</kbd> <kbd>g</kbd> <kbd>r</kbd> | Normal | **Reset Hunk**: Revert changes in current git hunk |
| <kbd>Space</kbd> <kbd>g</kbd> <kbd>s</kbd> | Normal | **Stage Hunk**: Stage current git hunk |

---

### 🪟 Window & Split Management

| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| <kbd>Ctrl</kbd> + <kbd>h</kbd> | Normal / Terminal | **Move Left**: Switch focus to window on the left |
| <kbd>Ctrl</kbd> + <kbd>j</kbd> | Normal / Terminal | **Move Down**: Switch focus to window below |
| <kbd>Ctrl</kbd> + <kbd>k</kbd> | Normal / Terminal | **Move Up**: Switch focus to window above |
| <kbd>Ctrl</kbd> + <kbd>l</kbd> | Normal / Terminal | **Move Right**: Switch focus to window on the right |
| <kbd>Space</kbd> <kbd>\\</kbd> | Normal | **Split Vertical**: Split window vertically |
| <kbd>Space</kbd> <kbd>\|</kbd> | Normal | **Split Horizontal**: Split window horizontally |
| <kbd>Ctrl</kbd> + <kbd>Up/Down/Left/Right</kbd> | Normal | **Resize Window**: Resize active window dimension |

---

### 💻 Embedded Terminal

| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| <kbd>Space</kbd> <kbd>t</kbd> <kbd>f</kbd> | Normal | **Floating Terminal**: Open or toggle floating terminal overlay |
| <kbd>Space</kbd> <kbd>t</kbd> <kbd>h</kbd> | Normal | **Horizontal Terminal**: Open or toggle bottom split terminal |
| <kbd>Space</kbd> <kbd>t</kbd> <kbd>v</kbd> | Normal | **Vertical Terminal**: Open or toggle right split terminal |
| <kbd>Esc</kbd> <kbd>Esc</kbd> | Terminal | **Exit Terminal Mode**: Return focus to normal navigation |

---

### ⚙️ UI & Quick Toggles (`<Leader>u` prefix)

| Shortcut | Mode | Description |
| :--- | :--- | :--- |
| <kbd>Space</kbd> <kbd>u</kbd> <kbd>n</kbd> | Normal | **Toggle Line Numbers**: Show or hide line numbers |
| <kbd>Space</kbd> <kbd>u</kbd> <kbd>r</kbd> | Normal | **Toggle Relative Numbers**: Toggle relative line numbering |
| <kbd>Space</kbd> <kbd>u</kbd> <kbd>w</kbd> | Normal | **Toggle Word Wrap**: Enable or disable soft line wrapping |
| <kbd>Space</kbd> <kbd>u</kbd> <kbd>s</kbd> | Normal | **Toggle Spell Check**: Enable or disable spellchecker |
| <kbd>Space</kbd> <kbd>u</kbd> <kbd>d</kbd> | Normal | **Toggle Diagnostics**: Enable or disable inline diagnostic virtual text |
| <kbd>Space</kbd> <kbd>u</kbd> <kbd>h</kbd> | Normal | **Toggle Inlay Hints**: Toggle LSP parameter and type inlay hints |

---

## 📦 Managing Plugins & Language Servers

### 1. Lazy.nvim Plugin Management

Open the plugin manager dashboard with:

```vim
:Lazy
```

- <kbd>S</kbd>: Sync all plugins (install missing, update existing, clean removed).
- <kbd>U</kbd>: Update all plugins.
- <kbd>C</kbd>: Clean unused plugins.
- <kbd>x</kbd>: Inspect detailed plugin status.

### 2. Mason Tool Management

[Mason](https://github.com/williamboman/mason.nvim) manages language servers, linters, debuggers, and formatters directly:

```vim
:Mason
```

- <kbd>i</kbd>: Install selected server/tool.
- <kbd>u</kbd>: Update selected server/tool.
- <kbd>X</kbd>: Uninstall selected server/tool.
- <kbd>/</kbd>: Search for language servers, formatters, or linters.

Recommended language tools commonly installed via Mason:

- **Lua**: `lua-language-server`, `stylua`
- **Bash/Zsh**: `bash-language-server`, `shellcheck`, `shfmt`
- **Python**: `pyright` or `basedpyright`, `ruff`
- **YAML / JSON**: `yaml-language-server`, `json-lsp`
- **Go**: `gopls`, `golangci-lint`
- **Rust**: `rust-analyzer`

### 3. AstroCommunity Language & Tooling Packs (`lua/community.lua`)

AstroCommunity packs provide pre-configured treesitter parsers, Mason language servers (LSP), linters, formatters, and debug adapters (DAP). The following packs are enabled in [`home/dot_config/nvim/lua/community.lua`](../home/dot_config/nvim/lua/community.lua):

| Pack | Languages / Tools | Features & Included Plugins |
| :--- | :--- | :--- |
| **`pack.bash`** | Bash, Zsh, POSIX Shell | Treesitter parser, `bash-language-server`, `shellcheck`, `shfmt` |
| **`pack.python`** | Python | Treesitter, LSP (`basedpyright`/`pyright`), `ruff`, DAP (`debugpy`), `venv-selector.nvim` |
| **`pack.docker`** | Dockerfile, Compose | Treesitter, `dockerls`, `docker_compose_language_service`, `hadolint` |
| **`pack.yaml`** | YAML | Treesitter, `yaml-language-server`, SchemaStore catalog validation |
| **`pack.chezmoi`** | Chezmoi Dotfiles | `chezmoi.vim`, `chezmoi.nvim`, `<Leader>f.` fuzzy search, auto-watch buffer edits, template icons |
| **`pack.ansible`** | Ansible Playbooks | Auto-detects `yaml.ansible`, `ansible-language-server`, `ansible-lint`, `ansible-vim` |
| **`pack.json`** | JSON, JSONC | Treesitter, `json-lsp` (`jsonls`), SchemaStore schema validations |
| **`pack.helm`** | Kubernetes Helm | Helm chart detection (`Chart.yaml`), `helm-ls`, gotmpl syntax, comment strings |
| **`pack.markdown`** | Markdown | Treesitter (`markdown`, `markdown_inline`), `marksman` LSP |
| **`pack.ps1`** | PowerShell | Treesitter, `powershell-editor-services` (`powershell_es`), `vim-ps1` |
| **`pack.terraform`** | Terraform, HCL | Treesitter, `terraform-ls`, `tflint`, `tfsec`, `terraform_fmt` via `conform.nvim` |

```lua
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.colorscheme.onedarkpro-nvim" },

  -- Language & Tooling Packs
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.docker" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.chezmoi" },
  { import = "astrocommunity.pack.ansible" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.helm" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.ps1" },
  { import = "astrocommunity.pack.terraform" },
}
```

### 4. Custom User Plugins (`lua/plugins/user.lua`)

To add a completely new plugin not available in AstroCommunity, create `home/dot_config/nvim/lua/plugins/user.lua` (it is not shipped; any `*.lua` file in that directory is loaded by the `{ import = "plugins" }` spec in [`lazy_setup.lua`](../home/dot_config/nvim/lua/lazy_setup.lua)):

```lua
return {
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({})
    end,
  },
}
```

---

## 💡 Tips & Tricks

### Fast File Jump & Navigation

- Press <kbd>Space</kbd> <kbd>f</kbd> <kbd>f</kbd> to find files. Type any substring (e.g. `zshrc` or `profile`) and press <kbd>Enter</kbd> to jump straight there.
- Use <kbd>Space</kbd> <kbd>f</kbd> <kbd>w</kbd> (live grep) to search across the entire repository. Press <kbd>Ctrl</kbd> + <kbd>q</kbd> in the search popup to send all results into a quickfix list.

### Seamless Clipboard Sharing (OSC 52)

NREDF configures terminal clipboard integration with OSC 52 passthrough. Even across remote SSH sessions or inside Zellij multiplexer sessions, copying with `y` or `"+y` syncs directly to your local desktop clipboard.

### Floating Git Workflow

Never leave your editor to manage branches or commits:

1. Press <kbd>Space</kbd> <kbd>g</kbd> <kbd>g</kbd> to open **LazyGit** in a full floating window.
2. Stage files, review diffs, write commit messages, or push to remote.
3. Press <kbd>q</kbd> to exit LazyGit and immediately return to your buffer with updated git gutters!

### Code Formatting on Save

Formatting can be invoked on demand with <kbd>Space</kbd> <kbd>l</kbd> <kbd>f</kbd>. To enable format-on-save globally, toggle it in AstroCore or run `:AstroCore format_on_save`.

---

## ❓ FAQ & Troubleshooting

### Q1: Why are icons showing as boxes or broken question marks?

**Cause**: Neovim uses Nerd Font glyphs for file types, git signs, and diagnostics.
**Resolution**:

- Ensure your terminal uses **FiraCode Nerd Font Mono** (the family this repo standardizes on everywhere).
- On Windows Terminal: Settings (`Ctrl+,`) &rarr; **Defaults** &rarr; **Appearance** &rarr; **Font face** &rarr; `FiraCode Nerd Font Mono`.
- On Kitty: font is configured automatically via `font_family family="FiraCode Nerd Font Mono"`.

### Q2: Treesitter parser compilation errors on fresh install

**Cause**: Treesitter requires a C compiler (`gcc`, `clang`, or `zig`) to compile language parsers.
**Resolution**:
In NREDF, required C/C++ compilers are now managed automatically during `chezmoi apply` via [`home/.chezmoidata/packages.yaml`](../home/.chezmoidata/packages.yaml):

- **Linux**: `build-essential` (`apt`), `base-devel` (`pacman`), or `gcc`/`gcc-c++`/`make` (`dnf`).
- **macOS**: Automatically checks and installs **Xcode Command Line Tools** (`xcode-select --install`).
- **Windows**: `LLVM.LLVM` installed automatically via `winget`.
Once installed, run `:TSUpdate` in Neovim to compile any pending language parsers.

### Q3: Where are undo history and swap files stored?

NREDF centralizes all editor runtime files to avoid polluting projects:

- **Undo History**: `~/.local/state/nvim/undo/`
- **Swap Files**: `~/.local/state/nvim/swap/`
- **Backup Files**: `~/.local/state/nvim/backup/`
Directories are created automatically during initialization in `lua/polish.lua`.

### Q4: How do I update AstroNvim and all plugins?

Run the following inside Neovim:

```vim
:Lazy update
:MasonUpdate
```

Or to update dotfiles and tools from your terminal:

```bash
chezmoi update
aqua install
```

### Q5: Windows: Chezmoi pack "attempt to concatenate a nil value"

**Cause**: The upstream `astrocommunity.pack.chezmoi` hardcodes `os.getenv "HOME" .. "/.local/share/chezmoi"`. Windows does not set `$env:HOME` by default (it uses `USERPROFILE`), causing a fatal concatenation error when evaluating lazy specs.
**Resolution**: NREDF automatically normalizes `vim.env.HOME = vim.env.USERPROFILE` at the start of `init.lua` and `community.lua`, persists `HOME` in Windows User environment variables, and points the chezmoi plugins at the source directory chezmoi itself renders (`.chezmoi.sourceDir`) in [`lua/plugins/chezmoi.lua.tmpl`](../home/dot_config/nvim/lua/plugins/chezmoi.lua.tmpl).

### Q6: Windows: "Installation failed for ansible-lint: Platform not supported"

**Cause**: The upstream Ansible project and `ansible-lint` require POSIX primitives and do not support native Windows. In Mason's package registry, `ansible-lint` is strictly flagged as `supported_platforms: [unix]`.
**Resolution**: In [`lua/plugins/mason.lua`](../home/dot_config/nvim/lua/plugins/mason.lua), NREDF automatically filters out `ansible-lint` on Windows host environments while retaining the `ansible-language-server` (LSP), YAML schemas, and `ansible-vim` syntax highlighting. On Linux, macOS, and WSL, `ansible-lint` is installed and used normally.
