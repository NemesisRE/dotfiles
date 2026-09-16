#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
# -----------------------------------------------------------------------------
# Bitwarden session management with OS keychain / biometric unlock
#
# Overview
# - Saves BW_SESSION in the native OS keychain after a successful unlock so
#   subsequent shell sessions can retrieve the token without re-entering the
#   master password.
# - macOS  : `security` (Keychain Services) — Touch ID unlocks the keychain
#             item transparently when the screen is locked / after sleep.
# - Linux  : `kwallet-query` (KDE Wallet) → `secret-tool` (GNOME Keyring)
#             → plaintext file in $XDG_RUNTIME_DIR with mode 600 (fallback).
#
# Public functions
# - bwu               Ensure BW_SESSION is set (keychain → fresh unlock),
#                     export it, print confirmation.
# - bwlock            Lock the vault, unset BW_SESSION, remove keychain entry.
# - chezmoi           Wrapper: restores BW_SESSION from keychain before
#                     delegating to the real chezmoi binary, so template
#                     functions like {{ bitwarden "item" "..." }} never prompt
#                     for the master password interactively.
# - _nredf_bw_ensure_session
#                     Low-level helper for use by other nredf functions (e.g.
#                     nredf_ssh TOTP helper). Sets and exports BW_SESSION.
#                     Returns 0 on success, 1 on failure.
#
# Keychain item identity
# - Service / label   : "nredf.bw_session"
# - Account           : value of $USER (falls back to $(id -un))
# -----------------------------------------------------------------------------

_NREDF_BW_SERVICE="nredf.bw_session"
_NREDF_BW_ACCOUNT="${USER:-$(id -un 2>/dev/null)}"

# ---------------------------------------------------------------------------
# Internal: detect which keychain backend is available
# ---------------------------------------------------------------------------
_nredf_bw_keychain_backend() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    echo "macos"
    return 0
  fi

  if command -v kwallet-query &>/dev/null; then
    echo "kwallet"
    return 0
  fi

  if command -v secret-tool &>/dev/null; then
    echo "secret-tool"
    return 0
  fi

  echo "fallback"
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Internal: helper to ensure folder exists in KWallet via qdbus
# ---------------------------------------------------------------------------
_nredf_bw_kwallet_ensure_folder() {
  local folder="$1"
  local wallet="${2:-kdewallet}"
  local qdbus_cmd=""
  local service=""

  for cmd in qdbus6 qdbus; do
    if command -v "${cmd}" &>/dev/null; then
      qdbus_cmd="${cmd}"
      break
    fi
  done
  [[ -z "${qdbus_cmd}" ]] && return 1

  for s in org.kde.kwalletd6 org.kde.kwalletd5; do
    if "${qdbus_cmd}" "${s}" &>/dev/null; then
      service="${s}"
      break
    fi
  done
  [[ -z "${service}" ]] && return 1

  local mod="/modules/${service##*.}"
  local handle
  handle="$("${qdbus_cmd}" "${service}" "${mod}" open "${wallet}" 0 "nredf" 2>/dev/null)" || return 1
  if [[ -n "${handle}" && "${handle}" -ge 0 ]]; then
    local has_folder
    has_folder="$("${qdbus_cmd}" "${service}" "${mod}" hasFolder "${handle}" "${folder}" 2>/dev/null)"
    if [[ "${has_folder}" != "true" ]]; then
      "${qdbus_cmd}" "${service}" "${mod}" createFolder "${handle}" "${folder}" &>/dev/null || true
    fi
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Internal: retrieve session token from keychain
# Returns 0 and prints token on success, returns 1 on miss.
# ---------------------------------------------------------------------------
_nredf_bw_keychain_get() {
  local backend token
  backend="$(_nredf_bw_keychain_backend)"

  case "${backend}" in
    macos)
      token="$(security find-generic-password \
        -s "${_NREDF_BW_SERVICE}" \
        -a "${_NREDF_BW_ACCOUNT}" \
        -w 2>/dev/null)"
      ;;
    kwallet)
      # Try nredf folder first, fallback to standard Passwords folder
      token="$(kwallet-query \
        --read-password "${_NREDF_BW_SERVICE}" \
        --folder "nredf" \
        kdewallet 2>/dev/null)"
      if [[ -z "${token}" ]]; then
        token="$(kwallet-query \
          --read-password "${_NREDF_BW_SERVICE}" \
          --folder "Passwords" \
          kdewallet 2>/dev/null)"
      fi
      ;;
    secret-tool)
      token="$(secret-tool lookup \
        service "${_NREDF_BW_SERVICE}" \
        username "${_NREDF_BW_ACCOUNT}" 2>/dev/null)"
      ;;
    fallback)
      local f="${XDG_RUNTIME_DIR:-/tmp}/nredf_bw_session"
      [[ -f "${f}" ]] && token="$(<"${f}")"
      ;;
  esac

  if [[ -n "${token}" ]]; then
    printf "%s" "${token}"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Internal: save session token to keychain
