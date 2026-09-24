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

  # The D-Bus probe forks gdbus/busctl/dbus-send and can be reached several
  # times per shell start (_nredf_set_aqua_env runs from both
  # _nredf_set_defaults and rc, then _nredf_ensure_aqua_github_token), so
  # remember its answer for this shell. Deliberately not exported: a child
  # shell may run under a different session bus. nredf_aqua_token_setup
  # clears it so an explicit command always re-probes.
  if [[ -z "${_NREDF_AQUA_KEYRING_PROBED:-}" ]]; then
    _nredf_aqua_keyring_probe
    _NREDF_AQUA_KEYRING_PROBED=$?
  fi
  return "${_NREDF_AQUA_KEYRING_PROBED}"
}

function _nredf_aqua_keyring_probe() {
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

# Source a shared `[export] KEY='value'` env file (aqua-vault.env, aqua.env)
# with every assignment exported. fish/nu write AQUA_KEYRING_ENABLED=... without
# `export` (their readers always export), and a plain bash/zsh `source` of such
# a line never reaches the aqua child process. `set -a` covers files written by
# any shell without changing the shared format; a caller's own allexport
# setting is left as it was.
function _nredf_source_env_file() {
  local _nredf_env_file="${1:-}"
  local _nredf_had_allexport="false"

  [[ -n "${_nredf_env_file}" && -f "${_nredf_env_file}" ]] || return 0

  case "$-" in
    *a*) _nredf_had_allexport="true" ;;
  esac
  set -a
  source "${_nredf_env_file}"
  if [[ "${_nredf_had_allexport}" != "true" ]]; then
    set +a
  fi
  return 0
}

function _nredf_set_aqua_env() {
  local _nredf_aqua_base_config="${XDG_CONFIG_HOME}/aquaproj-aqua/aqua.yaml"
  local _nredf_aqua_machine_config="${XDG_CONFIG_HOME}/aquaproj-aqua/machine.yaml"
  local _nredf_aqua_policy_config="${XDG_CONFIG_HOME}/aquaproj-aqua/aqua-policy.yaml"
  local _nredf_aqua_config_dir="${NREDF_CONFIG:-${XDG_CONFIG_HOME:-${HOME}/.config}/nredf}"
  local _nredf_aqua_vault_config="${_nredf_aqua_config_dir}/aqua-vault.env"
  local _nredf_aqua_auth_config="${_nredf_aqua_config_dir}/aqua.env"

  # Vault-derived (chezmoi-managed) first, then the runtime-local one
  # (nredf_aqua_token_setup's --env mode) so it can override — two different
  # owners of two different files on purpose: chezmoi would otherwise delete
  # a manually-configured token on every apply whenever the vault lookup
  # comes back empty (confirmed empirically).
  _nredf_source_env_file "${_nredf_aqua_vault_config}"
  _nredf_source_env_file "${_nredf_aqua_auth_config}"

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

  unset _nredf_aqua_base_config _nredf_aqua_machine_config _nredf_aqua_policy_config _nredf_aqua_config_dir _nredf_aqua_vault_config _nredf_aqua_auth_config
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
  mkdir -p "${_nredf_auth_dir}" || return 1

  # The file can hold a GitHub token: create it 0600 from the start (umask in
  # a subshell, so the caller's umask is untouched) rather than chmod-ing it
  # after the token is already on disk.
  _nredf_tmp_file="$(umask 077; mktemp "${_nredf_auth_dir}/aqua.env.XXXXXX")" || return 1

  # AQUA_KEYRING_ENABLED stays un-exported in the file, matching the fish/nu
  # writers: the shell readers export it (bash/zsh via _nredf_source_env_file)
  # only after _nredf_set_aqua_env has checked the keyring is reachable, while
  # the run_onchange_after_aqua hook, which sources this file without that
  # check, keeps not handing it to aqua on a headless apply.
  if ! (
    umask 077
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
  ); then
    rm -f "${_nredf_tmp_file}"
    return 1
  fi

  chmod 600 "${_nredf_tmp_file}"
  mv -f "${_nredf_tmp_file}" "${_nredf_auth_file}"

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
  # An explicit command always re-probes the keyring (it may have been started
  # since this shell cached the startup probe).
  unset _NREDF_AQUA_KEYRING_PROBED

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
      local _token="" _read_rc=0
      # Timed like _nredf_prompt_yes_no: this is also reached from the startup
      # prompt, and a pane nobody is watching must not block forever. A
      # timeout (or EOF with nothing read) is "unanswered" — nothing is
      # recorded, so a later shell asks again (unlike an explicit --skip).
      if [[ -r /dev/tty && -w /dev/tty ]]; then
        printf "Enter a GitHub access token: " > /dev/tty
        IFS= read -r -s -t "${NREDF_PROMPT_TIMEOUT:-30}" _token < /dev/tty || _read_rc=$?
        printf "\n" > /dev/tty
      else
        printf "Enter a GitHub access token: "
        IFS= read -r -s -t "${NREDF_PROMPT_TIMEOUT:-30}" _token || _read_rc=$?
        printf "\n"
      fi

      # bash signals a timeout with a status > 128 and keeps any partial input
      # — never store half a token. A status of 1 with input is a final line
      # without a trailing newline (e.g. `printf '%s' "$TOK" | ...`): keep it.
      # (zsh's timeout returns 1 without assigning, so it lands in the empty case.)
      if (( _read_rc > 128 )) || { (( _read_rc != 0 )) && [[ -z "${_token}" ]]; }; then
        _token=""
        echo "No token entered (timed out or no input); nothing recorded." >&2
        return 2
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
    _nredf_source_env_file "${_nredf_auth_file}"
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
