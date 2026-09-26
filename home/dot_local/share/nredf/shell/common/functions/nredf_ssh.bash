#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SSH wrapper with Bitwarden / 1Password TOTP and sshpass
#
# Overview
# - Provides a drop-in replacement for ssh that can automatically supply a
#   Time-based One-Time Password (TOTP) via sshpass when connecting to hosts
#   configured with a Bitwarden or 1Password TOTP item.
# - The TOTP item is referenced via an SSH config SetEnv directive:
#     SetEnv TOTP_ITEMID=<item_id_or_uuid>
# - If a ProxyJump is used, the first hop is inspected for TOTP_ITEMID first;
#   otherwise the target host is checked.
# - If no TOTP configuration is found, it falls back to a normal ssh invocation.
#
# Functions
# - nredf_ssh: Public alias function; currently delegates to _nredf_sshpass_totp.
# - _nredf_sshpass_totp: Core logic to discover TOTP settings and run ssh/sshpass.
# - _nredf_ssh_destination: Finds the destination in an ssh argument list.
# - _nredf_ssh_parse_totp: Extracts TOTP_ITEMID from `ssh -G` output.
# - _nredf_sshpass_bitwarden_unlock: Unlocks Bitwarden in the calling shell.
# - _nredf_sshpass_1password_totp: Fetches a TOTP code from 1Password CLI.
#
# How it works
# 1) Finds the destination by skipping ssh options (and the values of options
#    that take one).
# 2) Reads SSH configuration using `ssh [-F file] -G <destination>` to detect:
#    - ProxyJump (first hop only)
#    - SetEnv TOTP_ITEMID on either the first ProxyJump host or the target host
# 3) If TOTP_ITEMID is present:
#    - Ensures Bitwarden CLI is logged in and unlocked (prompts if needed)
#    - Retrieves a TOTP code for the configured item via `bw get totp --raw`
#    - Invokes ssh via `sshpass -p "<totp>" ssh ...`
# 4) If no TOTP_ITEMID is present, runs plain `ssh ...`
#
# Requirements
# - ssh, sshpass, awk
# - Bitwarden CLI (`bw`) if TOTP is used
# - A Bitwarden item configured with an OTP secret (TOTP)
#
# SSH configuration
# - Add SetEnv with your Bitwarden item ID/UUID on either the target host
#   or the first ProxyJump host.
#
#   Example: Direct host
#     Host myhost
#       HostName example.com
#       User ec2-user
#       SetEnv TOTP_ITEMID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
#   Example: With ProxyJump (first hop carries TOTP)
#     Host jumphost
#       HostName jump.example.com
#       User jumpuser
#       SetEnv TOTP_ITEMID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
#     Host target
#       HostName target.internal
#       User appuser
#       ProxyJump jumpuser@jumphost
#
# Usage
# - nredf_ssh [ssh_options...] <destination> [command...]
#   Takes exactly the arguments ssh does.
#   Examples:
#   - nredf_ssh myhost
#   - nredf_ssh -p 2222 -i ~/.ssh/id_ed25519 user@target uptime
#
# Bitwarden session handling
# - Uses _nredf_bw_ensure_session (from nredf_bw.bash) which restores
#   BW_SESSION from the OS keychain (Touch ID / Windows Hello / KDE Wallet /
#   GNOME Keyring) before falling back to an interactive bw unlock prompt.
# - It runs in the calling shell (never in a $(...) subshell), so the exported
#   BW_SESSION persists for the next nredf_ssh call.
# - BW_SESSION is cached in the keychain after the first unlock.
# - Requires interactive input only when the keychain has no valid entry.
#
# Exit codes
# - 1 if no arguments are provided.
# - Otherwise, mirrors the exit code of the underlying ssh/sshpass invocation.
#
# Security notes
# - sshpass receives the TOTP via `-p`, which can be observable in process
#   arguments on multi-user systems. Although TOTP codes are short-lived,
#   consider the exposure risk.
# - BW_SESSION is exported to the environment. Guard your shell history and
#   environment from unintended exposure.
#
# Limitations
# - Only the first ProxyJump hop is inspected for TOTP_ITEMID.
# - Only -F is forwarded to `ssh -G`; a ProxyJump given via -J/-o on the
#   command line is not inspected.
# - Requires `bw` to be installed and accessible if TOTP is desired.
# - The Bitwarden item referenced by TOTP_ITEMID must have a TOTP configured.
#
# Fallback behavior
# - If `bw` is not available or no TOTP_ITEMID is found, the function falls
#   back to running plain ssh.
# -----------------------------------------------------------------------------


# Alias function for 'ssh'
function nredf_ssh() {
  _nredf_sshpass_totp "$@"
}

