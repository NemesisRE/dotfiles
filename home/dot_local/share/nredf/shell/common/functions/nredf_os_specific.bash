#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_os_specific() {
  case ${NREDF_OS} in
    linux)
      if [[ $(uname -r) =~ WSL2 ]]; then
        export BROWSER="cmd.exe /c start"
      fi
      ;;
    darwin|macos)
      ;;
  esac
}
