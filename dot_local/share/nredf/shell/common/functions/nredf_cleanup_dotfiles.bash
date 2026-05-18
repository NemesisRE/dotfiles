#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_cleanup_dotfiles() {
  if [[ "${NREDF_OS}" == "linux" ]]; then
    if _nredf_last_run; then
      return 0
    elif ! _nredf_create_lock; then
      return 0
    fi

    echo -e '\033[1mSearch and delete broken symlinks\033[0m'
    if find . -xtype l &>/dev/null; then
      find "${HOME}" -maxdepth 1 -iname ".*" -print0 | xargs -0 -I"{.}" find "{.}" -xtype l -delete
    else
      find "${HOME}" -maxdepth 1 -iname ".*" -print0 | xargs -0 -I"{.}" find "{.}" -type l ! -exec test -e {} \; -delete
    fi

    _nredf_last_run "" "true"
    _nredf_remove_lock
  fi
}
