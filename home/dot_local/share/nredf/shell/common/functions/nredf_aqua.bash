#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_aqua_keyring_available() {
  case "${OSTYPE:-}" in
    darwin*) return 0 ;;
    msys*|cygwin*) return 0 ;;
  esac

  if [[ -n "${WINDIR:-}" || -n "${COMSPEC:-}" ]] && [[ -z "${WSL_DISTRO_NAME:-}" && -z "${WSL_INTEROP:-}" ]]; then
    return 0
  fi

  # Linux / Unix: aqua requires D-Bus secret service (org.freedesktop.secrets)
  local bus="${DBUS_SESSION_BUS_ADDRESS:-}"
  if [[ -z "${bus}" ]]; then
    local sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u 2>/dev/null)}/bus"
    if [[ -S "${sock}" ]]; then
      bus="unix:path=${sock}"
    else
      return 1
    fi
  fi

  # 1. Check with gdbus
  if command -v gdbus &>/dev/null; then
    if DBUS_SESSION_BUS_ADDRESS="${bus}" gdbus call --session \
      --dest org.freedesktop.secrets --object-path /org/freedesktop/secrets \
      --method org.freedesktop.DBus.Peer.Ping &>/dev/null; then
      return 0
    fi
    return 1
  fi

  # 2. Check with busctl
  if command -v busctl &>/dev/null; then
    if DBUS_SESSION_BUS_ADDRESS="${bus}" busctl --user call \
      org.freedesktop.secrets /org/freedesktop/secrets \
      org.freedesktop.DBus.Peer Ping &>/dev/null; then
      return 0
    fi
    return 1
  fi

  # 3. Check with dbus-send
  if command -v dbus-send &>/dev/null; then
    if DBUS_SESSION_BUS_ADDRESS="${bus}" dbus-send --session --dest=org.freedesktop.secrets \
      --type=method_call --print-reply /org/freedesktop/secrets \
      org.freedesktop.DBus.Peer.Ping &>/dev/null; then
      return 0
    fi
    return 1
  fi

  return 1
}

function _nredf_set_aqua_env() {
  local _nredf_aqua_base_config="${XDG_CONFIG_HOME}/aquaproj-aqua/aqua.yaml"
  local _nredf_aqua_machine_config="${XDG_CONFIG_HOME}/aquaproj-aqua/machine.yaml"
  local _nredf_aqua_policy_config="${XDG_CONFIG_HOME}/aquaproj-aqua/aqua-policy.yaml"
  local _nredf_aqua_auth_config="${NREDF_CONFIG:-${XDG_CONFIG_HOME:-${HOME}/.config}/nredf}/aqua.env"

  if [[ -f "${_nredf_aqua_auth_config}" ]]; then
    # shellcheck disable=SC1090
    source "${_nredf_aqua_auth_config}"
  fi

  # If keyring is configured but unavailable on this system (e.g. headless/WSL),
  # deactivate AQUA_KEYRING_ENABLED to prevent aqua CLI errors.
  if [[ "${AQUA_KEYRING_ENABLED:-}" == "true" ]] && ! _nredf_aqua_keyring_available; then
    unset AQUA_KEYRING_ENABLED
  fi

  if [[ -f "${_nredf_aqua_base_config}" ]]; then
    export AQUA_CONFIG="${_nredf_aqua_base_config}"
    export AQUA_GLOBAL_CONFIG="${_nredf_aqua_base_config}"
    if [[ -f "${_nredf_aqua_machine_config}" ]]; then
      export AQUA_GLOBAL_CONFIG="${AQUA_GLOBAL_CONFIG}:${_nredf_aqua_machine_config}"
    fi
  fi

  if [[ -f "${_nredf_aqua_policy_config}" ]]; then
    export AQUA_POLICY_CONFIG="${_nredf_aqua_policy_config}"
  fi

  unset _nredf_aqua_base_config _nredf_aqua_machine_config _nredf_aqua_policy_config _nredf_aqua_auth_config
}

