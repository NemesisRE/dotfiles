#!/usr/bin/env bash

set -euo pipefail

EMPTY_SENTINEL="__NREDF_EMPTY__"
STATE_PREFIX="NREDF_LOCAL__"
RESOLVED_PREFIX="NREDF_RESOLVED__"

config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/chezmoi"
state_file="${config_dir}/nredf-local.env"
source_dir="${1:-}"
subcommand="${2:-}"
schema_file="${source_dir}/.chezmoidata/nredf.yaml"

record_count=0
allow_setup="false"
changed=0
RESOLVE_RESULT=""

trim_spaces() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf "%s" "${value}"
}

has_tty() {
  [[ -r /dev/tty && -w /dev/tty ]]
}

tty_print() {
  if has_tty; then
    printf "%b" "$1" > /dev/tty
  fi
}

prompt_nonempty() {
  local prompt="$1"
  local default_value="${2:-}"
  local value=""

  while true; do
    if [[ -n "${default_value}" ]]; then
      tty_print "${prompt} [${default_value}]: "
    else
      tty_print "${prompt}: "
    fi

    IFS= read -r value < /dev/tty || return 1
    if [[ -z "${value}" && -n "${default_value}" ]]; then
      value="${default_value}"
    fi

    if [[ -n "${value}" ]]; then
      printf "%s" "${value}"
      return 0
    fi

    tty_print "Please provide a value.\n"
  done
}

prompt_optional() {
  local prompt="$1"
  local default_value="${2:-}"
  local empty_token="${3:-}"
  local value=""

  while true; do
    if [[ -n "${default_value}" ]]; then
      tty_print "${prompt} [${default_value}]: "
    else
      tty_print "${prompt}: "
    fi

    IFS= read -r value < /dev/tty || return 1
    if [[ -n "${empty_token}" && "${value}" == "${empty_token}" ]]; then
      printf ""
      return 0
    fi
    if [[ -z "${value}" ]]; then
      printf "%s" "${default_value}"
      return 0
    fi

    printf "%s" "${value}"
    return 0
  done
}

prompt_choice() {
  local prompt="$1"
  local default_value="$2"
  shift 2
  local choices=("$@")
  local choice_list=""
  local value=""
  local choice=""

  choice_list="$(IFS=/; printf "%s" "${choices[*]}")"

  while true; do
    tty_print "${prompt} [${default_value}] (${choice_list}): "
    IFS= read -r value < /dev/tty || return 1
    value="${value:-${default_value}}"

    for choice in "${choices[@]}"; do
      if [[ "${value}" == "${choice}" ]]; then
        printf "%s" "${value}"
        return 0
      fi
    done

    tty_print "Please choose one of: ${choice_list}\n"
  done
}

prompt_bool() {
  local prompt="$1"
  local default_value
  local value=""

  default_value="$(normalize_bool "${2:-false}")"

  while true; do
    if [[ "${default_value}" == "true" ]]; then
      tty_print "${prompt} [Y/n]: "
    else
      tty_print "${prompt} [y/N]: "
    fi

    IFS= read -r value < /dev/tty || return 1
    value="$(trim_spaces "${value}")"
    if [[ -z "${value}" ]]; then
      printf "%s" "${default_value}"
      return 0
    fi

    case "${value}" in
      y|Y|yes|YES|true|TRUE|1)
        printf "true"
        return 0
        ;;
      n|N|no|NO|false|FALSE|0)
        printf "false"
        return 0
        ;;
    esac

    tty_print "Please answer yes or no.\n"
  done
}

prompt_int() {
  local prompt="$1"
  local default_value="${2:-0}"
  local value=""

  while true; do
    tty_print "${prompt} [${default_value}]: "
    IFS= read -r value < /dev/tty || return 1
    value="$(trim_spaces "${value}")"
    if [[ -z "${value}" ]]; then
      printf "%s" "${default_value}"
      return 0
    fi

    if [[ "${value}" =~ ^-?[0-9]+$ ]]; then
      printf "%s" "${value}"
      return 0
    fi

    tty_print "Please enter an integer value.\n"
  done
}

git_config_value() {
  local key="$1"

  if command -v git >/dev/null 2>&1; then
    git config --global --get "${key}" 2>/dev/null || true
  fi
}

normalize_bool() {
  case "${1:-}" in
    1|on|true|yes|y)
      printf "true"
      ;;
    *)
      printf "false"
      ;;
  esac
}

