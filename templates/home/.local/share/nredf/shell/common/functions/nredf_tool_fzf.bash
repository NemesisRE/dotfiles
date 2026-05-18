#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
# shellcheck disable=SC2016

# Source fzf keybindings/completions and nredf fzf customizations
function _nredf_tool_fzf_source() {
  if command -v fzf &>/dev/null; then
    if [[ "${NREDF_SHELL_NAME}" =~ ^(bash|zsh)$ ]]; then
      # Prefer modern fzf init (fzf >= 0.48 supports --zsh / --bash)
      if fzf --version 2>/dev/null | awk '{split($1,v,"."); exit !(v[1]>0 || v[2]>=48)}'; then
        eval "$(fzf "--${NREDF_SHELL_NAME}")"
      else
        # shellcheck disable=SC1090
        [[ -f "${HOME}/.config/fzf/completion.${NREDF_SHELL_NAME}" ]] && source "${HOME}/.config/fzf/completion.${NREDF_SHELL_NAME}"
        # shellcheck disable=SC1090
        [[ -f "${HOME}/.config/fzf/key-bindings.${NREDF_SHELL_NAME}" ]] && source "${HOME}/.config/fzf/key-bindings.${NREDF_SHELL_NAME}"
      fi
    fi

    # nredf fzf customizations (ssh completions, etc.)
    [[ -f "${NREDF_DOT_PATH}/shell/common/fzf" ]] && source "${NREDF_DOT_PATH}/shell/common/fzf"
  fi
}
