#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_get_sys_info() {
  if [[ -n "${NREDF_OS:-}" && -n "${NREDF_ARCH:-}" && -n "${NREDF_PLATFORM:-}" ]]; then
    return 0
  fi

  local raw_s raw_m s_lower
  read -r raw_s raw_m <<< "$(uname -s -m 2>/dev/null)"
  NREDF_UNAME="${raw_s}"
  NREDF_UNAMEM="${raw_m}"

  s_lower="$(printf '%s' "${raw_s}" | tr '[:upper:]' '[:lower:]')"

  NREDF_UNAME_LOWER="${s_lower}"
  NREDF_UNAMES="${s_lower}"
  NREDF_OS="${s_lower}"

  case ${NREDF_UNAMEM} in
    arm64)
      NREDF_ARCH="arm64"
      ;;
    armv5*)
      NREDF_ARCH="armv5"
      NREDF_LIBC="musleabi"
      ;;
    armv6*)
      NREDF_ARCH="armv6"
      NREDF_LIBC="musl"
      ;;
    armv7*)
      NREDF_ARCH="arm"
      NREDF_LIBC="musleabihf"
      ;;
    aarch64)
      NREDF_ARCH="arm64"
      NREDF_LIBC="musl"
      ;;
    x86)
      NREDF_ARCH="386"
      NREDF_LIBC="musl"
      ;;
    x86_64)
      NREDF_ARCH="amd64"
      NREDF_LIBC="musl"
      ;;
    i686|i386)
      NREDF_ARCH="386"
      NREDF_LIBC="musl"
      ;;
  esac

  case "${NREDF_UNAMES}" in
    msys_nt*|cygwin_nt*|mingw*) NREDF_PLATFORM="pc-windows-msvc" ;;
    linux) NREDF_PLATFORM="unknown-linux-musl" ;;
    darwin) NREDF_PLATFORM="apple-darwin" ;;
    freebsd) NREDF_PLATFORM="unknown-freebsd" ;;
  esac

  case "${NREDF_OS}" in
    mingw*|msys*|cygwin*) NREDF_OS='windows' ;;
    darwin) NREDF_OS='macos' ;;
  esac

  export NREDF_ARCH NREDF_LIBC NREDF_OS NREDF_PLATFORM NREDF_UNAME NREDF_UNAME_LOWER NREDF_UNAMEM NREDF_UNAMES
}

