#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_get_sys_info() {
  NREDF_UNAME="$(uname)"
  NREDF_UNAME_LOWER="$(uname -s | tr '[:upper:]' '[:lower:]')"
  NREDF_UNAMEM=$(uname -m)
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
    i686)
      NREDF_ARCH="386"
      NREDF_LIBC="musl"
      ;;
    i386)
      NREDF_ARCH="386"
      NREDF_LIBC="musl"
      ;;
  esac

  NREDF_UNAMES="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "${NREDF_UNAMES}" in
    msys_nt*) NREDF_PLATFORM="pc-windows-msvc" ;;
    cygwin_nt*) NREDF_PLATFORM="pc-windows-msvc";;
    mingw*) NREDF_PLATFORM="pc-windows-msvc" ;;
    linux) NREDF_PLATFORM="unknown-linux-musl" ;;
    darwin) NREDF_PLATFORM="apple-darwin" ;;
    freebsd) NREDF_PLATFORM="unknown-freebsd" ;;
  esac

  NREDF_OS=$(uname|tr '[:upper:]' '[:lower:]')
  case "${NREDF_OS}" in
    mingw*) NREDF_OS='windows';;
    darwin) NREDF_OS='macos';;
  esac

  export NREDF_ARCH NREDF_LIBC NREDF_OS NREDF_PLATFORM NREDF_UNAME NREDF_UNAME_LOWER NREDF_UNAMEM NREDF_UNAMES
}
