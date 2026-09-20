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
  local INTERVAL=43200
  if [[ -z "${raw_next}" ]]; then
    NEXT_RUN="$((CURRENT_TIME + 43200))"
  elif (( raw_next < 100000000 )); then
    INTERVAL="${raw_next}"
    NEXT_RUN="$((CURRENT_TIME + raw_next))"
  else
    NEXT_RUN="${raw_next}"
    INTERVAL="$((raw_next - CURRENT_TIME))"
    (( INTERVAL <= 0 )) && INTERVAL=1
  fi

  local LAST_RUN_FILE="${NREDF_LRCACHE}/last_run${CURRENT_FUNCTION}.txt"

  # Fast path for recording success
  if [[ "${SUCCESS}" == "true" ]]; then
    [[ -d "${NREDF_LRCACHE}" ]] || mkdir -p "${NREDF_LRCACHE}"
    printf '%s\n' "${NEXT_RUN}" > "${LAST_RUN_FILE}"
    return 0
  fi

  [[ -f "${LAST_RUN_FILE}" ]] || return 1

  # In Zsh: zero-fork mtime check using glob qualifier.
  # Note: filename generation does NOT happen inside [[ ... ]], so the qualifier
  # must be applied in an array assignment, not a -n test.
  if [[ -n "${ZSH_VERSION:-}" ]] && eval "local -a _m=( \"\${LAST_RUN_FILE}\"(Nms-\${INTERVAL}) ); (( \${#_m} ))"; then
    return 0
  fi

  local LAST_RUN=0
  read -r LAST_RUN < "${LAST_RUN_FILE}" 2>/dev/null || LAST_RUN=0

  if [[ "${LAST_RUN}" -gt "${CURRENT_TIME}" ]]; then
    return 0
  fi
  return 1
}

