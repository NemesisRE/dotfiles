#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_set_ssh_agent_wsl() {
  # Get Windows username
  if ! command -v whoami.exe &>/dev/null; then
    printf "Error: whoami.exe not found in PATH. Please ensure it is available.\n"
    return 1
  fi
  WINDOWS_USER=$(whoami.exe | sed 's/.*\\//' | tr -d '\r\n')

  # Construct the npiperelay path
  NPIPERELAY_DEFAULT_PATH="/mnt/c/Users/${WINDOWS_USER}/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe/npiperelay.exe"
  NPIPERELAY="${NPIPERELAY_PATH:-$NPIPERELAY_DEFAULT_PATH}"

  # Try to auto-detect npiperelay.exe via Windows 'where' and convert to WSL path if default is not executable
  if [[ ! -x "${NPIPERELAY}" ]] && command -v where.exe &>/dev/null && command -v wslpath &>/dev/null; then
    win_npiperelay=$(cmd.exe /c "where.exe npiperelay.exe" 2>/dev/null | tr -d '\r' | head -n1)
    if [[ -n "${win_npiperelay}" ]]; then
      npiperelay_unix=$(wslpath -u "${win_npiperelay}" 2>/dev/null)
      if [[ -n "${npiperelay_unix}" ]]; then
        NPIPERELAY="${NPIPERELAY_PATH:-$npiperelay_unix}"
      fi
    else
      printf "Error: npiperelay.exe is not executable\n"
      printf "       Please ensure that npiperelay.exe is installed and accessible e.g.:\n"
      printf "       \e[3mwinget install albertony.npiperelay\e[23m\n"
      return 1
    fi
  fi

  if command -v setsid &>/dev/null && command -v socat &>/dev/null; then
    # Kill previous socat process if PID file exists
    SOCAT_PID_FILE="${HOME}/.ssh/socat_npiperelay.pid"
    if [[ -f "${SOCAT_PID_FILE}" ]]; then
      old_pid=$(<"${SOCAT_PID_FILE}")
      if kill -0 "${old_pid}" &>/dev/null; then
        kill "${old_pid}" &>/dev/null
      fi
      rm -f "${SOCAT_PID_FILE}"
    fi
    # Start new socat process, then record its PID reliably
    ( setsid socat UNIX-LISTEN:"${SSH_AUTH_SOCK}",fork EXEC:"${NPIPERELAY} -ei -s //./pipe/openssh-ssh-agent",nofork &>/dev/null & )
    # Give socat a brief moment to start, then capture the pid
    sleep 0.1
    new_pid=$(pgrep -f "socat UNIX-LISTEN:${SSH_AUTH_SOCK}" | head -n1)
    if [[ -n "${new_pid}" ]]; then
      echo "${new_pid}" > "${SOCAT_PID_FILE}"
    fi
  else
    printf "Warning: 'setsid' or 'socat' not found; SSH agent bridging not started.\n"
  fi
}

function _nredf_set_ssh_agent_bitwarden() {
  local candidates=()

  if [[ "${NREDF_OS:-}" == "macos" ]]; then
    candidates+=(
      "${HOME}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
      "${HOME}/.bitwarden-ssh-agent.sock"
    )
  else
    candidates+=(
      "${HOME}/.bitwarden-ssh-agent.sock"
      "${HOME}/snap/bitwarden/current/.bitwarden-ssh-agent.sock"
      "${HOME}/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
    )
  fi

  for sock in "${candidates[@]}"; do
    if [[ -S "${sock}" ]]; then
      if command -v ssh-add &>/dev/null; then
        SSH_AUTH_SOCK="${sock}" ssh-add -l &>/dev/null
        local rc=$?
        if [[ $rc -eq 0 || $rc -eq 1 ]]; then
          export SSH_AUTH_SOCK="${sock}"
          return 0
        fi
      else
        export SSH_AUTH_SOCK="${sock}"
        return 0
      fi
    fi
  done
}

