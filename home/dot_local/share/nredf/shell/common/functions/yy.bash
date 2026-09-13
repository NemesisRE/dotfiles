#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function yy() {
  if ! command -v yazi &>/dev/null; then
    echo "command \"yazi\" does not exist on system" >&2
    return 1
  fi

  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return 1

  yazi "${@}" --cwd-file="${tmp}"
  if [[ -s "${tmp}" ]] && cwd="$(< "${tmp}")" && [[ -n "${cwd}" && "${cwd}" != "${PWD}" ]]; then
    builtin cd -- "${cwd}" || true
  fi
  rm -f -- "${tmp}"
}

