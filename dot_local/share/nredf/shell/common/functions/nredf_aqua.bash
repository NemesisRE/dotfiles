#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_set_aqua_env() {
  local _nredf_aqua_base_config="${XDG_CONFIG_HOME}/aquaproj-aqua/aqua.yaml"
  local _nredf_aqua_machine_config="${XDG_CONFIG_HOME}/aquaproj-aqua/machine.yaml"
  local _nredf_aqua_policy_config="${XDG_CONFIG_HOME}/aquaproj-aqua/aqua-policy.yaml"
  local _nredf_aqua_auth_config="${NREDF_CONFIG:-${XDG_CONFIG_HOME:-${HOME}/.config}/nredf}/aqua.env"

  if [[ -f "${_nredf_aqua_auth_config}" ]]; then
    # shellcheck disable=SC1090
    source "${_nredf_aqua_auth_config}"
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
    fi
  } > "${_nredf_tmp_file}"

  chmod 600 "${_nredf_tmp_file}"
  mv "${_nredf_tmp_file}" "${_nredf_auth_file}"

  unset _nredf_mode _nredf_auth_file _nredf_auth_dir _nredf_tmp_file
}

function _nredf_clear_aqua_auth_config() {
  local _nredf_auth_file=""

  _nredf_auth_file="$(_nredf_aqua_auth_config_file)"
  rm -f "${_nredf_auth_file}"
  unset AQUA_KEYRING_ENABLED NREDF_AQUA_GITHUB_TOKEN_SETUP
  unset _nredf_auth_file
}

function _nredf_prompt_yes_no() {
  local _nredf_prompt="$1"
  local _nredf_reply=""

  if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
    return 1
  fi

  while true; do
    printf "%s [y/N]: " "${_nredf_prompt}" > /dev/tty
    IFS= read -r _nredf_reply < /dev/tty || return 1
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
    --set)
      if ! command -v aqua &>/dev/null; then
        echo "aqua is not installed." >&2
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
    *)
      echo "Usage: nredf_aqua_token_setup [--set|--skip|--reset]" >&2
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

  if ! command -v aqua &>/dev/null; then
    return 0
  fi

  if [[ -n "${AQUA_GITHUB_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
    return 0
  fi

  if [[ "${AQUA_KEYRING_ENABLED:-}" == "true" || "${_nredf_setup_state}" == "keyring" ]]; then
    return 0
  fi

  _nredf_auth_file="$(_nredf_aqua_auth_config_file)"
  if [[ -z "${_nredf_setup_state}" && -f "${_nredf_auth_file}" ]]; then
    # shellcheck disable=SC1090
    source "${_nredf_auth_file}"
    _nredf_setup_state="${NREDF_AQUA_GITHUB_TOKEN_SETUP:-}"
  fi

  if [[ "${AQUA_KEYRING_ENABLED:-}" == "true" || "${_nredf_setup_state}" == "keyring" ]]; then
    export AQUA_KEYRING_ENABLED="true"
    return 0
  fi

  if [[ "${_nredf_setup_state}" == "skip" ]]; then
    return 0
  fi

  if ! _nredf_prompt_yes_no "No GitHub token configured for aqua. Store one in the system keyring now?"; then
    nredf_aqua_token_setup --skip >/dev/null
    printf "Run 'nredf_aqua_token_setup' later to configure aqua's GitHub token.\n" > /dev/tty
    return 0
  fi

  if ! nredf_aqua_token_setup --set; then
    printf "aqua GitHub token setup was not completed.\n" > /dev/tty
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

  echo -e '\033[1mVacuuming aqua packages\033[0m'
  aqua vacuum -d "${_nredf_vacuum_days}" >/dev/null 2>&1 || true
  _nredf_last_run "" "true" "$(($(date +%s) + NREDF_24H_INTERVAL))"
  _nredf_remove_lock
}
