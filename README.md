# nredf dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io).

On a fresh machine: installs **aqua** (CLI tool manager), then links managed tools (including **sheldon**) before applying dotfiles.

## Fresh install (one-liner)

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply NemesisRE/chezmoi
```

Or download and run the bootstrap script:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NemesisRE/chezmoi/main/bootstrap.sh)
```

> **Prerequisites (auto-installed on Debian/Ubuntu):** `curl`, `git`  
> On macOS, Homebrew is used when available; otherwise upstream installers are used.

## What happens

1. **chezmoi** is installed to `~/.local/bin/chezmoi`
2. The repo is cloned to `~/.local/share/chezmoi`
3. **aqua** is installed and managed tools (including **sheldon**) are linked
4. All dotfiles are applied to `~/`
5. Shell data is deployed to `~/.local/share/nredf/`

## After install

```bash
# Configure git identity (name, email, signing key)
~/.local/bin/setup_git_identity.sh

# Restart your shell
exec $SHELL
```

## Directory structure

| Path | Purpose |
|------|---------|
| `.chezmoidata/aqua.yaml` | CLI tools managed by aqua |
| `.chezmoidata/git.yaml` | Git identity (name, email, signing key) |
| `.chezmoidata/nredf.yaml` | nredf shell config |
| `.chezmoidata/sheldon.yaml` | Sheldon plugin config overrides |
| `.chezmoiscripts/` | Bootstrap scripts (run once on `chezmoi apply`) |
| `.config/sheldon/plugins.toml.tmpl` | Zsh plugin list |
| `.local/share/nredf/shell/` | Shell function library |

## Daily use

```bash
chezmoi update          # pull latest dotfiles and re-apply
chezmoi edit ~/.zshrc   # edit a managed file
aqua install            # install/update all managed CLI tools
sheldon lock            # refresh zsh plugin lockfile
```

## Central dependency updates

Use centralized update PRs instead of local ad-hoc updates to avoid drift from chezmoi-managed files.

- Renovate config is in [renovate.json](renovate.json)
- GitHub Actions dependency updates are grouped automatically
- aqua registry ref in [dot_config/aquaproj-aqua/aqua.yaml](dot_config/aquaproj-aqua/aqua.yaml) is updated via Renovate regex manager

Recommended workflow:

1. Let Renovate open PRs
2. Merge PRs in this repo
3. Apply everywhere via chezmoi update

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `NREDF_DOT_PATH` | `~/.local/share/nredf` | Shell library root |
| `NREDF_COMMON_RC_PROFILE` | `full` | RC profile level (`full` / `login-minimal` / `interactive-minimal`) |
| `NREDF_NO_BOOTSTRAP` | unset | Set to skip aqua install + aqua tool linking on `chezmoi apply` |
