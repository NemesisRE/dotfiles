#!/usr/bin/env zsh
#
# vim: ts=2 sw=2 et ff=unix ft=zsh syntax=zsh
# chezmoi-managed: sheldon plugin management for zsh

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

  # fzf-cd-widget's ç/© (Option+c) binding lives in _nredf_tool_fzf_source
  # (common/functions/nredf_tool_fzf.bash), which runs right after the
  # fzf --zsh snippet that defines the widget in the first place — doing it
  # here too was a pure duplicate rebind of the same widget to the same keys.

  if (( ${+functions[_nredf_setup_inshellisense]} )); then
    _nredf_setup_inshellisense
  fi
}
