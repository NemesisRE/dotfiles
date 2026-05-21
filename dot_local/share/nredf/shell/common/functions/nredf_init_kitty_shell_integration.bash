#!/usr/bin/env bash
# chezmoi-managed: kitty shell integration bootstrap for bash and zsh

function _nredf_init_kitty_shell_integration() {
  local force_init="${1:-}"

  if [[ "${force_init}" != "--force" && "${NREDF_KITTY_SHELL_INTEGRATION_DONE:-0}" == "1" ]]; then
    return 0
  fi

  local _nredf_kitty_dir="${KITTY_INSTALLATION_DIR:-}"
  [[ -n "${_nredf_kitty_dir}" ]] || return 0

  local _nredf_kitty_mode="${KITTY_SHELL_INTEGRATION:-${NREDF_KITTY_SHELL_INTEGRATION_MODE:-enabled}}"
  case " ${_nredf_kitty_mode} " in
  *" disabled "*) return 0 ;;
  esac

  _nredf_kitty_mode="${_nredf_kitty_mode//no-rc/}"
  _nredf_kitty_mode="${_nredf_kitty_mode#"${_nredf_kitty_mode%%[![:space:]]*}"}"
  _nredf_kitty_mode="${_nredf_kitty_mode%"${_nredf_kitty_mode##*[![:space:]]}"}"
  [[ -n "${_nredf_kitty_mode}" ]] || _nredf_kitty_mode="enabled"

  export NREDF_KITTY_SHELL_INTEGRATION_MODE="${_nredf_kitty_mode}"

  case "${NREDF_SHELL_NAME:-}" in
  bash)
    local _nredf_kitty_bash="${_nredf_kitty_dir}/shell-integration/bash/kitty.bash"
    if [[ -f "${_nredf_kitty_bash}" ]]; then
      export KITTY_SHELL_INTEGRATION="${_nredf_kitty_mode}"
      # shellcheck disable=SC1090
      source "${_nredf_kitty_bash}"
      NREDF_KITTY_SHELL_INTEGRATION_DONE=1
      _nredf_step "kitty integration"
    fi
    unset _nredf_kitty_bash
    ;;
  zsh)
    local _nredf_kitty_zsh="${_nredf_kitty_dir}/shell-integration/zsh/kitty-integration"
    if [[ -f "${_nredf_kitty_zsh}" ]]; then
      export KITTY_SHELL_INTEGRATION="${_nredf_kitty_mode}"
      autoload -Uz -- "${_nredf_kitty_zsh}"
      kitty-integration
      unfunction kitty-integration 2>/dev/null || true
      NREDF_KITTY_SHELL_INTEGRATION_DONE=1
      _nredf_step "kitty integration"
    fi
    unset _nredf_kitty_zsh
    ;;
  esac

  unset _nredf_kitty_dir _nredf_kitty_mode
}
