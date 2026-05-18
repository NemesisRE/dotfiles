#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_is_macos_arm64() {
  [[ "${NREDF_OS}" == "macos" && "${NREDF_UNAMEM}" == "arm64" ]]
}

function _nredf_asset_arch() {
  case "${1}" in
    archive)
      printf '%s\n' "${NREDF_ARCH}"
      ;;
    machine)
      printf '%s\n' "${NREDF_UNAMEM}"
      ;;
    rust)
      if _nredf_is_macos_arm64; then
        printf 'aarch64\n'
      else
        printf '%s\n' "${NREDF_UNAMEM}"
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

function _nredf_asset_os() {
  case "${1}" in
    uname)
      printf '%s\n' "${NREDF_UNAME}"
      ;;
    uname-lower)
      printf '%s\n' "${NREDF_UNAME_LOWER}"
      ;;
    darwin-lower)
      if [[ "${NREDF_OS}" == "macos" ]]; then
        printf 'darwin\n'
      else
        printf '%s\n' "${NREDF_UNAME_LOWER}"
      fi
      ;;
    macos-release)
      if [[ "${NREDF_OS}" == "macos" ]]; then
        printf 'macOS\n'
      else
        printf '%s\n' "${NREDF_UNAME_LOWER}"
      fi
      ;;
    os)
      printf '%s\n' "${NREDF_OS}"
      ;;
    helix)
      if [[ "${NREDF_OS}" == "macos" ]]; then
        printf 'macos\n'
      else
        printf '%s\n' "${NREDF_OS}"
      fi
      ;;
    *)
      return 1
      ;;
  esac
}
