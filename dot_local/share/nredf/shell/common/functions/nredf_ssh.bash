#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SSH wrapper with Bitwarden TOTP and sshpass
#
# Overview
# - Provides a drop-in replacement for ssh that can automatically supply a
#   Time-based One-Time Password (TOTP) via sshpass when connecting to hosts
#   configured with a Bitwarden TOTP item.
# - The TOTP item is referenced via an SSH config SetEnv directive:
#     SetEnv TOTP_ITEMID=<bitwarden_item_id_or_uuid>
# - If a ProxyJump is used, the first hop is inspected for TOTP_ITEMID first;
#   otherwise the target host is checked.
# - If no TOTP configuration is found, it falls back to a normal ssh invocation.
#
# Functions
# - nredf_ssh: Public alias function; currently delegates to _nredf_sshpass_totp.
# - _nredf_sshpass_totp: Core logic to discover TOTP settings and run ssh/sshpass.
# - _nredf_sshpass_bitwarden_totp: Fetches a TOTP code from Bitwarden CLI.
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

  local totp_host proxyjump pj_first
  if proxyjump=$(ssh -G "$host" | awk 'tolower($1)=="proxyjump"{print $2; f=1; exit} END{exit(f?0:1)}'); then
    pj_first=$(
      awk -v s="${proxyjump}" 'BEGIN {
      split(s, a, ",");
      first = a[1];
      sub(/^[^@]*@/, "", first);
      sub(/:.*/, "", first);
      print first
      }'
    )
  fi

  if ssh -G "$pj_first" | awk 'tolower($1)=="setenv"{for(i=2;i<=NF;i++){split($i,a,"="); if(a[1]=="TOTP_ITEMID") f=1}} END{exit(f?0:1)}'; then
    totp_host="${pj_first}"
  elif ssh -G "${host}" | awk 'tolower($1)=="setenv"{for(i=2;i<=NF;i++){split($i,a,"="); if(a[1]=="TOTP_ITEMID") f=1}} END{exit(f?0:1)}'; then
    totp_host="${host}"
  else
    ssh "${@}"
  fi

  local totp_itemid
  totp_itemid=$(
    ssh -G "${totp_host}" | awk '
      tolower($1)=="setenv" {
        for (i=2; i<=NF; i++) {
          split($i,a,"=");
          if (a[1]=="TOTP_ITEMID") v=a[2];
        }
      }
      END { if (v!="") print v }
    '
  )

  if [[ "${NREDF_CONFIGS["SSH_TOTP_PROVIDER"]}" == "bitwarden" ]]; then
    item_totp=$(_nredf_sshpass_bitwarden_totp "$totp_itemid")
  fi

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

  if ! command -v bw; then
    echo "Bitwarden CLI (bw) is not installed, trying to install"
    _nredf_tool_bw
    if ! command -v bw; then
      return 1
    fi
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
