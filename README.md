<h1 align="center">
  NREDF &mdash; NemesisRE DotFiles
</h1>

<div align="center">
  <a href="../../commits/main">
    <img alt="Last commit" src="https://img.shields.io/github/last-commit/NemesisRE/chezmoi?style=for-the-badge&color=f2cdcd&labelColor=363a4f"/>
  </a>
  <img alt="Repo size" src="https://img.shields.io/github/repo-size/NemesisRE/chezmoi?style=for-the-badge&color=eba0ac&labelColor=363a4f"/>
  <a href="https://github.com/NemesisRE/chezmoi/actions/workflows/ci.yml">
    <img alt="CI" src="https://img.shields.io/github/actions/workflow/status/NemesisRE/chezmoi/ci.yml?branch=main&label=CI&style=for-the-badge&color=a6e3a1&labelColor=363a4f"/>
  </a>
  <img alt="License" src="https://img.shields.io/github/license/NemesisRE/chezmoi?style=for-the-badge&color=b4befe&labelColor=363a4f"/>
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
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white"/>
</div>

---

Personal cross-platform dotfiles managed with [chezmoi](https://chezmoi.io).

On a fresh machine: installs **aqua** (declarative CLI tool manager), links managed tools (including **sheldon** on zsh), and applies unified shell configurations across **Linux**, **macOS**, and **Windows**.

---

## ⚙️ Fresh Install (One-Liners)

### 🐧 Linux & 🍏 macOS

Using chezmoi's installer directly:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply NemesisRE/chezmoi
```

Or run the bootstrap script:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NemesisRE/chezmoi/main/bootstrap.sh)
```

> **Prerequisites:** `curl`, `git` (auto-installed on Debian/Ubuntu). On macOS, Homebrew is used when available.

---

### 🪟 Windows

Open **PowerShell** and run the bootstrap script:

```powershell
irm https://raw.githubusercontent.com/NemesisRE/chezmoi/main/bootstrap.ps1 | iex
```

Or using chezmoi directly via winget:

```powershell
winget install twpayne.chezmoi
chezmoi init --apply NemesisRE/chezmoi
aqua install -a -l
```

> [!TIP]
> Check the comprehensive [Windows HOWTO Guide](docs/windows.md) for Windows Terminal setup, Nerd Fonts, SSH Agent service, GPG commit signing, and system performance tweaks.

---

## 🔍 What Happens During Installation

1. **chezmoi** is installed (`~/.local/bin/chezmoi` on Unix, `%USERPROFILE%\.local\bin\chezmoi.exe` or winget on Windows)
2. The dotfiles repository is cloned to `~/.local/share/chezmoi`
3. **aqua** is installed and declarative CLI tools are linked
4. All dotfiles and profiles are applied to `~/`
5. On Unix, shell libraries are deployed to `~/.local/share/nredf/`; PowerShell dotfiles are maintained in `Documents/PowerShell` (with `~/.config/powershell` symlinked on Linux/macOS)

---

## 📝 After Install

The first interactive `chezmoi apply` or `chezmoi update` prompts for missing machine-local values defined in `home/.chezmoidata/config/` (such as Git name/email and preferred SSH agent mode). Answers are stored in `~/.config/chezmoi/nredf-local.env` and override defaults without dirtying tracked repository files.

If neither `GITHUB_TOKEN` nor `AQUA_GITHUB_TOKEN` is set, the first interactive session also offers to run `aqua token set` and store a token in your system keyring to prevent GitHub API rate limits.

```bash
# Configure git identity (name, email, signing key)
~/.local/bin/setup_git_identity.sh

# Configure aqua's GitHub token manually later
nredf_aqua_token_setup

# Restart your shell
exec $SHELL
```

On Windows:
```powershell
# Store GitHub token in Windows credential manager
aqua token set

# Reload PowerShell session
reload
```

---

## 📁 Directory Structure

The repository uses [`.chezmoiroot`](.chezmoiroot) pointing to `home/` to cleanly separate repository management files from deployed dotfiles:

| Path | Purpose |
| :--- | :--- |
| [`.chezmoiroot`](.chezmoiroot) | Directs chezmoi to use `home/` as the target dotfiles root |
| [`home/.chezmoidata/config/shell.yaml`](home/.chezmoidata/config/shell.yaml) | Shell defaults, multiplexer, SSH agent, and aqua options |
| [`home/.chezmoidata/config/devel.yaml`](home/.chezmoidata/config/devel.yaml) | Developer workspace paths and defaults |
| [`home/.chezmoidata/config/git.yaml`](home/.chezmoidata/config/git.yaml) | Git user, email, signing key, and GPG format schema |
| [`home/.chezmoidata/sheldon.yaml`](home/.chezmoidata/sheldon.yaml) | Sheldon zsh plugin configuration overrides |
| [`home/.chezmoidata/ble.yaml`](home/.chezmoidata/ble.yaml) | Ble.sh version tag |
| [`home/.chezmoiscripts/`](home/.chezmoiscripts/) | Platform lifecycle hooks (run on `chezmoi apply`) |
| [`home/dot_config/aquaproj-aqua/aqua.yaml`](home/dot_config/aquaproj-aqua/aqua.yaml) | Declarative CLI tools list managed by aqua |
| [`home/Documents/PowerShell/`](home/Documents/PowerShell/) | Unified PowerShell profile, functions, aliases, and completions |
| [`home/dot_config/oh-my-posh/config.json`](home/dot_config/oh-my-posh/config.json) | Shared Oh-My-Posh prompt theme |
| [`home/dot_local/share/nredf/shell/`](home/dot_local/share/nredf/shell/) | Bash/Zsh shell function library |
| [`docs/windows.md`](docs/windows.md) | In-depth Windows setup, tweaks, and troubleshooting guide |

---

## 🔄 Daily Use

```bash
chezmoi update          # Pull latest dotfiles and re-apply
chezmoi edit ~/.zshrc   # Edit a managed file
aqua install            # Install/update all managed CLI tools
sheldon lock            # Refresh zsh plugin lockfile
```

On Windows (PowerShell):
```powershell
chezmoi update          # Pull latest dotfiles and re-apply
aqua install            # Update/install managed CLI tools
reload                  # Reload current PowerShell environment
```

---

## 🤖 Central Dependency Updates

Centralized dependency PRs prevent drift from chezmoi-managed files:

- Renovate configuration in [renovate.json](renovate.json)
- GitHub Actions workflow updates grouped automatically
- aqua registry reference in [dot_config/aquaproj-aqua/aqua.yaml](dot_config/aquaproj-aqua/aqua.yaml) updated automatically via Renovate regex manager

**Recommended workflow:**
1. Let Renovate open PRs
2. Merge PRs in this repository
3. Apply everywhere via `chezmoi update`

---

## 🌐 Environment Variables

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `NREDF_DOT_PATH` | `~/.local/share/nredf` | Shell library root |
| `NREDF_COMMON_RC_PROFILE` | `full` | RC profile level (`full` / `login-minimal` / `interactive-minimal`) |
| `NREDF_NO_BOOTSTRAP` | unset | Set to `1` to skip aqua install + tool linking during `chezmoi apply` |
