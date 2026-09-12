#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
# shellcheck disable=SC2155

function _nredf_last_run() {
  _nredf_init_paths

  if [[ "${1}" != "" ]]; then
    CURRENT_FUNCTION="${1}"
  elif [[ -n $BASH_VERSION ]]; then
    local CURRENT_FUNCTION="${FUNCNAME[1]}"
  else  # zsh
    # shellcheck disable=SC2124,SC2154
    local CURRENT_FUNCTION="${funcstack[@]:1:1}"
  fi
  local SUCCESS="${2:-"false"}"
  local NEXT_RUN="${3:-"$(($(date +%s) + 43200))"}"
  local CURRENT_TIME="$(date +%s)"
  [[ ! -d "${NREDF_LRCACHE}" ]] && mkdir -p "${NREDF_LRCACHE}"
  local LAST_RUN_FILE="${NREDF_LRCACHE}/last_run${CURRENT_FUNCTION}.txt"
  local LAST_RUN="$(cat "${LAST_RUN_FILE}" 2>/dev/null || echo "0")"

  if [[ "${LAST_RUN}" -gt "${CURRENT_TIME}" ]]; then
    return 0
  elif ${SUCCESS}; then
    echo "${NEXT_RUN}" > "${LAST_RUN_FILE}"
    return 0
  else
    return 1
  fi
}
