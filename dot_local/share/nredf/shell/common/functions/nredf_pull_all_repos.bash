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

  echo "Getting all git Repositories in ${REPO_HOME:-${HOME}/Repos}"
  REPOSITORIES=$(find "${REPO_HOME:-${HOME}/Repos}" -type d -exec git -C {} rev-parse --show-toplevel \; 2>/dev/null | uniq)

  while IFS= read -r REPOSITORY; do
    if git -C "${REPOSITORY}" remote -v | grep -q "${REMOTE_FILTER:-github}" &>/dev/null; then
      echo "Updating Git repository in ${REPOSITORY}"
      git -C "${REPOSITORY}" pull --rebase --autostash
    fi
  done <<< "${REPOSITORIES}"
}