normalize_ssh_agent_mode() {
  case "${1:-}" in
    default|pipe|gpg|bitwarden)
      printf "%s" "$1"
      ;;
    *)
      printf ""
      ;;
  esac
}

detect_ssh_agent_mode() {
  local current_sock="${SSH_AUTH_SOCK:-}"
  local gpg_sock=""
  local sock=""
  local bitwarden_candidates=()

  if [[ -n "${current_sock}" && "${current_sock}" == *".bitwarden-ssh-agent.sock"* ]]; then
    printf "bitwarden"
    return 0
  fi

  if command -v gpgconf >/dev/null 2>&1; then
    gpg_sock="$(gpgconf --list-dirs agent-ssh-socket 2>/dev/null || true)"
    if [[ -n "${current_sock}" && -n "${gpg_sock}" && "${current_sock}" == "${gpg_sock}" ]]; then
      printf "gpg"
      return 0
    fi
  fi

  if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]]; then
    if [[ "${current_sock}" == "${HOME}/.ssh/auth_sock" || -f "${HOME}/.ssh/socat_npiperelay.pid" ]]; then
      printf "pipe"
      return 0
    fi
  fi

  if [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]; then
    bitwarden_candidates=(
      "${HOME}/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
      "${HOME}/.bitwarden-ssh-agent.sock"
    )
  else
    bitwarden_candidates=(
      "${HOME}/.bitwarden-ssh-agent.sock"
      "${HOME}/snap/bitwarden/current/.bitwarden-ssh-agent.sock"
      "${HOME}/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
    )
  fi

  for sock in "${bitwarden_candidates[@]}"; do
    if [[ -S "${sock}" ]]; then
      printf "bitwarden"
      return 0
    fi
  done

  if [[ -n "${gpg_sock}" && -S "${gpg_sock}" ]]; then
    printf "gpg"
    return 0
  fi

  printf "default"
}

should_manage_local_data() {
  case "${1:-}" in
    apply|init|update)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sanitize_segment() {
  printf "%s" "$1" | tr '[:lower:]-' '[:upper:]_' | tr -c 'A-Z0-9_' '_'
}

prefixed_var_name() {
  local prefix="$1"
  local path="$2"
  local old_ifs="${IFS}"
  local part=""
  local var_name="${prefix}"

  IFS='.'
  for part in ${path}; do
    var_name+="__$(sanitize_segment "${part}")"
  done
  IFS="${old_ifs}"

  printf "%s" "${var_name}"
}

state_var_name() {
  prefixed_var_name "${STATE_PREFIX}" "$1"
}

resolved_var_name() {
  prefixed_var_name "${RESOLVED_PREFIX}" "$1"
}

set_prefixed_value() {
  local prefix="$1"
  local path="$2"
  local value="$3"
  local encoded_value="$3"
  local var_name=""

  if [[ "${prefix}" == "${STATE_PREFIX}" && -z "${encoded_value}" ]]; then
    encoded_value="${EMPTY_SENTINEL}"
  fi

  var_name="$(prefixed_var_name "${prefix}" "${path}")"
  printf -v "${var_name}" '%s' "${encoded_value}"
}

set_state_value() {
  set_prefixed_value "${STATE_PREFIX}" "$1" "$2"
}

set_resolved_value() {
  set_prefixed_value "${RESOLVED_PREFIX}" "$1" "$2"
}

prefixed_value_is_set() {
  local prefix="$1"
  local path="$2"
  local var_name=""

  var_name="$(prefixed_var_name "${prefix}" "${path}")"
  eval '[[ ${'"${var_name}"'+x} == x ]]'
}

state_value_is_set() {
  prefixed_value_is_set "${STATE_PREFIX}" "$1"
}

resolved_value_is_set() {
  prefixed_value_is_set "${RESOLVED_PREFIX}" "$1"
}

prefixed_value() {
  local prefix="$1"
  local path="$2"
  local var_name=""
  local value=""

  var_name="$(prefixed_var_name "${prefix}" "${path}")"
  eval 'value="${'"${var_name}"'-}"'
  if [[ "${prefix}" == "${STATE_PREFIX}" && "${value}" == "${EMPTY_SENTINEL}" ]]; then
    value=""
  fi
  printf "%s" "${value}"
}

state_value() {
  prefixed_value "${STATE_PREFIX}" "$1"
}

resolved_value() {
  prefixed_value "${RESOLVED_PREFIX}" "$1"
}

migrate_state_value() {
  local old_path="$1"
  local new_path="$2"

  if ! state_value_is_set "${new_path}" && state_value_is_set "${old_path}"; then
    set_state_value "${new_path}" "$(state_value "${old_path}")"
    changed=1
  fi
}

