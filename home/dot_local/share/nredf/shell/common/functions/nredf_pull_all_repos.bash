#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_pull_all_repos() {
  local REPO_HOME
  local REMOTE_FILTER
  local REPOSITORIES

  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
      -p|--path)
        if [[ -z ${2} ]]; then
          echo "Error: ${1} needs an argument"
          return 1
        elif [[ ! -d "${2}" ]]; then
          echo "Error: ${1} needs to be a directory"
          return 1
        fi
        REPO_HOME="${2}"
        shift 2
        ;;
      -f|--filter)
        if [[ -z ${2} ]]; then
          echo "Error: needs an argument"
          return 1
        fi
        REMOTE_FILTER="${2}"
        shift 2
        ;;
      *)
        echo "Unknown option: ${1}"
        return 1
        ;;
    esac
  done

  local target_dir="${REPO_HOME:-${HOME}/Repos}"
  echo "Getting all git repositories in ${target_dir}"
  if command -v fd &>/dev/null; then
    REPOSITORIES=$(fd -H -I -t d '^\.git$' "${target_dir}")
  else
    REPOSITORIES=$(find "${target_dir}" -name .git -type d -prune 2>/dev/null)
  fi

  local git_dir REPOSITORY remote_url filter="${REMOTE_FILTER:-github}"
  while IFS= read -r git_dir; do
    [[ -z "${git_dir}" ]] && continue
    REPOSITORY="${git_dir%/.git}"
    remote_url="$(git -C "${REPOSITORY}" config --get remote.origin.url 2>/dev/null)"
    if [[ -z "${remote_url}" ]]; then
      # Fallback to checking any remote if origin is not set
      remote_url="$(git -C "${REPOSITORY}" remote -v 2>/dev/null)"
    fi
    if [[ "${remote_url}" == *"${filter}"* ]]; then
      echo "Updating Git repository in ${REPOSITORY}"
      git -C "${REPOSITORY}" pull --rebase --autostash
    fi
  done <<< "${REPOSITORIES}"
}

