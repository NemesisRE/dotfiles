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

  # Pre-load BW_SESSION from keychain so bitwarden template functions don't
  # prompt interactively at shell startup (no-op if bw is not installed).
  # stderr IS suppressed here intentionally: this runs during shell init and
  # a blocking password prompt would freeze every new shell. If no valid
  # keychain session exists we skip silently; the interactive chezmoi wrapper
  # function will handle unlocking when the user runs chezmoi directly.
  if command -v bw &>/dev/null \
    && [[ "${NREDF_NO_BOOTSTRAP:-}" != "1" && "${CI:-}" != "true" ]]; then
    _nredf_bw_ensure_session 2>/dev/null || true
  fi

  local _chezmoi_err=""
  if _chezmoi_err="$(chezmoi update --refresh-externals --force 2>&1)"; then
    # Write 24h throttle timestamp (don't re-fetch every shell)
    _nredf_last_run "" "true" "86400"
  else
    if [[ -n "${_chezmoi_err}" ]]; then
      printf '\033[1;33m⚠ chezmoi update failed: %s\033[0m\n' "${_chezmoi_err}" >&2
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
  if chezmoi upgrade --quiet 2>/dev/null; then
    # Write 24h throttle timestamp (don't re-check every shell)
    _nredf_last_run "" "true" "86400"
  fi
  _nredf_remove_lock
}
