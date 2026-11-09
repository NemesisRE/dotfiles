#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
#
# Picks the SSH agent for this shell and exports SSH_AUTH_SOCK.
#
# shell.ssh.agent (NREDF_SHELL_SSH_AGENT):
#   default                 keep a working agent, else auto-detect
#                           1Password -> Bitwarden -> systemd/gcr/keyring -> own ssh-agent
#   1password|onepassword   force the 1Password agent
#   bitwarden               force the Bitwarden agent
#   system                  force the systemd/gcr/keyring agent
#   gpg                     use gpg-agent's SSH socket
#   pipe                    WSL only: bridge the Windows OpenSSH agent via socat + npiperelay
#
# Everything here must be safe under `set -u`, silent on stdout, and must never
# block or prompt at shell startup (agent probes run under a timeout).

# Health check for an agent socket. ssh-add -l exits 0 (keys) or 1 (no keys) for
# a live agent; anything else (2 = unreachable, 124 = timed out) is a dead one.
function _nredf_ssh_agent_socket_works() {
  local sock="${1:-}" rc

  [[ -n "${sock}" && -S "${sock}" ]] || return 1
  command -v ssh-add &>/dev/null || return 0

  # A locked 1Password/Bitwarden agent can stall; never hang the shell on it.
  if command -v timeout &>/dev/null; then
    SSH_AUTH_SOCK="${sock}" timeout 2 ssh-add -l &>/dev/null
  elif command -v gtimeout &>/dev/null; then
    SSH_AUTH_SOCK="${sock}" gtimeout 2 ssh-add -l &>/dev/null
  else
    SSH_AUTH_SOCK="${sock}" ssh-add -l &>/dev/null
  fi
  rc=$?
  [[ ${rc} -eq 0 || ${rc} -eq 1 ]]
}

# Export the first candidate socket that answers.
function _nredf_ssh_agent_try_sockets() {
  local sock
  for sock in "$@"; do
    if _nredf_ssh_agent_socket_works "${sock}"; then
      export SSH_AUTH_SOCK="${sock}"
      return 0
    fi
  done
  return 1
}

function _nredf_ssh_agent_is_macos() {
  [[ "${NREDF_OS:-}" == "macos" || "${OSTYPE:-}" == darwin* ]]
}

function _nredf_ssh_agent_is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]]
}

function _nredf_set_ssh_agent_1password() {
  if _nredf_ssh_agent_is_macos; then
    _nredf_ssh_agent_try_sockets \
      "${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  else
    _nredf_ssh_agent_try_sockets \
      "${HOME}/.1password/agent.sock" \
      "${HOME}/.config/1Password/agent.sock"
  fi
}

function _nredf_set_ssh_agent_bitwarden() {
  if _nredf_ssh_agent_is_macos; then
    _nredf_ssh_agent_try_sockets \
      "${HOME}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock" \
      "${HOME}/.bitwarden-ssh-agent.sock"
  else
    _nredf_ssh_agent_try_sockets \
      "${HOME}/.bitwarden-ssh-agent.sock" \
      "${HOME}/snap/bitwarden/current/.bitwarden-ssh-agent.sock" \
      "${HOME}/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
  fi
}

function _nredf_set_ssh_agent_system() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/${UID}}"
  _nredf_ssh_agent_try_sockets \
    "${runtime_dir}/ssh-agent.socket" \
    "${runtime_dir}/gcr/ssh" \
    "${runtime_dir}/keyring/ssh"
}

function _nredf_set_ssh_agent_gpg() {
  local sock

  command -v gpgconf &>/dev/null || return 1
  sock="$(gpgconf --list-dirs agent-ssh-socket 2>/dev/null)" || return 1
  [[ -n "${sock}" ]] || return 1

  # The socket only exists once gpg-agent runs (and has enable-ssh-support).
  if [[ ! -S "${sock}" ]]; then
    gpgconf --launch gpg-agent &>/dev/null
  fi

  unset SSH_AGENT_PID
  _nredf_ssh_agent_try_sockets "${sock}"
}

