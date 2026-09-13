#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_create_lock() {
  _nredf_init_paths

  local CURRENT_FUNCTION=""
  if [[ -n "${1:-}" ]]; then
    CURRENT_FUNCTION="${1}"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    CURRENT_FUNCTION="${FUNCNAME[1]}"
  else  # zsh
    # shellcheck disable=SC2124,SC2154
    CURRENT_FUNCTION="${funcstack[@]:1:1}"
  fi

  [[ -d "${NREDF_LKCACHE}" ]] || mkdir -p "${NREDF_LKCACHE}"
  local LOCK_DIR="${NREDF_LKCACHE}/${CURRENT_FUNCTION}.lock"

  if mkdir "${LOCK_DIR}" 2>/dev/null; then
    printf '%s\n' "$$" > "${LOCK_DIR}/pid" 2>/dev/null || true
    return 0
  fi

  # Check for stale lock: if holding process is dead, break lock
  local lock_pid=""
  if [[ -f "${LOCK_DIR}/pid" ]]; then
    read -r lock_pid < "${LOCK_DIR}/pid" 2>/dev/null || lock_pid=""
    if [[ -n "${lock_pid}" ]] && ! kill -0 "${lock_pid}" 2>/dev/null; then
      rm -rf "${LOCK_DIR}"
      if mkdir "${LOCK_DIR}" 2>/dev/null; then
        printf '%s\n' "$$" > "${LOCK_DIR}/pid" 2>/dev/null || true
        return 0
      fi
    fi
  fi

  return 1
}

function _nredf_remove_lock() {
  _nredf_init_paths

  local CURRENT_FUNCTION=""
  if [[ -n "${1:-}" ]]; then
    CURRENT_FUNCTION="${1}"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    CURRENT_FUNCTION="${FUNCNAME[1]}"
  else  # zsh
    # shellcheck disable=SC2124,SC2154
    CURRENT_FUNCTION="${funcstack[@]:1:1}"
  fi

  local LOCK_DIR="${NREDF_LKCACHE}/${CURRENT_FUNCTION}.lock"
  rm -rf "${LOCK_DIR}"
  # Clean up legacy .lock files if present
  rm -f "${NREDF_LKCACHE}/${CURRENT_FUNCTION}.lock"
}

