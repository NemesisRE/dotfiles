#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_set_krew_path() {
  local _nredf_krew_root="${KREW_ROOT:-${HOME}/.krew}"
  local _nredf_krew_bin="${_nredf_krew_root}/bin"

  if [[ -d "${_nredf_krew_bin}" ]]; then
    export KREW_ROOT="${_nredf_krew_root}"
    case ":${PATH}:" in
    *":${_nredf_krew_bin}:"*) ;;
    *) export PATH="${_nredf_krew_bin}:${PATH}" ;;
    esac
  fi

  unset _nredf_krew_root _nredf_krew_bin
}

# Prepend each directory to PATH, in argument order, unless it is already on
# PATH. The rc files re-run _nredf_set_defaults in every nested shell
# (NREDF_COMMON_DEFAULTS_DONE is not exported, so a child still gets its
# aliases and functions), and a blind prepend grew PATH at every level.
# Skipping entries that are already present also keeps the parent's order.
function _nredf_path_prepend() {
  local _nredf_dir _nredf_prefix=""
  for _nredf_dir in "$@"; do
    [[ -n "${_nredf_dir}" ]] || continue
    case ":${_nredf_prefix}${PATH}:" in
    *":${_nredf_dir}:"*) ;;
    *) _nredf_prefix="${_nredf_prefix}${_nredf_dir}:" ;;
    esac
  done
  if [[ -n "${_nredf_prefix}" ]]; then
    export PATH="${_nredf_prefix%:}${PATH:+:${PATH}}"
  fi
}

