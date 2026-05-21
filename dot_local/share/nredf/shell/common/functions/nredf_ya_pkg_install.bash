#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_ya_pkg_install() {
  if _nredf_last_run; then
    return 0
  elif ! _nredf_create_lock; then
    return 0
  fi

  if ! command -v ya &>/dev/null || [[ ! -f "${XDG_CONFIG_HOME}/yazi/package.toml" ]]; then
    _nredf_remove_lock
    return 0
  fi

  echo -e '\033[1mInstalling yazi plugins\033[0m'
  ya pkg install --discard >/dev/null 2>&1 || true
  _nredf_last_run "" "true" "$(($(date +%s) + NREDF_24H_INTERVAL))"
  _nredf_remove_lock
}
