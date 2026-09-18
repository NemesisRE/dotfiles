#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
#
# Replaces nredf_sync_dotfiles: uses chezmoi update (throttled to once per 24h)

function _nredf_chezmoi_update() {
  # Check throttle: skip if last run was < 24h ago
  if _nredf_last_run; then
    return 0
  elif ! _nredf_create_lock; then
    return 0
  fi

  if ! command -v chezmoi &>/dev/null; then
    _nredf_remove_lock
    return 0
  fi

  if [[ -n "${NREDF_PROFILE_STARTUP:-}" || -n "${NREDF_VERBOSE:-}" ]]; then
    echo -e '\033[1mUpdating dotfiles and externals via chezmoi\033[0m'
  fi

  local _chezmoi_err=""
  # Run non-interactively (--no-tty and stdin from /dev/null) so startup
  # dotfile sync never silently hangs if a password safe (Bitwarden,
  # KeePassXC, 1Password) requires master password authentication.
  if _chezmoi_err="$(command chezmoi update --refresh-externals --force --no-tty </dev/null 2>&1)"; then
    # Write 24h throttle timestamp (don't re-fetch every shell)
    _nredf_last_run "" "true" "86400"
  else
    if [[ -n "${_chezmoi_err}" ]]; then
      if [[ "${_chezmoi_err}" =~ (locked|unlock|password|session|authentication|unauthorized) ]]; then
        printf '\033[1;33mℹ chezmoi update skipped: password safe is locked (unlock to sync dotfiles)\033[0m\n' >&2
      else
        printf '\033[1;33m⚠ chezmoi update failed: %s\033[0m\n' "${_chezmoi_err}" >&2
      fi
    fi
  fi
  _nredf_remove_lock
}

function _nredf_chezmoi_upgrade() {
  if _nredf_last_run; then
    return 0
  elif ! _nredf_create_lock; then
    return 0
  fi

  if ! command -v chezmoi &>/dev/null; then
    _nredf_remove_lock
    return 0
  fi

  if [[ -n "${NREDF_PROFILE_STARTUP:-}" || -n "${NREDF_VERBOSE:-}" ]]; then
    echo -e '\033[1mUpgrading chezmoi\033[0m'
  fi
  # Upgrade chezmoi binary (throttled to 24h)
  if command chezmoi upgrade >/dev/null 2>&1; then
    # Write 24h throttle timestamp (don't re-check every shell)
    _nredf_last_run "" "true" "86400"
  fi
  _nredf_remove_lock
}
