#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

_nredf_reload_shell () {
  _nredf_init_paths

  local LRCACHE=false
  local DOWNLOADS=false
  local FULL_RELOAD=false
  local PROFILE=false
  local HAS_OTHER_OPTIONS=false
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -c | --cache)
        LRCACHE=true
        HAS_OTHER_OPTIONS=true
        shift 1
      ;;
      -d | --downloads)
        DOWNLOADS=true
        HAS_OTHER_OPTIONS=true
        shift 1
      ;;
      -f | --full)
        LRCACHE=true
        FULL_RELOAD=true
        HAS_OTHER_OPTIONS=true
        shift 1
      ;;
      -p | --profile)
        PROFILE=true
        shift 1
      ;;
      -l | --last-run)
        LRCACHE=true
        HAS_OTHER_OPTIONS=true
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
-p, [--profile]             # Toggle startup profiling (or one-shot if combined with other options)
-s SHELL, [--shell SHELL]   # Reload with a different shell
-h, [--help]                # Show this help

"
        return 0
      ;;
      -s | --shell)
        HAS_OTHER_OPTIONS=true
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
    rm -f "${XDG_CACHE_HOME:-${HOME}/.cache}/sheldon/sheldon.zsh"*
    rm -f "${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/.zcompdump"*
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
    if command -v nredf-daily-sync >/dev/null 2>&1; then
      nredf-daily-sync --verbose || true
    fi
  fi


  if ${PROFILE}; then
    if ! ${HAS_OTHER_OPTIONS}; then
      if [[ "${NREDF_PROFILE_STARTUP:-0}" == "1" ]]; then
        unset NREDF_PROFILE_STARTUP NREDF_PROFILE_STARTUP_ONESHOT
        printf "\033[1;33mℹ Startup profiling disabled\033[0m\n"
      else
        export NREDF_PROFILE_STARTUP=1
        unset NREDF_PROFILE_STARTUP_ONESHOT
        printf "\033[1;32mℹ Startup profiling enabled (persistent)\033[0m\n"
      fi
    else
      export NREDF_PROFILE_STARTUP=1
      export NREDF_PROFILE_STARTUP_ONESHOT=1
    fi
  fi

  local NREDF_EXEC_SHELL="${NREDF_SHELL_NAME}"
  local NREDF_EXEC_ARGS=()
  if [[ "${NREDF_SHELL_NAME}" == "bash" && -n "${BASH:-}" ]]; then
    NREDF_EXEC_SHELL="${BASH}"
  elif [[ "${NREDF_SHELL_NAME}" == "pwsh" || "${NREDF_SHELL_NAME}" == "powershell" ]]; then
    NREDF_EXEC_ARGS+=("-NoLogo")
  fi

  exec "${NREDF_EXEC_SHELL}" "${NREDF_EXEC_ARGS[@]}"
}
