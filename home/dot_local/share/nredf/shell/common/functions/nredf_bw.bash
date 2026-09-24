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
_NREDF_BW_MARKER="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/nredf_bw_${_NREDF_BW_ACCOUNT}.active"

# ---------------------------------------------------------------------------
# Internal: helpers for interacting with KWallet via gdbus / D-Bus
# Works natively on KDE Plasma 6 (kwalletd6) and Plasma 5 (kwalletd5).
# ---------------------------------------------------------------------------
_nredf_bw_kwallet_service() {
  command -v gdbus &>/dev/null || return 1
  local s en
  for s in org.kde.kwalletd6 org.kde.kwalletd5 org.kde.kwalletd; do
    en="$(gdbus call --session --dest "${s}" --object-path "/modules/${s##*.}" \
      --method org.kde.KWallet.isEnabled 2>/dev/null)" || true
    if [[ "${en}" == *true* ]]; then
      printf "%s" "${s}"
      return 0
    fi
    if [[ "${en}" == *false* ]]; then
      continue
    fi
    if gdbus call --session --dest "${s}" --object-path "/modules/${s##*.}" \
      --method org.freedesktop.DBus.Peer.Ping 2>/dev/null; then
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
  # Extract numeric handle (gdbus returns '(975485171,)' or '(int32 975485171,)')
  local handle
  handle="$(printf "%s" "${res}" | sed -E 's/.*\(([a-zA-Z0-9]+[[:space:]]+)?(-?[0-9]+).*/\2/')"
  if [[ -n "${handle}" && "${handle}" =~ ^[0-9]+$ && "${handle}" -ge 0 ]]; then
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
  # Every loop/temp variable is declared here, once: undeclared they leak into
  # the interactive shell, and zsh prints `name=value` when a `local` without
  # an assignment is re-run inside a loop.
  local backend token key m w f_item f_raw folder def_w service handle raw mod f
  local -a wallets folders
  backend="$(_nredf_bw_keychain_backend)"

  case "${backend}" in
    macos)
      for key in "${_NREDF_BW_SERVICE}" "bw_session" "BW_SESSION"; do
        token="$(security find-generic-password \
          -s "${key}" \
          -a "${_NREDF_BW_ACCOUNT}" \
          -w 2>/dev/null)" || true
        [[ -n "${token}" ]] && break
      done
      ;;
    kwallet)
      # Primary: native D-Bus via gdbus (Plasma 6 / 5)
      if command -v gdbus &>/dev/null; then
        if service="$(_nredf_bw_kwallet_service)"; then
          mod="/modules/${service##*.}"
          wallets=("kdewallet")
          for m in networkWallet localWallet; do
            def_w="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
              --method "org.kde.KWallet.${m}" 2>/dev/null)" || true
            if [[ "${def_w}" == *\'*\'* ]]; then
              def_w="${def_w#*\'}"
              def_w="${def_w%\'*}"
              if [[ -n "${def_w}" && " ${wallets[*]} " != *" ${def_w} "* ]]; then
                wallets+=("${def_w}")
              fi
            fi
          done

          for w in "${wallets[@]}"; do
            if handle="$(_nredf_bw_kwallet_open "${service}" "${w}")"; then
              folders=("Passwords" "nredf")
              f_raw="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
                --method org.kde.KWallet.folderList "${handle}" 2>/dev/null)" || true
              if [[ -n "${f_raw}" ]]; then
                for f_item in $(printf "%s" "${f_raw}" | tr -d "[],()'"); do
                  if [[ -n "${f_item}" && " ${folders[*]} " != *" ${f_item} "* ]]; then
                    folders+=("${f_item}")
                  fi
                done
              fi

              for folder in "${folders[@]}"; do
                for key in "${_NREDF_BW_SERVICE}" "bw_session" "BW_SESSION" "bitwarden" "Bitwarden" "bw"; do
                  raw="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
                    --method org.kde.KWallet.readPassword "${handle}" "${folder}" "${key}" "nredf" 2>/dev/null)" || true
                  if [[ "${raw}" == *\'*\'* ]]; then
                    token="${raw#*\'}"
                    token="${token%\'*}"
                    if [[ -n "${token}" ]]; then
                      break 3
                    fi
                  fi
                done
              done
            fi
          done
        fi
      fi

      # Fallback: kwallet-query CLI
      if [[ -z "${token}" ]] && command -v kwallet-query &>/dev/null; then
        for folder in "Passwords" "nredf"; do
          for key in "${_NREDF_BW_SERVICE}" "bw_session" "BW_SESSION" "bitwarden" "Bitwarden" "bw"; do
            token="$(kwallet-query --read-password "${key}" --folder "${folder}" kdewallet 2>/dev/null)" || true
            if [[ -n "${token}" && "${token}" != *"kann nicht gelesen werden"* && "${token}" != *"cannot be read"* ]]; then
              break 2
            else
              token=""
            fi
          done
        done
      fi
      ;;
    secret-tool)
      for key in "${_NREDF_BW_SERVICE}" "bw_session"; do
        token="$(secret-tool lookup \
          service "${key}" \
          username "${_NREDF_BW_ACCOUNT}" 2>/dev/null)" || true
        [[ -n "${token}" ]] && break
        token="$(secret-tool lookup \
          service "${key}" 2>/dev/null)" || true
        [[ -n "${token}" ]] && break
      done
      ;;
    fallback)
      f="${XDG_RUNTIME_DIR:-/tmp}/nredf_bw_session"
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
  local backend k service handle mod res has_f f
  local saved=1
  backend="$(_nredf_bw_keychain_backend)"

  case "${backend}" in
    macos)
      for k in "${_NREDF_BW_SERVICE}" "bw_session"; do
        security delete-generic-password \
          -s "${k}" \
          -a "${_NREDF_BW_ACCOUNT}" &>/dev/null || true
        security add-generic-password \
          -s "${k}" \
          -a "${_NREDF_BW_ACCOUNT}" \
          -w "${token}" \
          -U &>/dev/null || true
      done
      ;;
    kwallet)
      # Primary: native D-Bus via gdbus (persists reliably in Plasma 6 & 5)
      if command -v gdbus &>/dev/null; then
        if service="$(_nredf_bw_kwallet_service)"; then
          if handle="$(_nredf_bw_kwallet_open "${service}")"; then
            mod="/modules/${service##*.}"
            # Write to Passwords folder for both nredf.bw_session and bw_session
            for k in "${_NREDF_BW_SERVICE}" "bw_session"; do
              res="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
                --method org.kde.KWallet.writePassword "${handle}" "Passwords" "${k}" "${token}" "nredf" 2>/dev/null)" || true
              [[ "${res}" == *\(0,\)* ]] && saved=0
            done
            if [[ "${saved}" -ne 0 ]]; then
              has_f="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
                --method org.kde.KWallet.hasFolder "${handle}" "nredf" 2>/dev/null)"
              if [[ "${has_f}" != *true* ]]; then
                gdbus call --session --dest "${service}" --object-path "${mod}" \
                  --method org.kde.KWallet.createFolder "${handle}" "nredf" &>/dev/null || true
              fi
              for k in "${_NREDF_BW_SERVICE}" "bw_session"; do
                res="$(gdbus call --session --dest "${service}" --object-path "${mod}" \
                  --method org.kde.KWallet.writePassword "${handle}" "nredf" "${k}" "${token}" "nredf" 2>/dev/null)" || true
                [[ "${res}" == *\(0,\)* ]] && saved=0
              done
            fi
          fi
        fi
      fi

      # Secondary: kwallet-query CLI
      if [[ "${saved}" -ne 0 ]] && command -v kwallet-query &>/dev/null; then
        for k in "${_NREDF_BW_SERVICE}" "bw_session"; do
          printf "%s" "${token}" | kwallet-query --write-password "${k}" --folder "Passwords" kdewallet &>/dev/null \
            || printf "%s" "${token}" | kwallet-query --write-password "${k}" --folder "nredf" kdewallet &>/dev/null || true
        done
      fi
      ;;
    secret-tool)
      for k in "${_NREDF_BW_SERVICE}" "bw_session"; do
        printf "%s" "${token}" | secret-tool store \
          --label "NREDF Bitwarden session" \
          service "${k}" \
          username "${_NREDF_BW_ACCOUNT}" &>/dev/null || true
      done
      ;;
    fallback)
      # Plaintext vault key: create it 0600 from the start (umask 077 in a
      # subshell, so the caller's umask is untouched) and rename it into
      # place, instead of writing it under the caller's umask and chmod-ing
      # afterwards. The rename also replaces, rather than follows, whatever
      # already sits at that path.
      f="${XDG_RUNTIME_DIR:-/tmp}/nredf_bw_session"
      if ! (
        umask 077
        _nredf_bw_tmp="$(mktemp "${f}.XXXXXX")" || exit 1
        if printf "%s" "${token}" >"${_nredf_bw_tmp}" && mv -f "${_nredf_bw_tmp}" "${f}"; then
          exit 0
        fi
        rm -f "${_nredf_bw_tmp}"
        exit 1
      ); then
        printf "Bitwarden: could not write session fallback file %s\n" "${f}" >&2
      fi
      ;;
  esac
  touch "${_NREDF_BW_MARKER}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Internal: remove session token from keychain
