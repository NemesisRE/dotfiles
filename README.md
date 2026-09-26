<h1 align="center">
  NREDF &mdash; NemesisRE DotFiles
</h1>

<div align="center">
  <a href="../../commits/main">
    <img alt="Last commit" src="https://img.shields.io/github/last-commit/NemesisRE/dotfiles?style=for-the-badge&color=f2cdcd&labelColor=363a4f"/>
  </a>
  <img alt="Repo size" src="https://img.shields.io/github/repo-size/NemesisRE/dotfiles?style=for-the-badge&color=eba0ac&labelColor=363a4f"/>
  <a href="https://github.com/NemesisRE/dotfiles/actions/workflows/ci.yml">
    <img alt="CI" src="https://img.shields.io/github/actions/workflow/status/NemesisRE/dotfiles/ci.yml?branch=main&label=CI&style=for-the-badge&color=a6e3a1&labelColor=363a4f"/>
  </a>
  <a href="LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/NemesisRE/dotfiles?style=for-the-badge&color=b4befe&labelColor=363a4f"/>
  </a>
</div>

<div align="center">
  <a href="https://chezmoi.io/">
    <img alt="chezmoi" src="https://img.shields.io/badge/chezmoi-fab387?style=for-the-badge&logo=chezmoi&logoColor=white"/>
  </a>
  <a href="https://aquaproj.github.io/">
    <img alt="aqua" src="https://img.shields.io/badge/aqua-89dceb?style=for-the-badge&logo=aqua&logoColor=white"/>
  </a>
  <a href="https://sheldon.cli.rs/">
    <img alt="sheldon" src="https://img.shields.io/badge/sheldon-cba6f7?style=for-the-badge&logo=rust&logoColor=white"/>
  </a>
  <a href="https://ohmyposh.dev/">
    <img alt="oh-my-posh" src="https://img.shields.io/badge/oh--my--posh-f9e2af?style=for-the-badge&logo=powershell&logoColor=white"/>
  </a>
  <a href="https://git-scm.com/">
    <img alt="git" src="https://img.shields.io/badge/git-F05032?style=for-the-badge&logo=git&logoColor=white"/>
  </a>
</div>

<div align="center">
  <img alt="Linux" src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black"/>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white"/>
  <img alt="Windows" src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white"/>
  <img alt="Zsh" src="https://img.shields.io/badge/Zsh-89b4fa?style=for-the-badge&logo=gnu-bash&logoColor=white"/>
  <img alt="Bash" src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white"/>
  <img alt="Fish" src="https://img.shields.io/badge/Fish-94e2d5?style=for-the-badge&logo=fishshell&logoColor=white"/>
  <img alt="Nushell" src="https://img.shields.io/badge/Nushell-f5c2e7?style=for-the-badge&logo=nushell&logoColor=white"/>
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white"/>
</div>

---

