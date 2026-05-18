#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_remote_multiplexer() {
  local HOSTNAME
  if command -pv hostname &>/dev/null; then
    HOSTNAME=$(hostname -s)
  elif command -pv hostnamectl &>/dev/null; then
    HOSTNAME=$(hostnamectl hostname)
  fi

  if [[ -z ${NREDF_CONFIGS["Multiplexer"]} || "${NREDF_CONFIGS["Multiplexer"]}" == "false" ]]; then
    return 0
  fi

  if [[ "${TERM_PROGRAM}" != "vscode" ]]; then
    if [[ -n "${SSH_TTY}" || -n "${WSL_DISTRO_NAME}" ]] && command -v zellij &>/dev/null; then
      if [[ -z "${ZELLIJ}" ]]; then
        echo -e "\033[1mStarting multiplexer\033[0m"
        zellij attach -c "${HOSTNAME}"
      fi
    elif [[ "${NREDF_OS}" == "linux" ]] && [[ -n "${SSH_TTY}" ]] && [[ "${PS1}" != "" ]] && command -pv tmux &>/dev/null; then
      if [[ -z "${TMUX}" ]]; then
        # Start tmux on connection
        if [[ "$(tmux -L "${HOSTNAME}" has-session -t "${HOSTNAME}" &>/dev/null; echo $?)" = 0 ]]; then
          echo -e '\033[1mAttach to running tmux session\033[0m'
          tmux -L "${HOSTNAME}" attach-session -t "${HOSTNAME}"
        elif [[ "$(which tmux 2>/dev/null)" != "" ]] && [[ "${TMUX}" = "" ]]; then
          echo -e '\033[1mStart new tmux session\033[0m'
          tmux -L "${HOSTNAME}" new-session -s "${HOSTNAME}"
        fi
      fi
    fi
  fi
}