# ---------------------------------------------------------------------------
_nredf_bw_keychain_del() {
  local backend key folder service handle mod
  backend="$(_nredf_bw_keychain_backend)"

  case "${backend}" in
    macos)
      for key in "${_NREDF_BW_SERVICE}" "bw_session" "BW_SESSION"; do
        security delete-generic-password \
          -s "${key}" \
          -a "${_NREDF_BW_ACCOUNT}" &>/dev/null || true
      done
      ;;
    kwallet)
      if command -v gdbus &>/dev/null; then
        if service="$(_nredf_bw_kwallet_service)"; then
          if handle="$(_nredf_bw_kwallet_open "${service}")"; then
            mod="/modules/${service##*.}"
            for folder in "Passwords" "nredf"; do
              for key in "${_NREDF_BW_SERVICE}" "bw_session" "BW_SESSION"; do
                gdbus call --session --dest "${service}" --object-path "${mod}" \
                  --method org.kde.KWallet.removeEntry "${handle}" "${folder}" "${key}" "nredf" &>/dev/null || true
              done
            done
          fi
        fi
      fi
      if command -v kwallet-query &>/dev/null; then
        for folder in "Passwords" "nredf"; do
          for key in "${_NREDF_BW_SERVICE}" "bw_session" "BW_SESSION"; do
            kwallet-query --delete-entry "${key}" --folder "${folder}" kdewallet &>/dev/null || true
          done
        done
      fi
      ;;
    secret-tool)
      for key in "${_NREDF_BW_SERVICE}" "bw_session"; do
        secret-tool clear \
          service "${key}" \
          username "${_NREDF_BW_ACCOUNT}" &>/dev/null || true
      done
      ;;
    fallback)
      rm -f "${XDG_RUNTIME_DIR:-/tmp}/nredf_bw_session"
      ;;
  esac
  rm -f "${_NREDF_BW_MARKER}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Internal: detect whether any Bitwarden secret is actually used in config