# Resolve the Windows-side npiperelay.exe and print its path.
function _nredf_ssh_agent_find_npiperelay() {
  local candidate win_user win_path

  # 1. Explicit user override
  if [[ -n "${NPIPERELAY_PATH:-}" ]]; then
    if [[ -x "${NPIPERELAY_PATH}" ]]; then
      printf '%s' "${NPIPERELAY_PATH}"
      return 0
    fi
  fi

  # 2. Default winget location
  if command -v whoami.exe &>/dev/null; then
    win_user="$(whoami.exe 2>/dev/null | sed 's/.*\\//' | tr -d '\r\n')"
    candidate="/mnt/c/Users/${win_user}/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe/npiperelay.exe"
    if [[ -n "${win_user}" && -x "${candidate}" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
  fi

  # 3. Anything on the Windows PATH
  if command -v where.exe &>/dev/null && command -v wslpath &>/dev/null; then
    win_path="$(where.exe npiperelay.exe 2>/dev/null | tr -d '\r' | head -n1)"
    if [[ -n "${win_path}" ]]; then
      candidate="$(wslpath -u "${win_path}" 2>/dev/null)"
      if [[ -n "${candidate}" && -x "${candidate}" ]]; then
        printf '%s' "${candidate}"
        return 0
      fi
    fi
  fi

  return 1
}

# Bridge the Windows OpenSSH agent pipe to a unix socket with socat.
function _nredf_ssh_agent_start_wsl_bridge() {
  local sock="${1}" npiperelay pid_file old_pid i

  if ! command -v setsid &>/dev/null || ! command -v socat &>/dev/null; then
    printf "Warning: 'setsid' or 'socat' not found; SSH agent bridging not started.\n" >&2
    return 1
  fi

  if ! npiperelay="$(_nredf_ssh_agent_find_npiperelay)"; then
    printf "Error: npiperelay.exe not found\n" >&2
    printf "       Install it e.g.: \033[3mwinget install albertony.npiperelay\033[23m\n" >&2
    printf "       or point NPIPERELAY_PATH at it.\n" >&2
    return 1
  fi

  pid_file="${HOME}/.ssh/socat_npiperelay.pid"
  if [[ -f "${pid_file}" ]]; then
    old_pid="$(<"${pid_file}")"
    # Only kill it if the PID still belongs to a socat (PIDs get recycled).
    if [[ "${old_pid}" =~ ^[0-9]+$ && -r "/proc/${old_pid}/comm" && "$(<"/proc/${old_pid}/comm")" == socat ]]; then
      kill "${old_pid}" &>/dev/null
    fi
    rm -f "${pid_file}"
  fi

  # The subshell keeps job-control noise out of interactive shells; unlink-early
  # lets socat replace a stale socket file itself.
  (
    setsid socat "UNIX-LISTEN:${sock},fork,unlink-early" \
      "EXEC:${npiperelay} -ei -s //./pipe/openssh-ssh-agent,nofork" \
      </dev/null &>/dev/null &
    printf '%s\n' "$!" >"${pid_file}"
  )

  # Wait (max ~1s) for the listener to appear.
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [[ -S "${sock}" ]] && return 0
    sleep 0.1
  done
  return 1
}

# Start our own ssh-agent on a fixed socket. Several shells may start at once
# (terminal restore, multiplexer panes), so a mkdir lock serialises them and
# whoever loses the race just uses the winner's agent.
function _nredf_ssh_agent_start_own() {
  local sock="${1}" lock="${HOME}/.ssh/auth_sock.lock" i rc=1 agent_env

  if ! command -v ssh-agent &>/dev/null; then
    printf "Warning: 'ssh-agent' not found; no SSH agent could be started.\n" >&2
    return 1
  fi

  for i in $(seq 1 30); do
    if mkdir "${lock}" 2>/dev/null; then
      break
    fi
    # Another shell holds the lock: its agent may be up by now.
    if _nredf_ssh_agent_socket_works "${sock}"; then
      export SSH_AUTH_SOCK="${sock}"
      return 0
    fi
    sleep 0.1
    # Stale lock (shell killed mid-start): take it over after ~3s.
    if [[ ${i} -eq 30 ]]; then
      rmdir "${lock}" 2>/dev/null
      mkdir "${lock}" 2>/dev/null || return 1
    fi
  done

  # Re-check under the lock; someone may have finished in the meantime.
  if _nredf_ssh_agent_socket_works "${sock}"; then
    rc=0
  else
    rm -f "${sock}"
    unset SSH_AGENT_PID
    agent_env="$(ssh-agent -s -a "${sock}")"
    # ssh-agent prints nothing usable on failure, and eval of "" succeeds.
    if [[ -n "${agent_env}" ]]; then
      eval "${agent_env}" >/dev/null
      _nredf_ssh_agent_socket_works "${sock}" && rc=0
    fi
  fi
  rmdir "${lock}" 2>/dev/null

  if [[ ${rc} -eq 0 ]]; then
    export SSH_AUTH_SOCK="${sock}"
    if [[ -n "${NREDF_PROFILE_STARTUP:-}" ]] && command -v ssh-add &>/dev/null; then
      SSH_AUTH_SOCK="${sock}" ssh-add -l &>/dev/null
      if [[ $? -eq 1 ]]; then
        printf "\033[1;33mAdd your SSH key(s) to the agent with 'ssh-add'\033[0m\n" >&2
      fi
    fi
  else
    printf "Warning: could not start ssh-agent on %s\n" "${sock}" >&2
  fi
  return ${rc}
}

# Try exactly one named provider.
function _nredf_ssh_agent_use_provider() {
  case "${1}" in
    1password) _nredf_set_ssh_agent_1password ;;
    bitwarden) _nredf_set_ssh_agent_bitwarden ;;
    system) _nredf_set_ssh_agent_system ;;
    gpg) _nredf_set_ssh_agent_gpg ;;
    pipe)
      _nredf_ssh_agent_is_wsl || return 1
      local sock="${HOME}/.ssh/auth_sock"
      if _nredf_ssh_agent_socket_works "${sock}"; then
        export SSH_AUTH_SOCK="${sock}"
        return 0
      fi
      _nredf_ssh_agent_prepare_dir
      _nredf_ssh_agent_start_wsl_bridge "${sock}" || return 1
      _nredf_ssh_agent_try_sockets "${sock}"
      ;;
    *) return 1 ;;
  esac
}