# ---------------------------------------------------------------------------
_nredf_bw_keychain_set() {
  local token="$1"
  local backend
  backend="$(_nredf_bw_keychain_backend)"

  case "${backend}" in
    macos)
      # Delete existing entry silently before adding to avoid duplicate errors
      security delete-generic-password \
        -s "${_NREDF_BW_SERVICE}" \
        -a "${_NREDF_BW_ACCOUNT}" &>/dev/null || true
      security add-generic-password \
        -s "${_NREDF_BW_SERVICE}" \
        -a "${_NREDF_BW_ACCOUNT}" \
        -w "${token}" \
        -U &>/dev/null
      ;;
    kwallet)
      local write_ok=1
      # Ensure 'nredf' folder exists via qdbus if possible
      _nredf_bw_kwallet_ensure_folder "nredf" "kdewallet" 2>/dev/null || true
      if printf "%s" "${token}" | kwallet-query \
        --write-password "${_NREDF_BW_SERVICE}" \
        --folder "nredf" \
        kdewallet &>/dev/null; then
        write_ok=0
      else
        # Fallback to default 'Passwords' folder which always exists
        if printf "%s" "${token}" | kwallet-query \
          --write-password "${_NREDF_BW_SERVICE}" \
          --folder "Passwords" \
          kdewallet &>/dev/null; then
          write_ok=0
        fi
      fi
      ;;
    secret-tool)
      printf "%s" "${token}" | secret-tool store \
        --label "NREDF Bitwarden session" \
        service "${_NREDF_BW_SERVICE}" \
        username "${_NREDF_BW_ACCOUNT}" &>/dev/null
      ;;
    fallback)
      local f="${XDG_RUNTIME_DIR:-/tmp}/nredf_bw_session"
      printf "%s" "${token}" >"${f}"
      chmod 600 "${f}"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Internal: remove session token from keychain
# ---------------------------------------------------------------------------
_nredf_bw_keychain_del() {
  local backend
  backend="$(_nredf_bw_keychain_backend)"

  case "${backend}" in
    macos)
      security delete-generic-password \
        -s "${_NREDF_BW_SERVICE}" \
        -a "${_NREDF_BW_ACCOUNT}" &>/dev/null || true
      ;;
    kwallet)
      kwallet-query \
        --delete-entry "${_NREDF_BW_SERVICE}" \
        --folder "nredf" \
        kdewallet &>/dev/null || true
      kwallet-query \
        --delete-entry "${_NREDF_BW_SERVICE}" \
        --folder "Passwords" \
        kdewallet &>/dev/null || true
      ;;
    secret-tool)
      secret-tool clear \
        service "${_NREDF_BW_SERVICE}" \
        username "${_NREDF_BW_ACCOUNT}" &>/dev/null || true
      ;;
    fallback)
      rm -f "${XDG_RUNTIME_DIR:-/tmp}/nredf_bw_session"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Internal: perform a fresh bw unlock/login and persist the session