Personal cross-platform dotfiles managed with [chezmoi](https://chezmoi.io).

On a fresh machine, NREDF automatically provisions a complete modern terminal environment with unified shell configurations across **Linux**, **macOS**, and **Windows**.

The core stack powering this setup includes:

- **Dotfiles & Packages**: [chezmoi](https://chezmoi.io) (declarative state management), [aqua](https://aquaproj.github.io/) (declarative CLI tool manager), and [sheldon](https://sheldon.cli.rs/) (fast shell plugin manager)
- **Shell & Navigation**: [Oh My Posh](https://ohmyposh.dev/) (cross-shell prompt theme), [Carapace](https://carapace.sh/) (multi-shell completion), [Atuin](https://atuin.sh/) (encrypted history sync & search), [zoxide](https://github.com/ajeetdsouza/zoxide) (smart `cd`), and [fzf](https://github.com/junegunn/fzf) (fuzzy finding)
- **Modern CLI Replacements**: [lsd](https://github.com/lsd-rs/lsd) (enhanced `ls`), [bat](https://github.com/sharkdp/bat) (`cat` clone with syntax highlighting), [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg` fast search), [fd](https://github.com/sharkdp/fd) (fast `find` alternative), and [tealdeer](https://github.com/tealdeer-rs/tealdeer) (`tldr` cheatsheets)
- **Terminal Workspace & Editor**: [Zellij](https://zellij.dev/) (terminal multiplexer & workspace manager), [Yazi](https://yazi-rs.github.io/) (async terminal file manager), and [AstroNvim](https://astronvim.com/) (aesthetic, extensible Neovim IDE)

---

## Fresh Install (One-Liners)

### Linux & macOS

Using chezmoi's installer directly:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply NemesisRE/dotfiles
```

Or run the bootstrap script:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NemesisRE/dotfiles/main/bootstrap.sh)
```

> **Prerequisites:** `curl`, `git` (auto-installed on Debian/Ubuntu). On macOS, Homebrew is used when available.

---

### Windows

Open **PowerShell** and run the bootstrap script:

```powershell
irm https://raw.githubusercontent.com/NemesisRE/dotfiles/main/bootstrap.ps1 | iex
```

Or using chezmoi directly via winget:

```powershell
winget install twpayne.chezmoi
chezmoi init --apply NemesisRE/dotfiles
aqua install -a -l
```

> [!TIP]
> For in-depth platform configurations, check the dedicated [Linux Guide](docs/linux.md), [macOS Guide](docs/macos.md), and [Windows Guide](docs/windows.md). Explore all tools, shells, and Neovim in the [Documentation Hub](#documentation-hub).

---

## What Happens During Installation

1. **chezmoi** is installed (`~/.local/bin/chezmoi` on Unix, `%USERPROFILE%\.local\bin\chezmoi.exe` or winget on Windows)
2. The dotfiles repository is cloned to `~/.local/share/chezmoi`
3. **aqua** is installed and declarative CLI tools are linked
4. All dotfiles and profiles are applied to `~/`
5. Shell libraries for all shells (Bash, Zsh, Fish, Nu, and PowerShell) are deployed to `~/.local/share/nredf/shell/`; PowerShell entry-point profiles are maintained in `Documents/PowerShell` (with `~/.config/powershell` symlinked on Linux/macOS)

---

## After Install

The initial `chezmoi init` prompts for machine-local values (such as Git name/email, secrets profile preset, SSH agent provider, and remote multiplexer). Answers are stored in `~/.config/chezmoi/chezmoi.toml` and override defaults without dirtying tracked repository files. To re-prompt or reconfigure anytime, run `chezmoi init --prompt && chezmoi apply`.

If you use **Bitwarden**, **KeePassXC**, or **1Password**, your `AQUA_GITHUB_TOKEN` and Git SSH commit signing key are automatically resolved from your secret store without manual token entry. For full details on setting up personal or work secret profiles, see the [Secrets Guide](docs/secrets.md).

Alternatively, if no secret store is configured and neither `GITHUB_TOKEN` nor `AQUA_GITHUB_TOKEN` is set, the first interactive session also offers to run `aqua token set` and store a token in your system keyring to prevent GitHub API rate limits.

```bash
# Reconfigure machine settings (name, email, secret store, signing key, SSH agent)
chezmoi init --prompt && chezmoi apply

# Configure aqua's GitHub token manually later (keyring fallback)
nredf_aqua_token_setup

# Restart your shell
exec $SHELL
```

On Windows:

```powershell
# Reconfigure machine settings
chezmoi init --prompt; chezmoi apply

# Reload PowerShell session
reload
```

---

## Documentation Hub

Comprehensive, platform-specific and tool-specific guides:

| Guide | Description |
| :--- | :--- |
| [Linux Guide](docs/linux.md) | Distro packages (`apt`, `pacman`, `dnf`), Linuxbrew, WSL with `npiperelay`, Kitty, shortcuts, tips, and troubleshooting |
| [macOS Guide](docs/macos.md) | Apple Silicon & Intel Homebrew, modern Bash 5.x migration, Option-as-Alt fixes, Bitwarden SSH, Kitty, shortcuts, and troubleshooting |
| [Windows Guide](docs/windows.md) | Windows Terminal, PowerShell 7+ & 5.1, Developer Mode, Win32 Long Paths, UTC RTC dual-boot fix, OneDrive junctions, Defender exclusions |
| [Unified Shells Guide](docs/shells.md) | Feature parity matrix across **Zsh**, **Bash**, **Fish**, **Nushell**, and **PowerShell (pwsh)**, keybindings, PSReadLine, `ble.sh`, unified aliases, and `reload` |
| [Core Tools Reference](docs/tools.md) | Declarative CLI tools (`aqua`, `chezmoi`), history sync (`atuin`), fuzzy find (`fzf`), smart jump (`zoxide`), `lsd`, `bat`, `lazygit` (`lzg`), `lazydocker` (`lzd`), `lazyjournal` (`lzj`), `lnav`, `yazi` (`yy`), `bottom` (`btm`), `k9s`, and builtin multiplexer **`zellij`** |
| [Secrets & Multi-Store Guide](docs/secrets.md) | Pluggable secret store management (Bitwarden, KeePassXC, 1Password), URI routing, zero-duplication SSH keys, and automated `aqua` token sync |
| [Neovim Guide](docs/neovim.md) | Dedicated **AstroNvim v6** documentation: OneDark-Pro theme, full keyboard shortcuts cheat sheet, LSP, Mason, Lazy, plugins, tips, and troubleshooting |

---

## Daily Use

```bash
chezmoi update          # Pull latest dotfiles and re-apply
chezmoi edit ~/.zshrc   # Edit a managed file
aqua install -a         # Install/update all managed CLI tools
sheldon lock --update   # Refresh zsh plugin lockfile against upstream
```

On Windows (PowerShell):

```powershell
chezmoi update          # Pull latest dotfiles and re-apply
aqua install -a         # Update/install managed CLI tools
reload                  # Reload current PowerShell environment
```

---

## Safety Nets

### Automated Daily Sync

A native background scheduler (`launchd` on macOS, `systemd --user` on Linux, Task Scheduler on Windows) runs once a day with low CPU/I/O priority: it fast-forwards this repo, re-applies dotfiles, upgrades chezmoi/aqua/Homebrew, and refreshes the Sheldon plugin lock — all without adding a single millisecond to interactive shell startup. See the "Automated Daily Maintenance & Hot-Reloading" section of the [Unified Shells Guide](docs/shells.md) for exactly what it runs, how it skips itself when a secret store is locked, and how an already-open shell picks up the result (`reload` / `reload -f`).

### CI Guard

Every `.chezmoiscripts/` hook and `get-*.tmpl` vault lookup checks `$CI` (in addition to `$NREDF_NO_BOOTSTRAP`, see below) before it installs anything, calls a package manager, or reads a secret store, and exits cleanly instead. This is what lets `.github/scripts/check.sh` dry-run the entire tree — including the Windows and vault-gated paths — in GitHub Actions with `CI=1`, with no network access and no `bw`/`op`/`keepassxc-cli` in sight.

### `.chezmoiremove` Cleanup

[`home/.chezmoiremove.tmpl`](home/.chezmoiremove.tmpl) lists target paths chezmoi deletes on `chezmoi apply` once they're no longer part of the tracked source — how this repo retires an old config layout (completions replaced by Carapace, deprecated dotfiles, a legacy shell-override directory) without leaving orphaned files behind on every machine.

---

## Central Dependency Updates

[Renovate](renovate.json) opens PRs for everything version-pinned in this repo, not just `package.json`-style manifests:

- **GitHub Actions**: grouped, with a 3-day release wait (they run third-party code in CI).
- **mise tool versions**: parsed out of [`home/dot_config/mise/config.toml.tmpl`](home/dot_config/mise/config.toml.tmpl).
- **aqua packages**: both the registry `ref:` and each package's `version:` in [`home/dot_config/aquaproj-aqua/aqua.yaml`](home/dot_config/aquaproj-aqua/aqua.yaml), via custom regex managers (grouped as "aqua packages").
- **`ble.sh`** (`home/.chezmoidata/ble.yaml`) and **Kitty** (`home/.chezmoidata/kitty.yaml`): release-tag/version bumps.
- **The Windows aqua bootstrap** (`home/.chezmoidata/aqua-bootstrap.yaml`).

Kitty and the aqua bootstrap are also pinned by SHA-256. A Renovate PR that bumps either version alone would fail the checksum-verification CI job, so [`.github/workflows/refresh-pins.yml`](.github/workflows/refresh-pins.yml) recomputes and commits the matching hashes on the PR branch and re-runs CI, letting Renovate automerge once it's green. Minor/patch/digest bumps elsewhere automerge the same way, on green CI only.

**Recommended workflow:**

1. Let Renovate open PRs (most automerge on green CI without any action).
2. For anything that doesn't automerge, review and merge in this repository.
3. Apply everywhere via `chezmoi update`.

---

## Environment Variables

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `NREDF_DOT_PATH` | `~/.local/share/nredf` | Shell library root |
| `NREDF_COMMON_RC_PROFILE` | `full` | RC profile level (`full` / `login-minimal` / `interactive-minimal`) |
| `NREDF_NO_BOOTSTRAP` | unset | Set to `1` to skip every install/link/bootstrap hook *and* every vault secret lookup (GitHub token, git signing key, MCP servers) during `chezmoi apply` — the same switch CI flips on for its dry-runs |

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
