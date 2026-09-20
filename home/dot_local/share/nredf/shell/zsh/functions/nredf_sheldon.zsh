#!/usr/bin/env zsh
#
# vim: ts=2 sw=2 et ff=unix ft=zsh syntax=zsh
# chezmoi-managed: sheldon plugin management for zsh

function _nredf_update_sheldon_plugins() {
  local sheldon_conf="${XDG_CONFIG_HOME:-${HOME}/.config}/sheldon/plugins.toml"

  if [[ ! -f "${sheldon_conf}" ]]; then
    return 0
  fi

  if ! command -v sheldon >/dev/null 2>&1; then
    return 0
  fi

  if ! _nredf_last_run "_nredf_update_sheldon_plugins"; then
    if ! _nredf_create_lock; then
      return 0
    fi

    _nredf_last_run "_nredf_update_sheldon_plugins" "true" "86400"
    local sheldon_lock_opts=(--color never)
    if [[ -z "${NREDF_VERBOSE:-}" && -z "${NREDF_PROFILE_STARTUP:-}" ]]; then
      sheldon_lock_opts+=(--quiet)
    fi
    sheldon "${sheldon_lock_opts[@]}" lock --update >/dev/null 2>&1 || true
    _nredf_remove_lock
  fi
}

function _nredf_load_sheldon_plugins() {
  # Initialize completion before plugin load if compdef is still unavailable.
  if (( ! ${+functions[compdef]} )); then
    autoload -Uz compinit
    if (( ${+functions[_nredf_compinit]} )); then
      _nredf_compinit -i
    else
      compinit -i
    fi
  fi
  local sheldon_cache="${XDG_CACHE_HOME:-${HOME}/.cache}/sheldon/sheldon.zsh"
  local sheldon_conf="${XDG_CONFIG_HOME:-${HOME}/.config}/sheldon/plugins.toml"
  local sheldon_lock="${XDG_DATA_HOME:-${HOME}/.local/share}/sheldon/plugins.lock"
  local regenerate=0

  if [[ ! -s "${sheldon_cache}" ]]; then
    regenerate=1
  elif [[ -f "${sheldon_conf}" && "${sheldon_conf}" -nt "${sheldon_cache}" ]]; then
    regenerate=1
  elif [[ -f "${sheldon_lock}" && "${sheldon_lock}" -nt "${sheldon_cache}" ]]; then
    regenerate=1
  fi

  if (( regenerate )); then
    local sheldon_source_opts=(--color never)
    if [[ -z "${NREDF_VERBOSE:-}" && -z "${NREDF_PROFILE_STARTUP:-}" ]]; then
      sheldon_source_opts+=(--quiet)
    fi
    mkdir -p "${sheldon_cache%/*}"
    if sheldon "${sheldon_source_opts[@]}" source >| "${sheldon_cache}" 2>/dev/null; then
      zcompile "${sheldon_cache}" >/dev/null 2>&1 || true
      source "${sheldon_cache}"
    else
      rm -f "${sheldon_cache}" "${sheldon_cache}.zwc"
      eval "$(sheldon "${sheldon_source_opts[@]}" source)"
    fi
  else
    if [[ ! -f "${sheldon_cache}.zwc" || "${sheldon_cache}" -nt "${sheldon_cache}.zwc" ]]; then
      zcompile "${sheldon_cache}" >/dev/null 2>&1 || true
    fi
    source "${sheldon_cache}"
  fi

  _nredf_init_oh_my_posh --force

  if (( ${+functions[_nredf_init_kitty_shell_integration]} )); then
    _nredf_init_kitty_shell_integration --force
  fi

  # Ensure atuin keybindings are bound if atuin is installed and widget exists
  if (( ${+widgets[atuin-search]} )); then
    bindkey -M emacs '^r' atuin-search
    bindkey -M viins '^r' atuin-search-viins
    bindkey -M vicmd '/' atuin-search
    bindkey -M emacs '^[[A' atuin-up-search
    bindkey -M vicmd '^[[A' atuin-up-search-vicmd
    bindkey -M viins '^[[A' atuin-up-search-viins
    bindkey -M emacs '^[OA' atuin-up-search
    bindkey -M vicmd '^[OA' atuin-up-search-vicmd
    bindkey -M viins '^[OA' atuin-up-search-viins
    bindkey -M vicmd 'k' atuin-up-search-vicmd
  fi

  # Ensure fzf-cd-widget is bound to ç and © on macOS (Option+c special character)
  if (( ${+widgets[fzf-cd-widget]} )); then
    bindkey -M emacs 'ç' fzf-cd-widget 2>/dev/null || true
    bindkey -M viins 'ç' fzf-cd-widget 2>/dev/null || true
    bindkey -M vicmd 'ç' fzf-cd-widget 2>/dev/null || true
    bindkey -M emacs '©' fzf-cd-widget 2>/dev/null || true
    bindkey -M viins '©' fzf-cd-widget 2>/dev/null || true
    bindkey -M vicmd '©' fzf-cd-widget 2>/dev/null || true
  fi

  if (( ${+functions[_nredf_setup_inshellisense]} )); then
    _nredf_setup_inshellisense
  fi
}