cleanup_legacy_state_vars() {
  unset -v \
    NREDF_LOCAL__GENERELL__MULTIPLEXER \
    NREDF_LOCAL__GENERELL__SSH_AGENT \
    NREDF_LOCAL__OTHER__SSH_TOTP_PROVIDER \
    NREDF_LOCAL__OTHER__TEST_VAR \
    NREDF_LOCAL__GIT__NAME \
    NREDF_LOCAL__GIT__EMAIL \
    NREDF_LOCAL__GIT__SIGNINGKEY \
    NREDF_LOCAL__GIT__SIGNINGKEY_SSH \
    NREDF_LOCAL_GIT_NAME \
    NREDF_LOCAL_GIT_EMAIL \
    NREDF_LOCAL_GIT_SIGNINGKEY \
    NREDF_LOCAL_GIT_SIGNINGKEY_SSH \
    NREDF_LOCAL_SSH_AGENT || true
}

load_state() {
  if [[ -f "${state_file}" ]]; then
    # shellcheck disable=SC1090
    source "${state_file}"
  fi

  if [[ ${NREDF_LOCAL_GIT_NAME+x} == x ]]; then
    set_state_value "gitConfig.user.name" "${NREDF_LOCAL_GIT_NAME}"
  fi
  if [[ ${NREDF_LOCAL_GIT_EMAIL+x} == x ]]; then
    set_state_value "gitConfig.user.email" "${NREDF_LOCAL_GIT_EMAIL}"
  fi
  if [[ ${NREDF_LOCAL_GIT_SIGNINGKEY+x} == x ]]; then
    if [[ -n "${NREDF_LOCAL_GIT_SIGNINGKEY}" ]]; then
      set_state_value "gitConfig.user.signingkey" "${NREDF_LOCAL_GIT_SIGNINGKEY}"
    else
      set_state_value "gitConfig.user.signingkey" ""
    fi
  fi
  if [[ ${NREDF_LOCAL_GIT_SIGNINGKEY_SSH+x} == x ]]; then
    if [[ "$(normalize_bool "${NREDF_LOCAL_GIT_SIGNINGKEY_SSH}")" == "true" ]]; then
      set_state_value "gitConfig.gpg.format" "ssh"
    else
      set_state_value "gitConfig.gpg.format" "openpgp"
    fi
  fi
  if [[ ${NREDF_LOCAL_SSH_AGENT+x} == x ]]; then
    set_state_value "shell.ssh.agent" "$(normalize_ssh_agent_mode "${NREDF_LOCAL_SSH_AGENT}")"
  fi

  migrate_state_value "generell.multiplexer" "shell.generell.multiplexer"
  migrate_state_value "generell.ssh-agent" "shell.ssh.agent"
  migrate_state_value "other.ssh_totp_provider" "shell.ssh.totp_provider"
  migrate_state_value "other.test_var" "shell.other.test_var"
  migrate_state_value "git.name" "gitConfig.user.name"
  migrate_state_value "git.email" "gitConfig.user.email"
  migrate_state_value "git.signingkey" "gitConfig.user.signingkey"
  if ! state_value_is_set "gitConfig.gpg.format" && state_value_is_set "git.signingkey_ssh"; then
    if [[ "$(normalize_bool "$(state_value "git.signingkey_ssh")")" == "true" ]]; then
      set_state_value "gitConfig.gpg.format" "ssh"
    else
      set_state_value "gitConfig.gpg.format" "openpgp"
    fi
    changed=1
  fi

  cleanup_legacy_state_vars
}

write_state() {
  local tmp_file=""
  local var_name=""

  mkdir -p "${config_dir}"
  tmp_file="$(mktemp "${config_dir}/nredf-local.env.XXXXXX")"

  {
    printf "# Machine-local chezmoi values generated by nredf-local-data.sh\n"
    while IFS= read -r var_name; do
      printf "%s=%q\n" "${var_name}" "${!var_name}"
    done < <(compgen -A variable NREDF_LOCAL__ | LC_ALL=C sort)
  } > "${tmp_file}"

  chmod 600 "${tmp_file}"
  mv "${tmp_file}" "${state_file}"
}

