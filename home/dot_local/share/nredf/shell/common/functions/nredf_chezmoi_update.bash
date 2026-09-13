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
  chezmoi update --refresh-externals --force >/dev/null 2>&1 || true

  # Write 24h throttle timestamp (don't re-fetch every shell)
  _nredf_last_run "" "true" "86400"
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

  echo -e '\033[1mUpgrading chezmoi\033[0m'
  chezmoi upgrade --quiet >/dev/null 2>&1 || true
  # Write 24h throttle timestamp (don't re-check every shell)
  _nredf_last_run "" "true" "86400"
  _nredf_remove_lock
}
