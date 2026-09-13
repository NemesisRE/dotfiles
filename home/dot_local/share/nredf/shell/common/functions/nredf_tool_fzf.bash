#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
# shellcheck disable=SC2016

# Source fzf keybindings/completions and nredf fzf customizations
function _nredf_tool_fzf_source() {
  if command -v fzf &>/dev/null; then
    if [[ "${NREDF_SHELL_NAME}" =~ ^(bash|zsh)$ ]]; then
      local fzf_cache="${XDG_CACHE_HOME:-${HOME}/.cache}/nredf/init/fzf.${NREDF_SHELL_NAME}.sh"
      if command -v _nredf_refresh_cached_shell_snippet &>/dev/null; then
        _nredf_refresh_cached_shell_snippet \
          "_nredf_fzf_init_${NREDF_SHELL_NAME}" \
          "${fzf_cache}" \
          fzf "--${NREDF_SHELL_NAME}"
      elif fzf "--${NREDF_SHELL_NAME}" &>/dev/null; then
        eval "$(fzf "--${NREDF_SHELL_NAME}")"
      fi

      if [[ ! -s "${fzf_cache}" ]]; then
        # shellcheck disable=SC1090
        [[ -f "${HOME}/.config/fzf/completion.${NREDF_SHELL_NAME}" ]] && source "${HOME}/.config/fzf/completion.${NREDF_SHELL_NAME}"
        # shellcheck disable=SC1090
        [[ -f "${HOME}/.config/fzf/key-bindings.${NREDF_SHELL_NAME}" ]] && source "${HOME}/.config/fzf/key-bindings.${NREDF_SHELL_NAME}"
      fi


      if [[ "${NREDF_SHELL_NAME}" == "bash" ]]; then
        # Prevent fzf's complete -D fallback from intercepting command-name completion
        complete -F _comp_complete_load -D 2>/dev/null || complete -r -D 2>/dev/null
        # On macOS, Option+c can send ç (\xC3\xA7) or © (\xC2\xA9) instead of \ec
        bind '"\xC3\xA7": "\ec"' 2>/dev/null || true
        bind '"ç": "\ec"' 2>/dev/null || true
        bind '"\xC2\xA9": "\ec"' 2>/dev/null || true
        bind '"©": "\ec"' 2>/dev/null || true
      elif [[ "${NREDF_SHELL_NAME}" == "zsh" ]]; then
        # On macOS, Option+c can send ç or © instead of \ec
        if (( ${+widgets[fzf-cd-widget]} )); then
          bindkey 'ç' fzf-cd-widget 2>/dev/null || true
          bindkey '©' fzf-cd-widget 2>/dev/null || true
          bindkey -M vicmd 'ç' fzf-cd-widget 2>/dev/null || true
          bindkey -M viins 'ç' fzf-cd-widget 2>/dev/null || true
        fi
      fi
    fi

    # nredf fzf customizations (ssh completions, etc.)
    [[ -f "${NREDF_DOT_PATH}/shell/common/fzf" ]] && source "${NREDF_DOT_PATH}/shell/common/fzf"
  fi
}