# ---------------------------------------------------------------------------
_nredf_bw_do_unlock() {
  if ! command -v bw &>/dev/null; then
    printf "Bitwarden CLI (bw) is not installed. Run: aqua install\n" >&2
    return 1
  fi

  local session
  if ! bw login --check &>/dev/null; then
    printf "Bitwarden: not logged in — running bw login\n" >&2
    session="$(bw login --raw)" || return 1
  else
    printf "Bitwarden: vault locked — running bw unlock\n" >&2
    session="$(bw unlock --raw)" || return 1
  fi

  if [[ -z "${session}" ]]; then
    printf "Bitwarden: unlock returned an empty session token\n" >&2
    return 1
  fi

  _nredf_bw_keychain_set "${session}"
  BW_SESSION="${session}"
  export BW_SESSION
  return 0
}

# ---------------------------------------------------------------------------
# Public: _nredf_bw_ensure_session
# Ensures BW_SESSION is set and valid. Returns 0 on success, 1 on failure.
# ---------------------------------------------------------------------------
function _nredf_bw_ensure_session() {
  if ! command -v bw &>/dev/null; then
    printf "Bitwarden CLI (bw) is not installed. Run: aqua install\n" >&2
    return 1
  fi

  # 1. If BW_SESSION is already set in the environment, validate it.
  if [[ -n "${BW_SESSION:-}" ]]; then
    if bw unlock --check &>/dev/null; then
      return 0
    fi
    # Token is stale — fall through to keychain lookup
    unset BW_SESSION
  fi

  # 2. Try to restore from keychain
  local cached_session
  if cached_session="$(_nredf_bw_keychain_get)"; then
    BW_SESSION="${cached_session}"
    export BW_SESSION
    if bw unlock --check &>/dev/null; then
      return 0
    fi
    # Cached token is stale — remove it and do a fresh unlock
    unset BW_SESSION
    _nredf_bw_keychain_del
  fi

  # 3. Fresh unlock
  _nredf_bw_do_unlock
}

# ---------------------------------------------------------------------------
# Public: bwu — Bitwarden Unlock
# Ensures the vault is unlocked and BW_SESSION is exported.
# ---------------------------------------------------------------------------
function bwu() {
  if _nredf_bw_ensure_session; then
    printf "\033[1;32m✔ Bitwarden vault unlocked\033[0m\n"
    return 0
  else
    printf "\033[1;31m✘ Failed to unlock Bitwarden vault\033[0m\n" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Public: bwlock — lock the vault and wipe the keychain entry
# ---------------------------------------------------------------------------
function bwlock() {
  _nredf_bw_keychain_del

  if [[ -n "${BW_SESSION:-}" ]]; then
    bw lock &>/dev/null || true
    unset BW_SESSION
  fi

  printf "\033[1;33m⚿ Bitwarden vault locked and session cleared\033[0m\n"
}

# ---------------------------------------------------------------------------
# Public: chezmoi wrapper
# Pre-loads BW_SESSION from the keychain so chezmoi template functions like
# {{ bitwarden "item" "..." }} never prompt for the master password.
# Only activates when `bw` is on PATH; otherwise delegates transparently.
#
# NOTE: stderr is intentionally NOT suppressed here — bw unlock writes its
# "? Master password:" prompt to stderr and we need it visible on the terminal.
# ---------------------------------------------------------------------------
function chezmoi() {
  # Only inject the session when bw is available and this is not a bootstrap
  # run that explicitly opts out (NREDF_NO_BOOTSTRAP=1 or CI=true).
  if command -v bw &>/dev/null \
    && [[ "${NREDF_NO_BOOTSTRAP:-}" != "1" && "${CI:-}" != "true" ]]; then
    _nredf_bw_ensure_session || true
  fi
  command chezmoi "$@"
}