function _nredf_set_aqua_path() {
  local _nredf_aqua_bin="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/aquaproj-aqua}/bin"
  case ":${PATH}:" in
  *":${_nredf_aqua_bin}:"*) ;;
  *) export PATH="${_nredf_aqua_bin}:${PATH}" ;;
  esac
  unset _nredf_aqua_bin
}

function _nredf_aqua_auth_config_file() {
  local _nredf_config_dir="${NREDF_CONFIG:-${XDG_CONFIG_HOME:-${HOME}/.config}/nredf}"

  printf "%s/aqua.env" "${_nredf_config_dir}"
  unset _nredf_config_dir
}

function _nredf_write_aqua_auth_config() {
  local _nredf_mode="${1:-}"
  local _nredf_token="${2:-}"
  local _nredf_auth_file=""
  local _nredf_auth_dir=""
  local _nredf_tmp_file=""

  if [[ -z "${_nredf_mode}" ]]; then
    echo "missing aqua auth mode" >&2
    return 1
  fi

  _nredf_auth_file="$(_nredf_aqua_auth_config_file)"
  _nredf_auth_dir="${_nredf_auth_file%/*}"
  mkdir -p "${_nredf_auth_dir}"
  _nredf_tmp_file="$(mktemp "${_nredf_auth_dir}/aqua.env.XXXXXX")"

  {
    printf "# Local aqua GitHub auth preferences\n"
    printf "NREDF_AQUA_GITHUB_TOKEN_SETUP=%q\n" "${_nredf_mode}"
    if [[ "${_nredf_mode}" == "keyring" ]]; then
      printf "AQUA_KEYRING_ENABLED=%q\n" "true"
    elif [[ "${_nredf_mode}" == "env" && -n "${_nredf_token}" ]]; then
      printf "export AQUA_GITHUB_TOKEN=%q\n" "${_nredf_token}"
      printf "export GITHUB_TOKEN=%q\n" "${_nredf_token}"
    fi
  } > "${_nredf_tmp_file}"

  chmod 600 "${_nredf_tmp_file}"
  mv "${_nredf_tmp_file}" "${_nredf_auth_file}"

  unset _nredf_mode _nredf_token _nredf_auth_file _nredf_auth_dir _nredf_tmp_file
}

function _nredf_clear_aqua_auth_config() {
  local _nredf_auth_file=""

  _nredf_auth_file="$(_nredf_aqua_auth_config_file)"
  rm -f "${_nredf_auth_file}"
  unset AQUA_KEYRING_ENABLED NREDF_AQUA_GITHUB_TOKEN_SETUP AQUA_GITHUB_TOKEN GITHUB_TOKEN
  unset _nredf_auth_file
}

# Returns 0 = yes, 1 = no, 2 = unanswered (no usable terminal, EOF, or timeout).
# "Unanswered" must never be conflated with "no": callers record "no" as a
# permanent opt-out, which is wrong when nobody was there to be asked (a restored
# multiplexer pane, an IDE-spawned terminal). The timeout also stops such a shell
# from blocking forever on a prompt no one will see.
function _nredf_prompt_yes_no() {
  local _nredf_prompt="$1"
  local _nredf_reply=""

  if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
    return 2
  fi

  while true; do
    printf "%s [y/N]: " "${_nredf_prompt}" > /dev/tty
    if ! IFS= read -r -t "${NREDF_PROMPT_TIMEOUT:-30}" _nredf_reply < /dev/tty; then
      printf "\n" > /dev/tty
      return 2
    fi
    case "${_nredf_reply}" in
      y|Y|yes|YES)
        return 0
        ;;
      n|N|no|NO|'')
        return 1
        ;;
    esac
    printf "Please answer yes or no.\n" > /dev/tty
  done
}

