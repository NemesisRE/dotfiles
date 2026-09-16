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
# - _nredf_bw_restore_session
#                     Restores BW_SESSION from keychain if available (silent,
#                     non-blocking, called during shell startup).
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
# Internal: helpers for interacting with KWallet via gdbus / D-Bus
# Works natively on KDE Plasma 6 (kwalletd6) and Plasma 5 (kwalletd5).
# ---------------------------------------------------------------------------
_nredf_bw_kwallet_service() {
  command -v gdbus &>/dev/null || return 1
  local en
  for s in org.kde.kwalletd6 org.kde.kwalletd5; do
    en="$(gdbus call --session --dest "${s}" --object-path "/modules/${s##*.}" \
      --method org.kde.KWallet.isEnabled 2>/dev/null)" || continue
    if [[ "${en}" == *true* ]]; then
      printf "%s" "${s}"
      return 0
    fi
  done
  return 1
}

_nredf_bw_kwallet_open() {
  local service="$1"
  local wallet="${2:-kdewallet}"
  local mod="/modules/${service##*.}"
  local res
  res="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
    --method org.kde.KWallet.open "${wallet}" 0 "nredf" 2>/dev/null)" || return 1
  # Extract numeric handle
  local handle
  handle="$(printf "%s" "${res}" | tr -dc '0-9')"
  if [[ -n "${handle}" && "${handle}" -ge 0 ]]; then
    printf "%s" "${handle}"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Internal: detect which keychain backend is available
# ---------------------------------------------------------------------------
_nredf_bw_keychain_backend() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    echo "macos"
    return 0
  fi

  if command -v kwallet-query &>/dev/null || (command -v gdbus &>/dev/null && _nredf_bw_kwallet_service &>/dev/null); then
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
      # Primary: native D-Bus via gdbus (Plasma 6 / 5)
      if command -v gdbus &>/dev/null; then
        local service handle raw
        if service="$(_nredf_bw_kwallet_service)"; then
          if handle="$(_nredf_bw_kwallet_open "${service}")"; then
            local mod="/modules/${service##*.}"
            # Check nredf folder first, fallback to Passwords
            for f in "nredf" "Passwords"; do
              raw="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
                --method org.kde.KWallet.readPassword "${handle}" "${f}" "${_NREDF_BW_SERVICE}" "nredf" 2>/dev/null)" || true
              if [[ "${raw}" == \(\'* ]]; then
                token="${raw#*(\'}"
                token="${token%\',)}"
                [[ -n "${token}" ]] && break
              fi
            done
          fi
        fi
      fi

      # Fallback: kwallet-query CLI
      if [[ -z "${token}" ]] && command -v kwallet-query &>/dev/null; then
        token="$(kwallet-query --read-password "${_NREDF_BW_SERVICE}" --folder "nredf" kdewallet 2>/dev/null)"
        if [[ -z "${token}" ]]; then
          token="$(kwallet-query --read-password "${_NREDF_BW_SERVICE}" --folder "Passwords" kdewallet 2>/dev/null)"
        fi
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
      local saved=1
      # Primary: native D-Bus via gdbus (persists reliably in Plasma 6 & 5)
      if command -v gdbus &>/dev/null; then
        local service handle
        if service="$(_nredf_bw_kwallet_service)"; then
          if handle="$(_nredf_bw_kwallet_open "${service}")"; then
            local mod="/modules/${service##*.}"
            # Ensure folder nredf exists or create it
            local has_f
            has_f="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
              --method org.kde.KWallet.hasFolder "${handle}" "nredf" 2>/dev/null)"
            if [[ "${has_f}" != *true* ]]; then
              gdbus call --session --dest "${service}" --object-path "${mod}" \
                --method org.kde.KWallet.createFolder "${handle}" "nredf" &>/dev/null || true
            fi
            # Write to nredf folder, fallback to Passwords
            local res
            res="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
              --method org.kde.KWallet.writePassword "${handle}" "nredf" "${_NREDF_BW_SERVICE}" "${token}" "nredf" 2>/dev/null)"
            if [[ "${res}" == *\(0,\)* ]]; then
              saved=0
            else
              res="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
                --method org.kde.KWallet.writePassword "${handle}" "Passwords" "${_NREDF_BW_SERVICE}" "${token}" "nredf" 2>/dev/null)"
              [[ "${res}" == *\(0,\)* ]] && saved=0
            fi
          fi
        fi
      fi

      # Secondary: kwallet-query CLI
      if [[ "${saved}" -ne 0 ]] && command -v kwallet-query &>/dev/null; then
        printf "%s" "${token}" | kwallet-query --write-password "${_NREDF_BW_SERVICE}" --folder "nredf" kdewallet &>/dev/null \
          || printf "%s" "${token}" | kwallet-query --write-password "${_NREDF_BW_SERVICE}" --folder "Passwords" kdewallet &>/dev/null || true
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
      if command -v gdbus &>/dev/null; then
        local service handle
        if service="$(_nredf_bw_kwallet_service)"; then
          if handle="$(_nredf_bw_kwallet_open "${service}")"; then
            local mod="/modules/${service##*.}"
            gdbus call --session --dest "${service}" --object-path "${mod}" \
              --method org.kde.KWallet.removeEntry "${handle}" "nredf" "${_NREDF_BW_SERVICE}" "nredf" &>/dev/null || true
            gdbus call --session --dest "${service}" --object-path "${mod}" \
              --method org.kde.KWallet.removeEntry "${handle}" "Passwords" "${_NREDF_BW_SERVICE}" "nredf" &>/dev/null || true
          fi
        fi
      fi
      if command -v kwallet-query &>/dev/null; then
        kwallet-query --delete-entry "${_NREDF_BW_SERVICE}" --folder "nredf" kdewallet &>/dev/null || true
        kwallet-query --delete-entry "${_NREDF_BW_SERVICE}" --folder "Passwords" kdewallet &>/dev/null || true
      fi
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
# Internal: detect whether any Bitwarden secret is actually used in config
# Returns 0 if Bitwarden is configured in chezmoi.toml or chezmoidata, 1 otherwise.
# ---------------------------------------------------------------------------
_nredf_bw_secret_configured() {
  local cfg="${XDG_CONFIG_HOME:-${HOME}/.config}/chezmoi/chezmoi.toml"
  [[ -f "${cfg}" ]] || cfg="${HOME}/.config/chezmoi/chezmoi.toml"

  # 1. Check chezmoi.toml if present
  if [[ -f "${cfg}" ]]; then
    if grep -Eq '^[[:blank:]]*\[bitwarden\]' "${cfg}" 2>/dev/null; then
      return 0
    fi
    if grep -Eq '["'\'' ](bitwarden|bw):' "${cfg}" 2>/dev/null; then
      return 0
    fi
  fi

  # 2. Check repo-level chezmoidata if present
  local src_dir="${NREDF_DOT_PATH:-${HOME}/.local/share/chezmoi}"
  if [[ -d "${src_dir}/home/.chezmoidata" ]]; then
    if grep -rEq '["'\'' ](bitwarden|bw):' "${src_dir}/home/.chezmoidata" 2>/dev/null; then
      return 0
    fi
  fi
  if [[ -f "${src_dir}/home/.chezmoidata.yaml" ]]; then
    if grep -Eq '["'\'' ](bitwarden|bw):' "${src_dir}/home/.chezmoidata.yaml" 2>/dev/null; then
      return 0
    fi
  fi

  return 1
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
# Public: _nredf_bw_restore_session
# Restores BW_SESSION from the OS keychain if not already set in the environment.
# Fast and non-blocking: never prompts, suitable for shell startup.
# ---------------------------------------------------------------------------
function _nredf_bw_restore_session() {
  [[ -n "${BW_SESSION:-}" ]] && return 0
  command -v bw &>/dev/null || return 0

  local cached
  if cached="$(_nredf_bw_keychain_get 2>/dev/null)" && [[ -n "${cached}" ]]; then
    BW_SESSION="${cached}"
    export BW_SESSION
  fi
}