# Returns 0 if Bitwarden is configured in chezmoi.toml or chezmoidata, 1 otherwise.
# ---------------------------------------------------------------------------
_nredf_bw_secret_configured() {
  local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/chezmoi"
  local c
  for c in \
    "${config_dir}/chezmoi.toml" \
    "${config_dir}/chezmoi.yaml" \
    "${config_dir}/chezmoi.json" \
    "${HOME}/.config/chezmoi/chezmoi.toml" \
    "${HOME}/.config/chezmoi/chezmoi.yaml" \
    "${HOME}/.chezmoi.toml" \
    "${HOME}/.chezmoi.yaml"; do
    if [[ -f "${c}" ]]; then
      if grep -Eq '^[[:blank:]]*\[(data\.)?bitwarden\]' "${c}" 2>/dev/null; then
        return 0
      fi
      if grep -Eq '["'\''[:blank:]](bitwarden|bw):' "${c}" 2>/dev/null; then
        return 0
      fi
      if grep -Eq '\{\{[[:blank:]]*(\([[:blank:]]*)?bitwarden[[:blank:]]' "${c}" 2>/dev/null; then
        return 0
      fi
    fi
  done

  # 2. Check the chezmoi source tree's .chezmoidata. NREDF_DOT_PATH is the
  #    deployed ~/.local/share/nredf tree, never the chezmoi source, so it
  #    can't be used here. Resolve the source dir from chezmoi.toml's
  #    sourceDir, then `chezmoi source-path`, then chezmoi's default. Only
  #    reached from a non-forced _nredf_bw_ensure_session, never at startup,
  #    so forking chezmoi here is acceptable.
  local src d
  local -a src_dirs=()
  if [[ -f "${config_dir}/chezmoi.toml" ]]; then
    src="$(sed -nE 's/^[[:blank:]]*sourceDir[[:blank:]]*=[[:blank:]]*["'\'']([^"'\'']+)["'\''].*/\1/p' \
      "${config_dir}/chezmoi.toml" 2>/dev/null | head -n1)"
    if [[ -n "${src}" ]]; then
      # A literal leading ~/ in the TOML value (not a shell tilde).
      # shellcheck disable=SC2088
      [[ "${src}" == "~/"* ]] && src="${HOME}/${src#"~/"}"
      src_dirs+=("${src}")
    fi
  fi
  if [[ ${#src_dirs[@]} -eq 0 ]] && command -v chezmoi &>/dev/null; then
    src="$(chezmoi source-path 2>/dev/null)" || src=""
    [[ -n "${src}" ]] && src_dirs+=("${src}")
  fi
  src_dirs+=("${XDG_DATA_HOME:-${HOME}/.local/share}/chezmoi")

  for src in "${src_dirs[@]}"; do
    # sourceDir is the repo root; `chezmoi source-path` already includes
    # .chezmoiroot (home/). Check both layouts.
    for d in "${src}" "${src}/home"; do
      if [[ -d "${d}/.chezmoidata" ]] \
        && grep -rEq '["'\''[:blank:]](bitwarden|bw):' "${d}/.chezmoidata" 2>/dev/null; then
        return 0
      fi
      if [[ -f "${d}/.chezmoidata.yaml" ]] \
        && grep -Eq '["'\''[:blank:]](bitwarden|bw):' "${d}/.chezmoidata.yaml" 2>/dev/null; then
        return 0
      fi
    done
  done

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

  local cached
  if cached="$(_nredf_bw_keychain_get 2>/dev/null)" && [[ -n "${cached}" ]]; then
    BW_SESSION="${cached}"
    export BW_SESSION
    touch "${_NREDF_BW_MARKER}" 2>/dev/null || true
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
      _nredf_bw_keychain_set "${BW_SESSION}"
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
  # 1. If BW_SESSION is already set and valid in current shell, sync and return
  if [[ -n "${BW_SESSION:-}" ]] && bw unlock --check &>/dev/null; then
    _nredf_bw_keychain_set "${BW_SESSION}"
    printf "\033[1;32m✔ Bitwarden vault already unlocked (keychain synchronized)\033[0m\n"
    return 0
  fi

  # 2. Check keychain first — if valid, restore without prompting
  local cached_session
  if cached_session="$(_nredf_bw_keychain_get 2>/dev/null)" && [[ -n "${cached_session}" ]]; then
    BW_SESSION="${cached_session}"
    export BW_SESSION
    if bw unlock --check &>/dev/null; then
      _nredf_bw_keychain_set "${BW_SESSION}"
      printf "\033[1;32m✔ Bitwarden vault unlocked from keychain\033[0m\n"
      return 0
    fi
    unset BW_SESSION
    _nredf_bw_keychain_del
  fi

  # 3. Vault is locked — prompt for unlock and persist
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

