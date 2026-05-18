#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_backup_rc() {
  _nredf_init_paths

  if [[ ! -L "${HOME}/.bashrc" ]]; then
    cp "${HOME}/.bashrc" "${NREDF_CONFIG}/shell/bash/rc"
  fi

  if [[ ! -L "${HOME}/.zshrc" ]]; then
    cp "${HOME}/.zshrc" "${NREDF_CONFIG}/shell/zsh/rc"
  fi
}
