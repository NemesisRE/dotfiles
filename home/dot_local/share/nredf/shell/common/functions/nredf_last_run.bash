#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
# shellcheck disable=SC2155

function _nredf_last_run() {
  if [[ -z "${NREDF_LRCACHE:-}" ]]; then
    _nredf_init_paths
  fi

  local CURRENT_FUNCTION=""
  if [[ -n "${1:-}" ]]; then
    CURRENT_FUNCTION="${1}"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    CURRENT_FUNCTION="${FUNCNAME[1]}"
  else  # zsh
    # shellcheck disable=SC2124,SC2154
    CURRENT_FUNCTION="${funcstack[@]:1:1}"
  fi

  local CURRENT_TIME="${EPOCHSECONDS:-}"
  if [[ -z "${CURRENT_TIME}" ]]; then
    CURRENT_TIME="$(date +%s)"
  fi

  local SUCCESS="${2:-false}"
  local raw_next="${3:-}"
  local NEXT_RUN
  if [[ -z "${raw_next}" ]]; then
    NEXT_RUN="$((CURRENT_TIME + 43200))"
  elif (( raw_next < 100000000 )); then
    NEXT_RUN="$((CURRENT_TIME + raw_next))"
  else
    NEXT_RUN="${raw_next}"
  fi

  [[ ! -d "${NREDF_LRCACHE}" ]] && mkdir -p "${NREDF_LRCACHE}"
  local LAST_RUN_FILE="${NREDF_LRCACHE}/last_run${CURRENT_FUNCTION}.txt"
  local LAST_RUN=0
  if [[ -f "${LAST_RUN_FILE}" ]]; then
    read -r LAST_RUN < "${LAST_RUN_FILE}" 2>/dev/null || LAST_RUN=0
  fi

  if [[ "${LAST_RUN}" -gt "${CURRENT_TIME}" ]]; then
    return 0
  elif [[ "${SUCCESS}" == "true" ]]; then
    echo "${NEXT_RUN}" > "${LAST_RUN_FILE}"
    return 0
  else
    return 1
  fi
}

