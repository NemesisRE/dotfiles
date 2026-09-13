#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_macos_prerquisites() {
  _nredf_init_paths

  # Homebrew environment variables to reduce unnecessary output
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_INSTALL_CLEANUP=1
  export HOMEBREW_QUIET=1

  local BREW_PATH=""
  if command -v brew &>/dev/null; then
    BREW_PATH="$(command -v brew)"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    BREW_PATH="/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    BREW_PATH="/usr/local/bin/brew"
  fi

  if [[ -z "${BREW_PATH}" ]]; then
    return 0
  fi

  if declare -f _nredf_step >/dev/null 2>&1; then _nredf_step "macOS: brew detected"; fi

  local HOMEBREW_PREFIX="${BREW_PATH%/bin/brew}"
  if ! command -v brew &>/dev/null; then
    eval "$("${BREW_PATH}" shellenv)"
    if declare -f _nredf_step >/dev/null 2>&1; then _nredf_step "macOS: brew shellenv"; fi
  fi

  local UTIL_LINUX_PREFIX="${HOMEBREW_PREFIX}/opt/util-linux"
  if [[ -d "${UTIL_LINUX_PREFIX}/bin" ]]; then
    case ":${PATH}:" in
    *":${UTIL_LINUX_PREFIX}/bin:"*) ;;
    *) export PATH="${UTIL_LINUX_PREFIX}/bin:${PATH}" ;;
    esac
  fi
  if [[ -d "${UTIL_LINUX_PREFIX}/sbin" ]]; then
    case ":${PATH}:" in
    *":${UTIL_LINUX_PREFIX}/sbin:"*) ;;
    *) export PATH="${UTIL_LINUX_PREFIX}/sbin:${PATH}" ;;
    esac
  fi
  if declare -f _nredf_step >/dev/null 2>&1; then _nredf_step "macOS: util-linux path"; fi
}
