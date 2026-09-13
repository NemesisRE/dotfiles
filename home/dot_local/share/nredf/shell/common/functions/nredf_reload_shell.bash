#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

_nredf_reload_shell () {
  _nredf_init_paths

  local LRCACHE=false
  local DOWNLOADS=false
  local FULL_RELOAD=false
  local PROFILE=false
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -c | --cache)
        LRCACHE=true
        shift 1
      ;;
      -d | --downloads)
        DOWNLOADS=true
        shift 1
      ;;
      -f | --full)
        LRCACHE=true
        FULL_RELOAD=true
        shift 1
      ;;
      -p | --profile)
        PROFILE=true
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
-c, [--cache]               # Delete 'Last Run Cache'
-d, [--downloads]           # Delete aqua pkgs (archives + binaries, keeps bin/ symlinks)
-f, [--full]                # Full refresh: clear caches + chezmoi/aqua/(zsh:sheldon)
-l, [--last-run]            # Delete only 'Last Run Cache'
-p, [--profile]             # Enable startup profiling (with timestamps for each step)
-s SHELL, [--shell SHELL]   # Reload with a different shell
-h, [--help]                # Show this help

"
        return 0
      ;;
      -s | --shell)
        if command -v "${2}" &> /dev/null; then
          NREDF_SHELL_NAME="${2}"
        else
          printf "\033[1;31m✘ Command not found (%s)\033[0m\n" "${2}" >&2
          return 1
        fi
        shift 2
      ;;
      *)
        printf "\033[1;31m✘ Unknown option: %s\033[0m\n" "${1}" >&2
        return 1
      ;;
    esac
  done
  if ${LRCACHE}; then
    rm -rf "${NREDF_LRCACHE:?}"
    rm -rf "${XDG_CACHE_HOME:-${HOME}/.cache}/nredf/init"
    rm -f "${XDG_CACHE_HOME:-${HOME}/.cache}/sheldon/sheldon.zsh"
  fi
  if ${DOWNLOADS}; then
    local _aqua_pkgs="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/aquaproj-aqua}/pkgs"
    if [[ -d "${_aqua_pkgs}" ]]; then
      printf "\033[1mRemoving aqua packages\033[0m\n"
      rm -rf "${_aqua_pkgs:?}"
    fi
    unset _aqua_pkgs
  fi

  if ${FULL_RELOAD}; then
    printf "\033[1mStarting full reload\033[0m\n"
    rm -f "${XDG_CACHE_HOME:-${HOME}/.cache}/sheldon/sheldon.zsh"
    # LRCACHE is cleared above — chezmoi/aqua/sheldon run automatically via normal shell init
  fi


  if ${PROFILE}; then
    export NREDF_PROFILE_STARTUP=1
  fi

  local NREDF_EXEC_SHELL="${NREDF_SHELL_NAME}"
  if [[ "${NREDF_SHELL_NAME}" == "bash" && -n "${BASH:-}" ]]; then
    NREDF_EXEC_SHELL="${BASH}"
  fi

  exec "${NREDF_EXEC_SHELL}"
}
