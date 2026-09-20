#!/usr/bin/env zsh
#
# vim: ts=2 sw=2 et ff=unix ft=zsh syntax=zsh
# chezmoi-managed: inshellisense compatibility setup for zsh

function _nredf_setup_inshellisense() {
  if [[ -z "${ISTERM:-}" ]]; then
    return 0
  fi

  # Disable conflicting plugins during inshellisense session
  if (( ${+functions[disable-fzf-tab]} )); then
    disable-fzf-tab
  fi

  if (( ${+functions[_zsh_autosuggest_disable]} )); then
    _zsh_autosuggest_disable
  fi

  _zsh_highlight() { :; }

  # Bypass Oh-My-Posh zle .recursive-edit (which blocks prompt-end signal) and emit PS + PE immediately
  function _omp_zle-line-init() {
    builtin printf '\e]6973;PS\a\e]6973;PE\a' > /dev/tty
    return 0
  }

  function __is_zle_line_init() {
    builtin printf '\e]6973;PS\a\e]6973;PE\a' > /dev/tty
    return 0
  }
}

