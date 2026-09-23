#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

_nredf_set_local () {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt localoptions nullglob
  fi
  _nredf_init_paths

  local ALIAS=${1:-false}
  if ${ALIAS}; then
    if [[ -f "${NREDF_DOT_PATH}/shell/common/aliases" ]]; then
      source "${NREDF_DOT_PATH}/shell/common/aliases"
    fi

    if [[ -f "${NREDF_RC_PATH}/aliases" ]]; then
      source "${NREDF_RC_PATH}/aliases"
    fi

    if [[ -f "${NREDF_RC_LOCAL}/aliases" ]]; then
      source "${NREDF_RC_LOCAL}/aliases"
    fi
  else
    if [[ ! -d "${NREDF_RC_LOCAL}" ]]; then
      mkdir -p "${NREDF_RC_LOCAL}"
    fi

    if [[ -d "${NREDF_RC_LOCAL}/functions" ]]; then
      for NREDF_LOCAL_FUNCTIONS in "${NREDF_RC_LOCAL}/functions/"*; do
        [[ -f "${NREDF_LOCAL_FUNCTIONS}" ]] || continue
        [[ "${NREDF_LOCAL_FUNCTIONS}" == *.md ]] && continue
        source "${NREDF_LOCAL_FUNCTIONS}"
      done
    fi

    if [[ -s "${NREDF_RC_PATH}/functions.bundle" ]]; then
      source "${NREDF_RC_PATH}/functions.bundle"
    elif [[ -f "${NREDF_RC_PATH}/functions" ]]; then
      source "${NREDF_RC_PATH}/functions"
    fi

    if [[ -f "${NREDF_RC_LOCAL}/rc" ]]; then
      source "${NREDF_RC_LOCAL}/rc"
    fi
  fi
}