function _nredf_set_defaults() {
  _nredf_set_aqua_path
  _nredf_set_aqua_env
  _nredf_set_krew_path

  [[ -f "${HOME}/.proxy.local" ]] && source "${HOME}/.proxy.local"

  # Set language environment if not already configured with a UTF-8 locale
  if [[ -z "${LANG:-}" || "${LANG:-}" == "C" ]]; then
    local _nredf_locale="C" _nredf_locales
    _nredf_locales="$(locale -a 2>/dev/null)"
    if grep -qiE '^en_US\.UTF-?8$' <<<"${_nredf_locales}"; then
      _nredf_locale="en_US.UTF-8"
    elif grep -qiE '^C\.UTF-?8$' <<<"${_nredf_locales}"; then
      _nredf_locale="C.UTF-8"
    fi
    export LANG="${_nredf_locale}"
    export LANGUAGE="${_nredf_locale}"
    export LC_ALL="${_nredf_locale}"
  fi

  _nredf_init_paths

  _nredf_path_prepend "${HOME}/bin" "${XDG_BIN_HOME}" /usr/local/bin
  if [[ -d /snap/bin ]]; then
    case ":${PATH}:" in
    *":/snap/bin:"*) ;;
    *) export PATH="${PATH}:/snap/bin" ;;
    esac
  fi
  export GOPATH="${HOME}/.local"
  export RLWRAP_HOME="${XDG_CACHE_HOME}/RLWRAP"

  # Set default editor (nvim -> hx -> vi)
  if command -v nvim &>/dev/null; then
    export EDITOR="nvim"
    export VISUAL="nvim"
    export GIT_EDITOR="nvim"
  elif command -v hx &>/dev/null; then
    export EDITOR="hx"
    export VISUAL="hx"
    export GIT_EDITOR="hx"
  else
    export EDITOR="vi"
    export VISUAL="vi"
    export GIT_EDITOR="vi"
  fi

  # Bat Defaults
  export BAT_THEME="OneDarkPro"
  # Render man pages through bat (bat's documented recipe). MANROFFOPT=-c makes
  # groff emit the overstrike output `col -bx` expects. A MANPAGER set by the
  # user or inherited from a parent shell wins.
  if [[ -z "${MANPAGER:-}" ]] && command -v bat &>/dev/null; then
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export MANROFFOPT="-c"
  fi

  # FZF Defaults
  export FZF_DEFAULT_OPTS='--bind tab:down --bind btab:up --cycle --ansi --color=dark,bg+:#2c313c,bg:#282c34,gutter:#282c34,spinner:#e5c07b,hl:#e06c75,fg:#abb2bf,header:#61afef,info:#56b6c2,pointer:#c678dd,marker:#98c379,fg+:#abb2bf,prompt:#61afef,hl+:#98c379,border:#4f5666'
  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type file --follow --hidden --exclude .git --color=always'
    export FZF_ALT_C_COMMAND="fd --type directory --hidden --follow --exclude .git"
  else
    export FZF_DEFAULT_COMMAND="find -L"
  fi
  export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
  if command -v bat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --theme=OneDarkPro {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
  fi
  if command -v lsd &>/dev/null; then
    export FZF_ALT_C_OPTS="--preview 'lsd -A --tree --depth=2 --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
  fi


  #  VIM/NVIM Defaults
  if [[ -f "${XDG_CONFIG_HOME}/vim/gvimrc" ]]; then
    # shellcheck disable=SC2016
    export GVIMINIT='let $MYGVIMRC="$XDG_CONFIG_HOME/vim/gvimrc" | source $MYGVIMRC'
  else
    unset GVIMINIT
  fi
  if [[ -f "${XDG_CONFIG_HOME}/vim/vimrc" ]]; then
    # shellcheck disable=SC2016
    export VIMINIT='let $MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc" | source $MYVIMRC'
  else
    unset VIMINIT
  fi
  export NVIM_LOG_FILE="${XDG_STATE_HOME}/nvim/log"

  # Timewarrior
  export TIMEWARRIORDB="${XDG_CACHE_HOME}/timewarrior"

  # docker-compose
  export COMPOSE_PARALLEL_LIMIT=10
  export COMPOSE_HTTP_TIMEOUT=600

  # k9s config directory
  export K9SCONFIG="${XDG_CONFIG_HOME}/k9s"

  # readline config
  export INPUTRC="${XDG_CONFIG_HOME}/readline/inputrc"

  # Only point X clients at the XDG runtime copy when nothing (display manager,
  # `ssh -X`) set XAUTHORITY already and that file actually exists. Exporting it
  # unconditionally broke X forwarding and yielded `/Xauthority` on macOS.
  if [[ -z "${XAUTHORITY:-}" && -n "${XDG_RUNTIME_DIR:-}" && -f "${XDG_RUNTIME_DIR}/Xauthority" ]]; then
    export XAUTHORITY="${XDG_RUNTIME_DIR}/Xauthority"
  fi

  # Let carapace fall back to other shells' completions for commands it has no
  # spec for. A user-set value wins.
  export CARAPACE_BRIDGES="${CARAPACE_BRIDGES:-zsh,fish,bash}"

  # make less more friendly for non-text input files, see lesspipe(1).
  # Cached like the other tool-init snippets (cleared by `reload -c`), so
  # nested shells do not fork lesspipe/dircolors again.
  if [[ -x /usr/bin/lesspipe ]]; then
    _nredf_refresh_cached_shell_snippet \
      "_nredf_lesspipe_${NREDF_SHELL_NAME}" \
      "${XDG_CACHE_HOME}/nredf/init/lesspipe.${NREDF_SHELL_NAME}.sh" \
      env SHELL=/bin/sh /usr/bin/lesspipe
  fi

  if command -v dircolors &>/dev/null && [[ -e "${XDG_CONFIG_HOME}/dircolors" ]]; then
    local _nredf_dircolors_cache="${XDG_CACHE_HOME}/nredf/init/dircolors.${NREDF_SHELL_NAME}.sh"
    # An edited (or re-applied) dircolors file invalidates the cache right away
    # instead of waiting out the 24h stamp.
    if [[ -e "${_nredf_dircolors_cache}" && "${XDG_CONFIG_HOME}/dircolors" -nt "${_nredf_dircolors_cache}" ]]; then
      rm -f "${_nredf_dircolors_cache}" "${_nredf_dircolors_cache}.zwc"
    fi
    _nredf_refresh_cached_shell_snippet \
      "_nredf_dircolors_${NREDF_SHELL_NAME}" \
      "${_nredf_dircolors_cache}" \
      dircolors -b "${XDG_CONFIG_HOME}/dircolors"
  fi

  # Less pager defaults & history hygiene
  export LESS="-R -F -X -i"
  export LESSHISTFILE="${XDG_STATE_HOME:-${HOME}/.local/state}/less/history"

  # Tool config paths
  export WGETRC="${XDG_CONFIG_HOME}/wgetrc"
  export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}/ripgrep/config"
  export GH_CONFIG_DIR="${XDG_CONFIG_HOME}/gh"
  export POWERSHELL_UPDATECHECK="Off"
}
