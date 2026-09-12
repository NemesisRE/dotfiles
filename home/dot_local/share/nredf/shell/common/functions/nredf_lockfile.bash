#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_create_lock() {
  _nredf_init_paths

  if [[ "${1}" != "" ]]; then
    CURRENT_FUNCTION="${1}"
  elif [[ -n $BASH_VERSION ]]; then
    local CURRENT_FUNCTION="${FUNCNAME[1]}"
  else  # zsh
    # shellcheck disable=SC2124,SC2154
    local CURRENT_FUNCTION="${funcstack[@]:1:1}"
  fi

  [[ ! -d "${NREDF_LKCACHE}" ]] && mkdir -p "${NREDF_LKCACHE}"
  local LOCK_FILE="${NREDF_LKCACHE}/${CURRENT_FUNCTION}.lock"

  touch "${LOCK_FILE}"

  exec {FD}<>"${LOCK_FILE}"

  if flock -x -w 0 ${FD}; then
    return 0
  elif [[ $(find "${LOCK_FILE}" -mtime +5 -print) ]]; then
    _nredf_remove_lock "${CURRENT_FUNCTION}"
    return 0
  else
    return 1
  fi
}

function _nredf_remove_lock() {
  _nredf_init_paths

  if [[ "${1}" != "" ]]; then
    CURRENT_FUNCTION="${1}"
  elif [[ -n $BASH_VERSION ]]; then
    local CURRENT_FUNCTION="${FUNCNAME[1]}"
  else  # zsh
    # shellcheck disable=SC2124,SC2154
    local CURRENT_FUNCTION="${funcstack[@]:1:1}"
  fi

  local LOCK_FILE="${NREDF_LKCACHE}/${CURRENT_FUNCTION}.lock"

  rm -f "${LOCK_FILE}"
}
