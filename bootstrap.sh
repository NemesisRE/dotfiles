#!/usr/bin/env bash
# Bootstrap nredf dotfiles on a fresh machine (macOS, Ubuntu, Debian, …).
#
# Usage (after pushing to GitHub):
#   bash <(curl -fsSL https://raw.githubusercontent.com/NemesisRE/chezmoi/main/bootstrap.sh)
#
# Or using chezmoi's own one-liner (no need to clone first):
#   sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply NemesisRE/chezmoi
#
# The DOTFILES_REPO env var can override the GitHub user/repo slug.

set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-NemesisRE/chezmoi}"

step()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
info()  { printf '    %s\n' "$*"; }
warn()  { printf '\033[33m    WARNING: %s\033[0m\n' "$*"; }

# ── Prerequisites ──────────────────────────────────────────────────────────────
if [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ -x /opt/homebrew/bin/brew ]] && [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
    export PATH="/opt/homebrew/bin:${PATH}"
  fi
  if ! xcode-select -p &>/dev/null; then
    step "Installing Xcode Command Line Tools"
    xcode-select --install || true
  fi
  if ! command -v brew &>/dev/null && [[ ! -x /opt/homebrew/bin/brew && ! -x /usr/local/bin/brew ]]; then
    step "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
    if [[ -x /opt/homebrew/bin/brew ]] && [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
      export PATH="/opt/homebrew/bin:${PATH}"
    fi
  fi
elif command -v apt-get &>/dev/null; then
  MISSING=()
  command -v curl &>/dev/null || MISSING+=(curl)
  command -v git  &>/dev/null || MISSING+=(git)
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    step "Installing prerequisites: ${MISSING[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${MISSING[@]}"
  fi
fi


# ── chezmoi ────────────────────────────────────────────────────────────────────
LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "${LOCAL_BIN}"
export PATH="${LOCAL_BIN}:${PATH}"

if ! command -v chezmoi &>/dev/null; then
  step "Installing chezmoi"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${LOCAL_BIN}"
fi

# ── Apply dotfiles ─────────────────────────────────────────────────────────────
# chezmoi init --apply will:
#   1. Clone this repo to ~/.local/share/chezmoi
#   2. Run .chezmoiscripts/run_once_before_install-tools.sh  (installs aqua, links sheldon via aqua)
#   3. Apply all managed dotfiles to ~/
step "Applying dotfiles (${DOTFILES_REPO})"
chezmoi init --apply "${DOTFILES_REPO}"

AQUA_BIN="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/aquaproj-aqua}/bin"
if [[ -d "${AQUA_BIN}" ]] && [[ ":$PATH:" != *":${AQUA_BIN}:"* ]]; then
  export PATH="${AQUA_BIN}:${PATH}"
fi

if command -v aqua &>/dev/null; then
  step "Linking aqua-managed tools"
  aqua install -a -l >/dev/null 2>&1 || true
fi


# ── Done ───────────────────────────────────────────────────────────────────────
step "Done"
info "Open a new terminal (or run: exec \$SHELL) to activate your shell config."
info ""
info "Useful commands:"
info "  chezmoi update        — pull latest dotfiles and re-apply"
info "  chezmoi edit ~/.zshrc — edit a managed file"
info "  aqua install          — install/update all managed CLI tools"