decode_yaml_scalar() {
  local raw_value="$1"
  local inner=""

  if [[ "${raw_value}" == "true" || "${raw_value}" == "false" ]]; then
    SCALAR_TYPE="bool"
    SCALAR_VALUE="${raw_value}"
    return 0
  fi

  if [[ "${raw_value}" =~ ^-?[0-9]+$ ]]; then
    SCALAR_TYPE="int"
    SCALAR_VALUE="${raw_value}"
    return 0
  fi

  SCALAR_TYPE="string"
  if [[ "${raw_value}" == \"*\" && "${raw_value}" == *\" ]]; then
    inner="${raw_value:1:${#raw_value}-2}"
    inner="${inner//\\\"/\"}"
    inner="${inner//\\n/$'\n'}"
    inner="${inner//\\r/$'\r'}"
    inner="${inner//\\t/$'\t'}"
    inner="${inner//\\\\/\\}"
    SCALAR_VALUE="${inner}"
    return 0
  fi

  if [[ "${raw_value}" == \'*\' && "${raw_value}" == *\' ]]; then
    SCALAR_VALUE="${raw_value:1:${#raw_value}-2}"
    return 0
  fi

  SCALAR_VALUE="${raw_value}"
}

yaml_escape_string() {
  local value="$1"

  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}

  printf '"%s"' "${value}"
}

yaml_format_value() {
  local value_type="$1"
  local value="$2"

  case "${value_type}" in
    bool)
      printf "%s" "$(normalize_bool "${value}")"
      ;;
    int)
      printf "%s" "${value}"
      ;;
    *)
      yaml_escape_string "${value}"
      ;;
  esac
}

