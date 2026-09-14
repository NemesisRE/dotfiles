#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_remote_multiplexer() {
  if [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
    return 0
  fi

  # Never start multiplexer in non-interactive or background sessions
  if [[ ! -t 0 || ! -t 1 ]]; then
    return 0
  fi

  if ! command -v zellij &>/dev/null; then
    return 0
  fi

  if [[ -n "${ZELLIJ:-}" ]]; then
    return 0
  fi

  local is_ssh="false"
  if [[ -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" || -n "${SSH_CLIENT:-}" ]]; then
    is_ssh="true"
  fi

  local is_wsl="false"
  if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]]; then
    is_wsl="true"
  elif [[ -f /proc/version ]] && grep -qi "microsoft" /proc/version 2>/dev/null; then
    is_wsl="true"
  fi

  local should_start="false"

  if [[ "${is_ssh}" == "true" ]]; then
    local multiplexer_enabled="${NREDF_SHELL_MULTIPLEXER:-${NREDF_SHELL_GENERELL_MULTIPLEXER:-true}}"
    if [[ "${multiplexer_enabled}" != "false" && -n "${multiplexer_enabled}" ]]; then
      should_start="true"
    fi
  elif [[ "${is_wsl}" == "true" ]]; then
    local wsl_multiplexer="${NREDF_SHELL_WSL_MULTIPLEXER:-${NREDF_SHELL_MULTIPLEXER_WSL:-false}}"
    if [[ "${wsl_multiplexer}" == "true" || "${wsl_multiplexer}" == "1" || "${wsl_multiplexer}" == "yes" ]]; then
      should_start="true"
    fi
  fi

  if [[ "${should_start}" != "true" ]]; then
    return 0
  fi

  local host_name="${HOSTNAME:-}"
  if [[ -z "${host_name}" && -n "${HOST:-}" ]]; then
    host_name="${HOST%%.*}"
  fi
  if [[ -z "${host_name}" ]]; then
    if command -v hostname &>/dev/null; then
      host_name="$(hostname -s 2>/dev/null)"
    elif command -v hostnamectl &>/dev/null; then
      host_name="$(hostnamectl hostname 2>/dev/null)"
    fi
  fi

  printf '\033[1mStarting multiplexer (zellij)\033[0m\n'
  zellij attach -c "${host_name}"
}

