#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_os_specific() {
  case ${NREDF_OS} in
    linux)
      if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]]; then
        export BROWSER="cmd.exe /c start"
      elif [[ -f /proc/version ]] && grep -qi "microsoft" /proc/version 2>/dev/null; then
        export BROWSER="cmd.exe /c start"
      fi
      ;;
    darwin|macos)
      ;;

  esac
}
