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

  # Restore BW_SESSION from the OS keychain only — never attempt an interactive
  # unlock during shell startup. If no cached session exists, or if the cached
  # token is stale, we skip silently; the chezmoi wrapper handles unlocking on
  # demand when the user runs chezmoi directly.
  #
  # NOTE: _nredf_bw_ensure_session is intentionally NOT used here. Even with
  # 2>/dev/null, it falls through to _nredf_bw_do_unlock → `bw unlock --raw`,
  # which blocks on stdin/tty regardless of stderr redirection.
  if command -v bw &>/dev/null \
    && [[ "${NREDF_NO_BOOTSTRAP:-}" != "1" && "${CI:-}" != "true" ]]; then
    local _bw_cached
    if _bw_cached="$(_nredf_bw_keychain_get 2>/dev/null)" && [[ -n "${_bw_cached}" ]]; then
      BW_SESSION="${_bw_cached}"
      export BW_SESSION
      # Validate; if stale, clear it so the wrapper can prompt interactively
      bw unlock --check &>/dev/null \
        || { unset BW_SESSION; _nredf_bw_keychain_del 2>/dev/null || true; }
    fi
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
  # Use `command chezmoi` to bypass the BW wrapper — upgrade never reads
  # Bitwarden-backed templates, so no session injection is needed.
  if command chezmoi upgrade --quiet 2>/dev/null; then
    # Write 24h throttle timestamp (don't re-check every shell)
    _nredf_last_run "" "true" "86400"
  fi
  _nredf_remove_lock
}
