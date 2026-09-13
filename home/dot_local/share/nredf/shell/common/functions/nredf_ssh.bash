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
# - _nredf_sshpass_bitwarden_totp: Fetches a TOTP code from Bitwarden CLI.
# - _nredf_sshpass_1password_totp: Fetches a TOTP code from 1Password CLI.
#
# How it works
# 1) Reads SSH configuration using `ssh -G <host>` to detect:
#    - ProxyJump (first hop only)
#    - SetEnv TOTP_ITEMID on either the first ProxyJump host or the target host
# 2) If TOTP_ITEMID is present:
#    - Ensures Bitwarden CLI is logged in and unlocked (prompts if needed)
#    - Retrieves a TOTP code for the configured item via `bw get totp --raw`
#    - Invokes ssh via `sshpass -p "<totp>" ssh ...`
# 3) If no TOTP_ITEMID is present, runs plain `ssh ...`
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
# - nredf_ssh <ssh_host> [ssh_options...]
#   Examples:
#   - nredf_ssh myhost
#   - nredf_ssh target -p 2222 -i ~/.ssh/id_ed25519
#
# Bitwarden session handling
# - If not logged in: runs `bw login --raw` and exports BW_SESSION.
# - If locked: runs `bw unlock --raw` and exports BW_SESSION.
# - Requires interactive input if credentials are not already available.
#
# Exit codes
# - 1 if no host argument is provided.
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

function _nredf_sshpass_totp() {
  local host="$1"

  if [[ -z "${host}" ]]; then
    echo "Usage: nredf_ssh <ssh_host>"
    return 1
  fi

  local host_cfg proxyjump pj_first totp_itemid=""
  host_cfg="$(ssh -G "$host" 2>/dev/null)" || { ssh "${@}"; return $?; }

  # Helper awk script to extract TOTP_ITEMID from ssh -G output
  _parse_totp() {
    awk '
      tolower($1) == "setenv" {
        for (i = 2; i <= NF; i++) {
          split($i, a, "=")
          if (a[1] == "TOTP_ITEMID") { print a[2]; exit }
        }
      }
    ' <<< "$1"
  }

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
      local pj_cfg
      pj_cfg="$(ssh -G "${pj_first}" 2>/dev/null)"
      totp_itemid="$(_parse_totp "${pj_cfg}")"
    fi
  fi

  if [[ -z "${totp_itemid}" ]]; then
    totp_itemid="$(_parse_totp "${host_cfg}")"
  fi

  if [[ -z "${totp_itemid}" ]]; then
    ssh "${@}"
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
      item_totp=$(_nredf_sshpass_bitwarden_totp "$totp_itemid")
      ;;
    1password|onepassword|op)
      item_totp=$(_nredf_sshpass_1password_totp "$totp_itemid")
      ;;
  esac

  if [[ -z "${item_totp}" ]]; then
    ssh "${@}"
  else
    # Unset SSH_ASKPASS to prevent GUI password prompts from interfering with sshpass
    # sshpass needs to handle password input directly via stdin/controlling terminal
    env SSH_ASKPASS="" SSH_ASKPASS_REQUIRE="" DISPLAY="" sshpass -p "${item_totp}" ssh "${@}"
  fi
}

function _nredf_sshpass_bitwarden_totp() {
  local itemid="$1"
  local totp

  if ! command -v bw &>/dev/null; then
    echo "Bitwarden CLI (bw) is not installed. Run: aqua install" >&2
    return 1
  fi

  if ! bw login --check &>/dev/null; then
    BW_SESSION=$(bw login --raw)
    export BW_SESSION
  fi

  if ! bw unlock --check &>/dev/null; then
    BW_SESSION=$(bw unlock --raw)
    export BW_SESSION
  fi

  totp=$(bw get totp "${itemid}" --raw)

  echo "$totp"
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
