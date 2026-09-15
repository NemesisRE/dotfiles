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

function _nredf_set_defaults() {
  _nredf_set_aqua_path
  _nredf_set_aqua_env
  _nredf_set_krew_path

  [[ -f "${HOME}/.proxy.local" ]] && source "${HOME}/.proxy.local"

  export NREDF_COMMON_RC_LOCAL="${HOME}/.config/shell"
  export NREDF_RC_PATH="${NREDF_DOT_PATH}/shell/${NREDF_SHELL_NAME}"
  export NREDF_RC_LOCAL="${HOME}/.config/${NREDF_SHELL_NAME}"

  # Set language environment if not already configured with a UTF-8 locale
  if [[ -z "${LANG:-}" || "${LANG:-}" == "C" ]]; then
    local _nredf_locale="C"
    if locale -a 2>/dev/null | grep -qiE '^en_US\.UTF-?8$'; then
      _nredf_locale="en_US.UTF-8"
    elif locale -a 2>/dev/null | grep -qiE '^C\.UTF-?8$'; then
      _nredf_locale="C.UTF-8"
    fi
    export LANG="${_nredf_locale}"
    export LANGUAGE="${_nredf_locale}"
    export LC_ALL="${_nredf_locale}"
  fi


  _nredf_init_paths

  export PATH="${HOME}/bin:${XDG_BIN_HOME}:/usr/local/bin:${PATH}"
  [[ -d /snap/bin ]] && export PATH="${PATH}:/snap/bin"
  export GOPATH="${HOME}/.local"
  export RLWRAP_HOME="${XDG_CACHE_HOME}/RLWRAP"
  [[ -s "${HOME}/.rvm/scripts/rvm" ]] && source "${HOME}/.rvm/scripts/rvm"

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

  # Load PYENV if you are using it
  if [[ -s ${HOME}/.pyenv ]]; then
    export PYENV_ROOT="${HOME}/.pyenv"
    export PATH="${PYENV_ROOT}/bin:${PATH}"
    eval "$(pyenv init -)"
  fi

  # Bat Defaults
  export BAT_THEME="OneDarkPro"

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

  export XAUTHORITY="${XDG_RUNTIME_DIR}/Xauthority"

  export _Z_DATA="${XDG_DATA_HOME}/z"

  # asdf config
  export ASDF_DATA_DIR="${XDG_DATA_HOME}/asdf"
  export ASDF_CONFIG_FILE="${XDG_CONFIG_HOME}/asdf/asdfrc"
  export ADSF_DEFAULT_TOOL_VERSIONS_FILENAME="${XDG_CONFIG_HOME}/asdf/tool-versions"
  export PATH="${ASDF_DATA_DIR}/shims:${PATH}"


  # make less more friendly for non-text input files, see lesspipe(1)
  if [ -x /usr/bin/lesspipe ]; then eval "$(SHELL=/bin/sh lesspipe)"; fi

  if command -v dircolors &>/dev/null; then
    if [[ -e "${XDG_CONFIG_HOME}/dircolors" ]]; then eval "$(dircolors "${XDG_CONFIG_HOME}/dircolors")"; fi
  fi

  # Less pager defaults & history hygiene
  export LESS="-R -F -X -i"
  export LESSHISTFILE="${XDG_STATE_HOME:-${HOME}/.local/state}/less/history"

  # Tool config paths
  export WGETRC="${XDG_CONFIG_HOME}/wgetrc"
  export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}/ripgrep/config"
  export GH_CONFIG_DIR="${XDG_CONFIG_HOME}/gh"

  if [[ -f "${NREDF_CONFIG}/GITHUB.AUTH" ]]; then
    eval "$(< "${NREDF_CONFIG}/GITHUB.AUTH")"
    if [[ -n ${NREDF_GITHUB_USERNAME} && -n ${NREDF_GITHUB_TOKEN} ]]; then
      export NREDF_CURL_GITHUB_AUTH="-u ${NREDF_GITHUB_USERNAME}:${NREDF_GITHUB_TOKEN}"
    fi
  fi
}
