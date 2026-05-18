#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_normalize_configs() {
  if [[ -z "${NREDF_CONFIGS+x}" ]]; then
    return 0
  fi

  local key canonical value

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    local -a kv
    local i
    eval 'kv=("${(@kv)NREDF_CONFIGS}")'
    for (( i = 1; i <= ${#kv}; i += 2 )); do
      key="${kv[i]}"
      value="${kv[i+1]}"
      canonical="${key#\"}"
      canonical="${canonical%\"}"
      NREDF_CONFIGS[${canonical}]="${value}"
      NREDF_CONFIGS["\"${canonical}\""]="${value}"
    done
    return 0
  fi

  if [[ -n "${BASH_VERSION:-}" ]]; then
    if ! declare -p NREDF_CONFIGS 2>/dev/null | grep -q 'declare -A'; then
      return 0
    fi

    local -a keys
    keys=("${!NREDF_CONFIGS[@]}")
    for key in "${keys[@]}"; do
      canonical="${key#\"}"
      canonical="${canonical%\"}"
      value="${NREDF_CONFIGS[$key]}"
      NREDF_CONFIGS[$canonical]="${value}"
      NREDF_CONFIGS["\"$canonical\""]="${value}"
    done
  fi
}
