#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

# mkdir -p the given directory and cd into it in one step.
function mkcd() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: mkcd <dir>" >&2
    return 1
  fi

  mkdir -p -- "$1" && cd -- "$1" || return 1
}
