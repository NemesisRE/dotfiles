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

    # The user's own ~/.config/<shell>/aliases is intentionally NOT sourced
    # here: this function runs under `setopt localoptions`, which reverts any
    # `setopt`/`unsetopt` a sourced file makes as soon as the function
    # returns. The caller sources it at top level instead — see rc.tmpl.
  else
    if [[ ! -d "${NREDF_RC_LOCAL}" ]]; then
      mkdir -p "${NREDF_RC_LOCAL}"
    fi

    # Bundle loads first so a user override in NREDF_RC_LOCAL/functions
    # (loaded below) can rely on — or redefine — anything nredf itself defines.
    if [[ -s "${NREDF_RC_PATH}/functions.bundle" ]]; then
      source "${NREDF_RC_PATH}/functions.bundle"
    fi

    if [[ -d "${NREDF_RC_LOCAL}/functions" ]]; then
      for NREDF_LOCAL_FUNCTIONS in "${NREDF_RC_LOCAL}/functions/"*; do
        [[ -f "${NREDF_LOCAL_FUNCTIONS}" ]] || continue
        [[ "${NREDF_LOCAL_FUNCTIONS}" == *.md ]] && continue
        source "${NREDF_LOCAL_FUNCTIONS}"
      done
    fi

    # The user's own ~/.config/<shell>/rc is intentionally NOT sourced here —
    # see the comment above the aliases branch; the caller sources it at top
    # level instead.
  fi
}