function _nredf_ssh_agent_prepare_dir() {
  [[ -d "${HOME}/.ssh" ]] || (umask 077 && mkdir -p "${HOME}/.ssh")
}

function _nredf_set_ssh_agent() {
  local mode="${NREDF_SHELL_SSH_AGENT:-default}"
  local auth_sock="${HOME}/.ssh/auth_sock"
  local launchd_sock

  [[ "${mode}" == "onepassword" ]] && mode="1password"

  # Never override a forwarded agent.
  [[ -z "${SSH_CONNECTION:-}" ]] || return 0

  if [[ "${mode}" != "default" ]]; then
    # Explicit provider: it wins; otherwise fall back to whatever already works.
    _nredf_ssh_agent_use_provider "${mode}" && return 0
    _nredf_ssh_agent_socket_works "${SSH_AUTH_SOCK:-}" && return 0
    return 1
  fi

  # default: keep a working agent. macOS launchd always provides its own
  # (usually empty) agent, which "works" and would shadow a running
  # 1Password/Bitwarden agent, so prefer those when available.
  if _nredf_ssh_agent_socket_works "${SSH_AUTH_SOCK:-}"; then
    if [[ "${SSH_AUTH_SOCK}" == */com.apple.launchd.*/Listeners ]]; then
      launchd_sock="${SSH_AUTH_SOCK}"
      if _nredf_set_ssh_agent_1password || _nredf_set_ssh_agent_bitwarden; then
        return 0
      fi
      export SSH_AUTH_SOCK="${launchd_sock}"
    fi
    return 0
  fi

  # Previously started own agent / bridge.
  if _nredf_ssh_agent_try_sockets "${auth_sock}"; then
    return 0
  fi

  # Running desktop/systemd agents beat spawning a new process.
  _nredf_set_ssh_agent_1password && return 0
  _nredf_set_ssh_agent_bitwarden && return 0
  _nredf_set_ssh_agent_system && return 0

  _nredf_ssh_agent_prepare_dir
  _nredf_ssh_agent_start_own "${auth_sock}"
}