function nredf_aqua_token_setup() {
  local _nredf_action="${1:---set}"

  _nredf_init_paths

  case "${_nredf_action}" in
    --keyring)
      if ! command -v aqua &>/dev/null; then
        echo "aqua is not installed." >&2
        return 1
      fi
      if ! _nredf_aqua_keyring_available; then
        echo "System keyring (org.freedesktop.secrets) is not available on this system." >&2
        echo "Use 'nredf_aqua_token_setup --env' to store the token in local aqua.env instead." >&2
        return 1
      fi
      if ! aqua token set; then
        return 1
      fi
      _nredf_write_aqua_auth_config "keyring"
      export AQUA_KEYRING_ENABLED="true"
      export NREDF_AQUA_GITHUB_TOKEN_SETUP="keyring"
      echo "Stored aqua's GitHub token in the system keyring."
      ;;
    --env)
      local _token=""
      if [[ -r /dev/tty && -w /dev/tty ]]; then
        printf "Enter a GitHub access token: " > /dev/tty
        IFS= read -r -s _token < /dev/tty
        printf "\n" > /dev/tty
      else
        printf "Enter a GitHub access token: "
        IFS= read -r -s _token
        printf "\n"
      fi

      if [[ -z "${_token}" ]]; then
        echo "Error: Token cannot be empty." >&2
        return 1
      fi

      _nredf_write_aqua_auth_config "env" "${_token}"
      export AQUA_GITHUB_TOKEN="${_token}"
      export GITHUB_TOKEN="${_token}"
      export NREDF_AQUA_GITHUB_TOKEN_SETUP="env"
      unset AQUA_KEYRING_ENABLED
      local _auth_file
      _auth_file="$(_nredf_aqua_auth_config_file)"
      echo "Stored aqua's GitHub token in ${_auth_file} (mode 0600)."
      ;;
    --set)
      if _nredf_aqua_keyring_available; then
        if nredf_aqua_token_setup --keyring; then
          return 0
        fi
        echo "Keyring setup failed. Falling back to file-based token storage..."
      fi
      nredf_aqua_token_setup --env
      ;;
    --skip)
      _nredf_write_aqua_auth_config "skip"
      unset AQUA_KEYRING_ENABLED
      export NREDF_AQUA_GITHUB_TOKEN_SETUP="skip"
      echo "Skipping aqua GitHub token setup for now."
      ;;
    --reset)
      _nredf_clear_aqua_auth_config
      echo "Reset aqua GitHub token preference."
      ;;
    --status)
      local _auth_file
      _auth_file="$(_nredf_aqua_auth_config_file)"
      echo "=== aqua GitHub Token Status ==="
      if [[ -n "${AQUA_GITHUB_TOKEN:-}" ]]; then
        echo "AQUA_GITHUB_TOKEN: set (length: ${#AQUA_GITHUB_TOKEN})"
      else
        echo "AQUA_GITHUB_TOKEN: unset"
      fi
      if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        echo "GITHUB_TOKEN:      set (length: ${#GITHUB_TOKEN})"
      else
        echo "GITHUB_TOKEN:      unset"
      fi
      echo "AQUA_KEYRING_ENABLED: ${AQUA_KEYRING_ENABLED:-unset}"
      echo "Setup state:          ${NREDF_AQUA_GITHUB_TOKEN_SETUP:-unset}"
      echo "Auth config file:     ${_auth_file} $([[ -f "${_auth_file}" ]] && echo "[exists]" || echo "[missing]")"
      if _nredf_aqua_keyring_available; then
        echo "System keyring:       available"
      else
        echo "System keyring:       unavailable (headless / WSL / no secret service)"
      fi
      ;;
    *)
      echo "Usage: nredf_aqua_token_setup [--set|--keyring|--env|--skip|--reset|--status]" >&2
      return 1
      ;;
  esac
}