# Prints the -F config file (possibly empty) on line 1 and the destination of
# an ssh argument list on line 2 (destination last, so $(...) stripping
# trailing newlines is harmless); prints nothing when there is no destination.
# Mirrors ssh's getopt: option clusters (-4vA) are skipped, and so is the value
# of every option letter that takes one, attached (-p2222) or separate
# (-p 2222). The first non-option is the destination, returned as given:
# `ssh -G` parses [user@]host and ssh:// URIs itself, and needs the user to
# evaluate `Match user` blocks correctly.
function _nredf_ssh_destination() {
  local arg c dest="" cfg_file="" want="" end_opts=0
  local -i i
  for arg in "$@"; do
    if [[ -n "${want}" ]]; then
      [[ "${want}" == "F" ]] && cfg_file="${arg}"
      want=""
      continue
    fi
    if (( ! end_opts )) && [[ "${arg}" == "--" ]]; then
      end_opts=1
      continue
    fi
    if (( ! end_opts )) && [[ "${arg}" == -?* ]]; then
      for (( i = 1; i < ${#arg}; i++ )); do
        c="${arg:$i:1}"
        case "${c}" in
          [BbcDEeFIiJLlmOoPpQRSWw])
            if (( i + 1 < ${#arg} )); then
              [[ "${c}" == "F" ]] && cfg_file="${arg:$((i + 1))}"
            else
              want="${c}"
            fi
            break
            ;;
        esac
      done
      continue
    fi
    dest="${arg}"
    break
  done

  [[ -z "${dest}" ]] && return 0

  printf '%s\n%s\n' "${cfg_file}" "${dest}"
}

# Extracts TOTP_ITEMID from `ssh -G` output ($1).
function _nredf_ssh_parse_totp() {
  awk '
    tolower($1) == "setenv" {
      for (i = 2; i <= NF; i++) {
        split($i, a, "=")
        if (a[1] == "TOTP_ITEMID") { print a[2]; exit }
      }
    }
  ' <<< "$1"
}

function _nredf_sshpass_totp() {
  if (( $# == 0 )); then
    echo "Usage: nredf_ssh [ssh_options...] <destination> [command...]" >&2
    return 1
  fi

  local parsed host cfg_file
  parsed="$(_nredf_ssh_destination "$@")"
  cfg_file="${parsed%%$'\n'*}"
  host="${parsed#*$'\n'}"

  # No destination (e.g. `nredf_ssh -V`): nothing to look up.
  if [[ -z "${host}" ]]; then
    ssh "$@"
    return $?
  fi

  local -a g_opts=()
  [[ -n "${cfg_file}" ]] && g_opts=(-F "${cfg_file}")

  local host_cfg proxyjump pj_first pj_cfg totp_itemid=""
  host_cfg="$(ssh "${g_opts[@]}" -G "${host}" 2>/dev/null)" || { ssh "$@"; return $?; }

  proxyjump=$(awk 'tolower($1)=="proxyjump" && $2!="none"{print $2; exit}' <<< "${host_cfg}")
  if [[ -n "${proxyjump}" ]]; then
    pj_first=$(awk -v s="${proxyjump}" 'BEGIN {
      split(s, a, ",");
      first = a[1];
      sub(/^[^@]*@/, "", first);
      sub(/:.*/, "", first);
      print first
    }')
    if [[ -n "${pj_first}" ]]; then
      pj_cfg="$(ssh "${g_opts[@]}" -G "${pj_first}" 2>/dev/null)"
      totp_itemid="$(_nredf_ssh_parse_totp "${pj_cfg}")"
    fi
  fi

  if [[ -z "${totp_itemid}" ]]; then
    totp_itemid="$(_nredf_ssh_parse_totp "${host_cfg}")"
  fi

  if [[ -z "${totp_itemid}" ]]; then
    ssh "$@"
    return $?
  fi

  local item_totp=""
  local totp_provider="${NREDF_SHELL_SSH_TOTP_PROVIDER:-}"
  totp_provider="${totp_provider#\#}"

  if [[ -z "${totp_provider}" ]]; then
    if command -v bw &>/dev/null; then
      totp_provider="bitwarden"
    elif command -v op &>/dev/null; then
      totp_provider="1password"
    fi
  fi

  case "${totp_provider}" in
    bitwarden)
      # Unlock in *this* shell, not inside the $(...) below: a subshell's
      # exported BW_SESSION dies with it, and every TOTP host would then
      # re-prompt for the master password.
      if _nredf_sshpass_bitwarden_unlock; then
        item_totp=$(bw get totp "${totp_itemid}" --raw)
      fi
      ;;
    1password|onepassword|op)
      item_totp=$(_nredf_sshpass_1password_totp "${totp_itemid}")
      ;;
  esac

  if [[ -z "${item_totp}" ]]; then
    ssh "$@"
  else
    # Unset SSH_ASKPASS to prevent GUI password prompts from interfering with sshpass
    # sshpass needs to handle password input directly via stdin/controlling terminal
    env SSH_ASKPASS="" SSH_ASKPASS_REQUIRE="" DISPLAY="" sshpass -p "${item_totp}" ssh "$@"
  fi
}

# Ensures the Bitwarden vault is unlocked (keychain / biometrics when
# available). Must be called directly, not in $(...), so the BW_SESSION that
# _nredf_bw_ensure_session exports lands in the calling shell.
function _nredf_sshpass_bitwarden_unlock() {
  if ! command -v bw &>/dev/null; then
    echo "Bitwarden CLI (bw) is not installed. Run: aqua install" >&2
    return 1
  fi

  if ! _nredf_bw_ensure_session --force; then
    echo "Bitwarden: failed to unlock vault" >&2
    return 1
  fi
}

function _nredf_sshpass_1password_totp() {
  local itemid="$1"
  local totp

  if ! command -v op &>/dev/null; then
    echo "1Password CLI (op) is not installed. Run: aqua install" >&2
    return 1
  fi

  if ! totp=$(op item get "${itemid}" --otp 2>/dev/null); then
    echo "Failed to retrieve TOTP from 1Password for item: ${itemid}" >&2
    return 1
  fi

  echo "$totp"
}