# ---------------------------------------------------------------------------
# Public: _nredf_bw_ensure_session
# Ensures BW_SESSION is set and valid. Returns 0 on success, 1 on failure.
# If not forced, only prompts/unlocks if a Bitwarden secret is configured.
# ---------------------------------------------------------------------------
function _nredf_bw_ensure_session() {
  local force="${1:-false}"

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
  if cached_session="$(_nredf_bw_keychain_get 2>/dev/null)"; then
    BW_SESSION="${cached_session}"
    export BW_SESSION
    if bw unlock --check &>/dev/null; then
      return 0
    fi
    # Cached token is stale — remove it and do a fresh unlock
    unset BW_SESSION
    _nredf_bw_keychain_del
  fi

  # 3. Only do a fresh unlock if explicitly forced (e.g. bwu / ssh TOTP) or if a Bitwarden secret is configured
  if [[ "${force}" != "true" && "${force}" != "--force" ]] && ! _nredf_bw_secret_configured; then
    return 0
  fi

  # 4. Fresh unlock
  _nredf_bw_do_unlock
}

# ---------------------------------------------------------------------------
# Public: bwu — Bitwarden Unlock
# Ensures the vault is unlocked and BW_SESSION is exported.
# ---------------------------------------------------------------------------
function bwu() {
  if _nredf_bw_ensure_session --force; then
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
# Only activates when `bw` is on PATH, not in bootstrap/CI, and a Bitwarden
# secret is actually used in the config.
#
# NOTE: stderr is intentionally NOT suppressed here — bw unlock writes its
# "? Master password:" prompt to stderr and we need it visible on the terminal.
# ---------------------------------------------------------------------------
function chezmoi() {
  if command -v bw &>/dev/null \
    && [[ "${NREDF_NO_BOOTSTRAP:-}" != "1" && "${CI:-}" != "true" ]]; then
    if _nredf_bw_secret_configured; then
      _nredf_bw_ensure_session || true
    fi
  fi
  command chezmoi "$@"
}
