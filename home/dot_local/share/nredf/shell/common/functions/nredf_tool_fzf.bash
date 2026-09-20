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
        [[ -f "${HOME}/.config/fzf/completion.${NREDF_SHELL_NAME}" ]] && source "${HOME}/.config/fzf/completion.${NREDF_SHELL_NAME}"
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
        # Readline binding for fzf tab completion
        bind -x '"\C-@": _nredf_fzf_tab_complete' 2>/dev/null || true
        bind -x '"\C- ": _nredf_fzf_tab_complete' 2>/dev/null || true
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
  fi
}

# Fuzzy tab completion with descriptions for Bash / ble.sh (Ctrl+Space)
function _nredf_fzf_tab_complete() {
  command -v fzf &>/dev/null || return 0

  local line="${READLINE_LINE:-}"
  local point="${READLINE_POINT:-0}"
  local prefix="${line:0:point}"
  local suffix="${line:point}"

  local cur_word=""
  local start_pos=0
  if [[ "$prefix" =~ [[:space:]]$ ]] || [[ -z "$prefix" ]]; then
    cur_word=""
    start_pos=$point
  else
    cur_word="${prefix##* }"
    start_pos=$(( point - ${#cur_word} ))
  fi

  local compline="$prefix"
  local cmd_name=""
  read -r cmd_name _ <<< "$compline"

  local -a candidates=()
  if [[ -n "$cmd_name" ]] && command -v carapace &>/dev/null; then
    mapfile -t candidates < <(echo "$compline" | sed -e "s/ \$/ ''/" | xargs carapace "$cmd_name" bash-ble 2>/dev/null)
    local -a valid=()
    for c in "${candidates[@]}"; do
      [[ -z "$c" || "$c" =~ ^ERR[[:space:]] ]] && continue
      valid+=("$c")
    done
    candidates=("${valid[@]}")
  fi

  # Fallback if no carapace candidates: compgen
  if ((${#candidates[@]} == 0)); then
    local -a raw=()
    if [[ -z "$cmd_name" || "$prefix" != *" "* ]]; then
      mapfile -t raw < <(compgen -c -- "$cur_word" 2>/dev/null | sort -u)
    else
      mapfile -t raw < <(compgen -f -- "$cur_word" 2>/dev/null)
    fi
    for r in "${raw[@]}"; do
      [[ -n "$r" ]] && candidates+=("$r"$'\t'"$r")
    done
  fi

  local count=${#candidates[@]}
  if ((count == 0)); then
    printf '\a'
    return 0
  fi

  local selected=""
  if ((count == 1)); then
    selected="${candidates[0]}"
  else
    selected=$(printf '%s\n' "${candidates[@]}" | fzf \
      --reverse \
      --height=40% \
      --ansi \
      --delimiter=$'\t' \
      --with-nth=2 \
      --bind="tab:down,btab:up" \
      --query="$cur_word")
  fi

  [[ -z "$selected" ]] && return 0

  local value="${selected%%$'\t'*}"
  local insert="$value"
  if [[ "$insert" != */ && "$insert" != *: && "$insert" != *= ]]; then
    insert="$insert "
  fi

  READLINE_LINE="${line:0:start_pos}${insert}${suffix}"
  READLINE_POINT=$(( start_pos + ${#insert} ))
}
