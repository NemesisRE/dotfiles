#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

_nredf_reload_shell () {
  _nredf_init_paths

  local LRCACHE=false
  local GHCACHE=false
  local DOWNLOADS=false
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -c | --cache)
        LRCACHE=true
        GHCACHE=true
        shift 1
      ;;
      -d | --downloads)
        DOWNLOADS=true
        shift 1
      ;;
      -f | --full)
        LRCACHE=true
        GHCACHE=true
        DOWNLOADS=true
        shift 1
      ;;
      -l | --last-run)
        LRCACHE=true
        shift 1
      ;;
      -h | --help)
        printf "NREDF Reload

Usage: reload [options]

Options:
-c, [--cache]               # Delete 'Last Run Cache' and 'Version Cache'
-d, [--downloads]           # Delete only 'Download Cache'
-f, [--full]                # Delete all caches
-l, [--last-run]            # Delete only 'Last Run Cache'
-h, [--help]                # Show this help
-s SHELL, [--shell SHELL]   # Reload with a different shell
-v, [--version]             # Delete only 'Version Cache'

"
        return 0
      ;;
      -s | --shell)
        if command -pv "${2}" &> /dev/null; then
          NREDF_SHELL_NAME="${2}"
        else
          echo -e "\033[1;31m\U274C Command not found (${2}) \033[0m"
          return 1
        fi;
        shift 2
      ;;
      -v | --version)
        GHCACHE=true
        shift 1
      ;;
      *)
        echo -e "\033[1;31m\U274C Unknown option: ${1} \033[0m"
        return 1
      ;;
    esac
  done
  if ${LRCACHE}; then
    rm -rf "${NREDF_LRCACHE:?}"
  fi
  if ${GHCACHE}; then
    rm -rf "${NREDF_GHCACHE:?}"
  fi
  if ${DOWNLOADS}; then
    rm -rf "${NREDF_DOWNLOADS:?}"
  fi
  exec "${NREDF_SHELL_NAME}"
}