function _nredf_set_ssh_agent_gpg() {
  if command -v gpgconf &>/dev/null; then
    # Only set SSH_AUTH_SOCK if not in an SSH session and this shell did not already set it (gnupg_SSH_AUTH_SOCK_by tracks the PID that set the socket)
    if [[ -z "${SSH_CONNECTION}" && "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]]; then
      unset SSH_AGENT_PID
      SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
      export SSH_AUTH_SOCK
      export gnupg_SSH_AUTH_SOCK_by=$$
    fi
  fi
}

function _nredf_ssh_agent_socket_works() {
  local sock="${1:-${SSH_AUTH_SOCK:-}}"

  if [[ -z "${sock}" || ! -S "${sock}" ]]; then
    return 1
  fi

  if command -v ssh-add &>/dev/null; then
    SSH_AUTH_SOCK="${sock}" ssh-add -l &>/dev/null
    local rc=$?
    [[ ${rc} -eq 0 || ${rc} -eq 1 ]]
    return $?
  fi

  return 0
}

function _nredf_set_ssh_agent() {
  local prefer_external_provider

  prefer_external_provider="false"

  if [[ "${NREDF_AGENT_PIPE:-}" == "true" || "${NREDF_AGENT_GPG:-}" == "true" || "${NREDF_AGENT_BITWARDEN:-}" == "true" ]]; then
    prefer_external_provider="true"
  fi

  # Do not override a forwarded SSH agent
  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    return 0
  fi

  # With explicit external provider preference, try configured providers first
  # and fallback to the current agent only if all preferred providers fail.
  if [[ "${prefer_external_provider}" == "true" ]]; then
    if [[ "${NREDF_AGENT_PIPE:-}" == "true" ]] && [[ -n "${WSL_DISTRO_NAME}" || -n "${WSL_INTEROP}" ]]; then
      export SSH_AUTH_SOCK="${HOME}/.ssh/auth_sock"
      _nredf_set_ssh_agent_wsl
      _nredf_ssh_agent_socket_works "${SSH_AUTH_SOCK}" && return 0
    fi

    if [[ "${NREDF_AGENT_GPG:-}" == "true" ]]; then
      _nredf_set_ssh_agent_gpg
      _nredf_ssh_agent_socket_works "${SSH_AUTH_SOCK}" && return 0
    fi

    if [[ "${NREDF_AGENT_BITWARDEN:-}" == "true" ]]; then
      _nredf_set_ssh_agent_bitwarden
      _nredf_ssh_agent_socket_works "${SSH_AUTH_SOCK}" && return 0
    fi

    if _nredf_ssh_agent_socket_works "${SSH_AUTH_SOCK:-}"; then
      return 0
    fi
  else
    # Keep current agent if it is working
    if _nredf_ssh_agent_socket_works "${SSH_AUTH_SOCK:-}"; then
      return 0
    fi
  fi

  # Ensure socket directory exists
  if [[ ! -d "${HOME}/.ssh" ]]; then
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
  fi

  # Check if socket exists and is working
  local auth_sock="${HOME}/.ssh/auth_sock"
  if _nredf_ssh_agent_socket_works "${auth_sock}"; then
    export SSH_AUTH_SOCK="${auth_sock}"
    return 0
  fi

  # Remove stale socket before starting new agent
  rm -f "${auth_sock}"

  if [[ "${NREDF_AGENT_PIPE:-}" == "true" ]] && [[ -n "${WSL_DISTRO_NAME}" || -n "${WSL_INTEROP}" ]]; then
    export SSH_AUTH_SOCK="${auth_sock}"
    if ! _nredf_set_ssh_agent_wsl; then
      printf "Error: Failed to set up WSL SSH agent bridge\n" >&2
      return 1
    fi
  elif [[ "${NREDF_AGENT_GPG:-}" == "true" ]]; then
    _nredf_set_ssh_agent_gpg
  elif [[ "${NREDF_AGENT_BITWARDEN:-}" == "true" ]]; then
    _nredf_set_ssh_agent_bitwarden
  else
    export SSH_AUTH_SOCK="${auth_sock}"
    if command -v ssh-agent &>/dev/null; then
      unset SSH_AGENT_PID
      eval "$(ssh-agent -s -a "${SSH_AUTH_SOCK}")" >/dev/null
    else
      printf "Warning: 'ssh-agent' not found; no SSH agent could be started.\n" >&2
      return 1
    fi
  fi

  # Verify the agent is actually working
  if [[ -S "${SSH_AUTH_SOCK}" ]] && command -v ssh-add &>/dev/null; then
    # Check if agent is responding (accept both 0 and 1 as valid)
    ssh-add -l &>/dev/null
    local exit_code=$?

    if [[ ${exit_code} -eq 0 ]]; then
      return 0
    elif [[ ${exit_code} -eq 1 ]]; then
      echo -e "\033[1;33mAdd your SSH key(s) to the agent with 'ssh-add'\033[0m"
      return 0
    elif [[ ${exit_code} -gt 1 ]]; then
      printf "Warning: SSH agent socket exists but agent is not responding\n" >&2
      return 1
    fi
  fi
}
