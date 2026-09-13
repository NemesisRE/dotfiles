#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_remote_multiplexer() {
  local multiplexer_enabled="${NREDF_SHELL_MULTIPLEXER:-${NREDF_SHELL_GENERELL_MULTIPLEXER:-}}"
  if [[ -z "${multiplexer_enabled:-}" || "${multiplexer_enabled}" == "false" ]]; then
    return 0
  fi

  if [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
    return 0
  fi

  local host_name="${HOSTNAME:-${HOST%%.*}}"
  if [[ -z "${host_name}" ]]; then
    if command -v hostname &>/dev/null; then
      host_name="$(hostname -s 2>/dev/null)"
    elif command -v hostnamectl &>/dev/null; then
      host_name="$(hostnamectl hostname 2>/dev/null)"
    fi
  fi

  if [[ -n "${SSH_TTY:-}" || -n "${WSL_DISTRO_NAME:-}" ]] && command -v zellij &>/dev/null; then
    if [[ -z "${ZELLIJ:-}" ]]; then
      printf '\033[1mStarting multiplexer\033[0m\n'
      zellij attach -c "${host_name}"
    fi
  elif [[ "${NREDF_OS:-}" == "linux" ]] && [[ -n "${SSH_TTY:-}" ]] && [[ -n "${PS1:-}" ]] && command -v tmux &>/dev/null; then
    if [[ -z "${TMUX:-}" ]]; then
      # Start tmux on connection
      if tmux -L "${host_name}" has-session -t "${host_name}" &>/dev/null; then
        printf '\033[1mAttach to running tmux session\033[0m\n'
        tmux -L "${host_name}" attach-session -t "${host_name}"
      elif command -v tmux &>/dev/null && [[ -z "${TMUX:-}" ]]; then
        printf '\033[1mStart new tmux session\033[0m\n'
        tmux -L "${host_name}" new-session -s "${host_name}"
      fi
    fi
  fi
}

