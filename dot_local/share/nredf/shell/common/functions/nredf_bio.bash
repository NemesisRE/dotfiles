#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_bio() {
  currentShell="$(cat /proc/$$/cmdline | tr "\0" " " | awk '{print $1}')"
  shellName="${currentShell##*/}"
  printf '\e[1;34m%-6s\e[m' "${shellName^} programmer"
}