function _nredf_ensure_aqua_github_token() {
  local _nredf_setup_state="${NREDF_AQUA_GITHUB_TOKEN_SETUP:-}"
  local _nredf_auth_file=""

  case "$-" in
    *i*) ;;
    *) return 0 ;;
  esac

  # Interactive, but with nothing to ask on: do nothing (and record nothing).
  if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
    return 0
  fi

  if ! command -v aqua &>/dev/null; then
    return 0
  fi

  if [[ -n "${AQUA_GITHUB_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
    return 0
  fi

  if [[ "${AQUA_KEYRING_ENABLED:-}" == "true" || "${_nredf_setup_state}" == "keyring" ]]; then
    if _nredf_aqua_keyring_available; then
      export AQUA_KEYRING_ENABLED="true"
      return 0
    fi
    unset AQUA_KEYRING_ENABLED
  fi

  _nredf_auth_file="$(_nredf_aqua_auth_config_file)"
  if [[ -z "${_nredf_setup_state}" && -f "${_nredf_auth_file}" ]]; then
    # shellcheck disable=SC1090
    source "${_nredf_auth_file}"
    _nredf_setup_state="${NREDF_AQUA_GITHUB_TOKEN_SETUP:-}"
  fi

  if [[ -n "${AQUA_GITHUB_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
    return 0
  fi

  if [[ "${AQUA_KEYRING_ENABLED:-}" == "true" || "${_nredf_setup_state}" == "keyring" ]]; then
    if _nredf_aqua_keyring_available; then
      export AQUA_KEYRING_ENABLED="true"
      return 0
    fi
    unset AQUA_KEYRING_ENABLED
  fi

  if [[ "${_nredf_setup_state}" == "skip" ]]; then
    return 0
  fi

  if _nredf_aqua_keyring_available; then
    _nredf_prompt_yes_no "No GitHub token configured for aqua. Store one in the system keyring now?"
    case $? in
      0) ;;
      1)
        nredf_aqua_token_setup --skip >/dev/null
        printf "Run 'nredf_aqua_token_setup' later to configure aqua's GitHub token.\n" > /dev/tty
        return 0
        ;;
      *) return 0 ;; # unanswered: ask again in a later shell
    esac

    if ! nredf_aqua_token_setup --keyring; then
      _nredf_prompt_yes_no "Keyring setup failed. Store token in ${_nredf_auth_file} (mode 0600) instead?"
      case $? in
        0) nredf_aqua_token_setup --env ;;
        1)
          nredf_aqua_token_setup --skip >/dev/null
          printf "Skipping aqua GitHub token setup for now.\n" > /dev/tty
          ;;
        *) ;; # unanswered: ask again in a later shell
      esac
    fi
  else
    printf "\033[1;33mNo GitHub token configured for aqua (system keyring unavailable on this system).\033[0m\n" > /dev/tty
    _nredf_prompt_yes_no "Store token in ${_nredf_auth_file} (mode 0600) now?"
    case $? in
      0) nredf_aqua_token_setup --env ;;
      1)
        nredf_aqua_token_setup --skip >/dev/null
        printf "Skipping aqua GitHub token setup for now. Run 'nredf_aqua_token_setup' later to configure.\n" > /dev/tty
        ;;
      *) ;; # unanswered: ask again in a later shell
    esac
  fi

  return 0
}

function _nredf_aqua_vacuum() {
  local _nredf_vacuum_days="${NREDF_SHELL_AQUA_VACUUM_DAYS:-30}"

  if _nredf_last_run; then
    return 0
  elif ! _nredf_create_lock; then
    return 0
  fi

  if [[ ! "${_nredf_vacuum_days}" =~ ^[0-9]+$ ]]; then
    _nredf_vacuum_days="30"
  fi

  if ! command -v aqua &>/dev/null; then
    _nredf_remove_lock
    return 0
  fi

  if [[ -n "${NREDF_PROFILE_STARTUP:-}" || -n "${NREDF_VERBOSE:-}" ]]; then
    echo -e '\033[1mVacuuming aqua packages\033[0m'
  fi
  if aqua vacuum -d "${_nredf_vacuum_days}" >/dev/null 2>&1; then
    _nredf_last_run "" "true" "${NREDF_24H_INTERVAL:-86400}"
  fi
  _nredf_remove_lock
}

function _nredf_aqua_update() {
  if _nredf_last_run; then
    return 0
  elif ! _nredf_create_lock; then
    return 0
  fi

  if ! command -v aqua &>/dev/null; then
    _nredf_remove_lock
    return 0
  fi

  if [[ -n "${NREDF_PROFILE_STARTUP:-}" || -n "${NREDF_VERBOSE:-}" ]]; then
    echo -e '\033[1mUpdating aqua\033[0m'
  fi
  if aqua update-aqua >/dev/null 2>&1; then
    _nredf_last_run "" "true" "${NREDF_24H_INTERVAL:-86400}"
  fi
  _nredf_remove_lock
}
