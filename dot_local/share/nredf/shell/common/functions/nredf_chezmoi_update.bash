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

  local SRC
  SRC="$(chezmoi source-path 2>/dev/null)" || SRC=""
  if [[ -z "${SRC}" || ! -d "${SRC}" ]]; then
    _nredf_remove_lock
    return 0
  fi

  # Fast check: only fetch if remote is configured
  local CHANGED=false
  if command -v git &>/dev/null; then
    if git -C "${SRC}" fetch --quiet 2>/dev/null; then
      local LOCAL REMOTE
      LOCAL="$(git -C "${SRC}" rev-parse @ 2>/dev/null)"
      REMOTE="$(git -C "${SRC}" rev-parse '@{u}' 2>/dev/null)"
      if [[ -n "${REMOTE}" && "${LOCAL}" != "${REMOTE}" ]]; then
        CHANGED=true
      fi
    fi
  fi

  # Write 24h throttle timestamp regardless of changes (don't re-fetch every shell)
  _nredf_last_run "" "true" "$(($(date +%s) + 86400))"
  _nredf_remove_lock

  if ${CHANGED}; then
    echo -e '\033[1mPulling dotfiles\033[0m'
    if chezmoi update --apply --force 2>&1; then
      echo -e '\033[1mDotfiles updated — reloading shell\033[0m'
      exec "${SHELL}"
    fi
  fi
}
