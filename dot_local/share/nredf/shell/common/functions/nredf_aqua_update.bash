#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
#
# Replaces nredf_install_tools_default: uses aqua install (throttled to once per 12h)

function _nredf_aqua_update() {
  # Check throttle: skip if last run was < 12h ago
  if _nredf_last_run; then
    return 0
  elif ! _nredf_create_lock; then
    return 0
  fi

  if ! command -v aqua &>/dev/null; then
    _nredf_remove_lock
    return 0
  fi

  echo -e '\033[1mLooking for fresh batteries\033[0m'
  aqua install || true

  _nredf_last_run "" "true"  # default 12h throttle
  _nredf_remove_lock
}