parse_schema() {
  local line=""
  local trimmed_line=""
  local rest=""
  local key=""
  local level=0
  local leading_spaces=0
  local in_root="false"
  local path=""
  local index=0
  local path_parts=()

  if [[ -z "${source_dir}" || ! -f "${schema_file}" ]]; then
    printf "Unable to read nredf schema at %s\n" "${schema_file}" >&2
    exit 1
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    trimmed_line="${line#"${line%%[![:space:]]*}"}"

    if [[ "${in_root}" != "true" ]]; then
      if [[ "${trimmed_line}" == "nredfDefaults:" ]]; then
        in_root="true"
      fi
      continue
    fi

    if [[ -n "${trimmed_line}" && "${trimmed_line}" != \#* && "${line}" != ' '* ]]; then
      break
    fi
    if [[ -z "${trimmed_line}" || "${trimmed_line}" == \#* ]]; then
      continue
    fi

    leading_spaces=$(( ${#line} - ${#trimmed_line} ))
    level=$(( leading_spaces / 2 - 1 ))
    key="${trimmed_line%%:*}"
    rest="${trimmed_line#*:}"
    rest="$(trim_spaces "${rest}")"
    if [[ -n "${rest}" && "${rest}" != \"* && "${rest}" != \'* ]]; then
      rest="${rest%% #*}"
      rest="$(trim_spaces "${rest}")"
    fi

    path_parts[${level}]="${key}"
    index=$(( level + 1 ))
    while [[ ${#path_parts[@]} -gt ${index} ]]; do
      unset "path_parts[${#path_parts[@]}-1]"
    done

    path=""
    for (( index = 0; index <= level; index++ )); do
      if [[ -n "${path}" ]]; then
        path+="."
      fi
      path+="${path_parts[${index}]}"
    done

    record_indent[${record_count}]="${level}"
    record_key[${record_count}]="${key}"
    record_path[${record_count}]="${path}"

    if [[ -z "${rest}" ]]; then
      record_kind[${record_count}]="map"
      record_type[${record_count}]=""
      record_default[${record_count}]=""
    else
      decode_yaml_scalar "${rest}"
      record_kind[${record_count}]="scalar"
      record_type[${record_count}]="${SCALAR_TYPE}"
      record_default[${record_count}]="${SCALAR_VALUE}"
    fi

    record_count=$(( record_count + 1 ))
  done < "${schema_file}"
}

resolve_value_for_path() {
  local path="$1"
  local value_type="$2"
  local default_value="$3"
  local value="${default_value}"
  local prompt_default=""
  local git_format=""

  RESOLVE_RESULT=""

  if state_value_is_set "${path}"; then
    RESOLVE_RESULT="$(state_value "${path}")"
    return 0
  fi

  case "${path}" in
    shell.ssh.agent)
      value="$(detect_ssh_agent_mode)"
      if [[ -z "${value}" ]]; then
        value="$(normalize_ssh_agent_mode "${default_value}")"
      fi
      if [[ "${allow_setup}" == "true" ]] && has_tty; then
        value="$(prompt_choice "SSH agent provider" "${value:-default}" default pipe gpg bitwarden)"
        set_state_value "${path}" "${value}"
        changed=1
      fi
      RESOLVE_RESULT="${value:-default}"
      return 0
      ;;
    gitConfig.user.name)
      prompt_default="$(git_config_value user.name)"
      if [[ -z "${prompt_default}" ]]; then
        prompt_default="${default_value}"
      fi
      if [[ "${allow_setup}" == "true" ]] && has_tty; then
        value="$(prompt_nonempty "Git user.name" "${prompt_default}")"
        set_state_value "${path}" "${value}"
        changed=1
      else
        value="${prompt_default}"
      fi
      RESOLVE_RESULT="${value}"
      return 0
      ;;
    gitConfig.user.email)
      prompt_default="$(git_config_value user.email)"
      if [[ -z "${prompt_default}" ]]; then
        prompt_default="${default_value}"
      fi
      if [[ "${allow_setup}" == "true" ]] && has_tty; then
        value="$(prompt_nonempty "Git user.email" "${prompt_default}")"
        set_state_value "${path}" "${value}"
        changed=1
      else
        value="${prompt_default}"
      fi
      RESOLVE_RESULT="${value}"
      return 0
      ;;
    gitConfig.user.signingkey)
      prompt_default="$(git_config_value user.signingkey)"
      if [[ -z "${prompt_default}" ]]; then
        prompt_default="${default_value}"
      fi
      if [[ "${allow_setup}" == "true" ]] && has_tty; then
        value="$(prompt_optional "Git signing key (enter - to skip)" "${prompt_default}" "-")"
        set_state_value "${path}" "${value}"
        changed=1
      else
        value="${prompt_default}"
      fi
      RESOLVE_RESULT="${value}"
      return 0
      ;;
    gitConfig.gpg.format)
      value="${default_value:-openpgp}"
      if [[ -z "$(resolved_value "gitConfig.user.signingkey")" ]]; then
        RESOLVE_RESULT="${value}"
        return 0
      fi
      git_format="$(git_config_value gpg.format)"
      if [[ "${git_format}" == "ssh" ]]; then
        value="ssh"
      elif [[ "${git_format}" == "openpgp" ]]; then
        value="openpgp"
      fi
      if [[ "${allow_setup}" == "true" ]] && has_tty; then
        value="$(prompt_choice "Git signing format" "${value}" openpgp ssh)"
        set_state_value "${path}" "${value}"
        changed=1
      fi
      RESOLVE_RESULT="${value}"
      return 0
      ;;
  esac

  if [[ "${allow_setup}" == "true" ]] && has_tty; then
    case "${value_type}" in
      bool)
        value="$(prompt_bool "Set nredf ${path}" "${default_value}")"
        ;;
      int)
        value="$(prompt_int "Set nredf ${path}" "${default_value}")"
        ;;
      *)
        value="$(prompt_optional "Set nredf ${path}" "${default_value}")"
        ;;
    esac
    set_state_value "${path}" "${value}"
    changed=1
  fi

  RESOLVE_RESULT="${value}"
}

resolve_records() {
  local index=0

  for (( index = 0; index < record_count; index++ )); do
    if [[ "${record_kind[${index}]}" != "scalar" ]]; then
      continue
    fi

    resolve_value_for_path "${record_path[${index}]}" "${record_type[${index}]}" "${record_default[${index}]}"
    set_resolved_value "${record_path[${index}]}" "${RESOLVE_RESULT}"
  done
}

render_yaml() {
  local index=0
  local indent=0
  local value=""
  local value_type=""
  local key=""

  printf "nredf:\n"
  for (( index = 0; index < record_count; index++ )); do
    indent=$(( (record_indent[${index}] + 1) * 2 ))
    printf "%*s" "${indent}" ""
    key="${record_key[${index}]}"

    if [[ "${record_kind[${index}]}" == "map" ]]; then
      printf "%s:\n" "${key}"
      continue
    fi

    value="$(resolved_value "${record_path[${index}]}")"
    value_type="${record_type[${index}]}"
    printf "%s: %s\n" "${key}" "$(yaml_format_value "${value_type}" "${value}")"
  done
}

main() {
  load_state

  if should_manage_local_data "${subcommand}"; then
    allow_setup="true"
  fi

  parse_schema
  resolve_records

  if [[ "${allow_setup}" == "true" && ( ! -f "${state_file}" || ${changed} -eq 1 ) ]]; then
    write_state
  fi

  render_yaml
}

main "$@"
