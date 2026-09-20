#!/usr/bin/env zsh
#
# vim: ts=2 sw=2 et ff=unix ft=zsh syntax=zsh
# chezmoi-managed: oh-my-posh initialization for zsh

function _nredf_init_oh_my_posh() {
  local force_init="${1:-}"

  if [[ "${force_init}" != "--force" && "${NREDF_OH_MY_POSH_INIT_DONE:-0}" == "1" ]]; then
    return 0
  fi

  local omp_config="${XDG_CONFIG_HOME:-${HOME}/.config}/oh-my-posh/config.json"

  if command -v oh-my-posh >/dev/null 2>&1 && [[ -f "${omp_config}" ]]; then
    local omp_init_file="${XDG_CACHE_HOME}/nredf/init/omp.zsh.sh"
    if [[ -z "${POSH_SESSION_ID:-}" ]]; then
      export POSH_SESSION_ID="${RANDOM:-$$}-$$-${EPOCHSECONDS:-0}"
    fi
    _nredf_omp_gen() {
      oh-my-posh init zsh --config "${omp_config}" 2>/dev/null | sed -E 's/export POSH_SESSION_ID="[^"]*"; ?//'
    }
    _nredf_refresh_cached_shell_snippet \
      "_nredf_omp_init_zsh" \
      "${omp_init_file}" \
      _nredf_omp_gen
    unset -f _nredf_omp_gen 2>/dev/null || true
    _nredf_step "oh-my-posh init"
    NREDF_OH_MY_POSH_INIT_DONE=1
  fi
}

