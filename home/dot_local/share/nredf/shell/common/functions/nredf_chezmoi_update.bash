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

  # If bw is installed, ensure the vault is unlocked before running chezmoi —
  # templates need BW secrets. Try the keychain first (silent); if the vault is
  # still locked, prompt the user interactively (stderr visible so the master-
  # password prompt is not hidden). Only skip the update if unlock fails.
  if command -v bw &>/dev/null \
    && [[ "${NREDF_NO_BOOTSTRAP:-}" != "1" && "${CI:-}" != "true" ]]; then
    if [[ -z "${BW_SESSION:-}" ]]; then
      local _bw_cached
      if _bw_cached="$(_nredf_bw_keychain_get 2>/dev/null)" && [[ -n "${_bw_cached}" ]]; then
        BW_SESSION="${_bw_cached}"
        export BW_SESSION
      fi
    fi
    if ! bw unlock --check &>/dev/null; then
      _nredf_bw_ensure_session || { _nredf_remove_lock; return 0; }
    fi
  fi

  local _chezmoi_err=""
  # Use `command chezmoi` to bypass the BW wrapper — the keychain pre-load
  # above already exported BW_SESSION when a cached session existed. Chezmoi's
  # own `unlock = "auto"` config handles any remaining BW auth for templates.
  if _chezmoi_err="$(command chezmoi update --refresh-externals --force 2>&1)"; then
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
  # Use `command chezmoi` to bypass the BW wrapper — upgrade never reads
  # Bitwarden-backed templates, so no session injection is needed.
  if command chezmoi upgrade --quiet 2>/dev/null; then
    # Write 24h throttle timestamp (don't re-check every shell)
    _nredf_last_run "" "true" "86400"
  fi
  _nredf_remove_lock
}
