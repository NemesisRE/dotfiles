#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
#
# Universal archive extract/compress via ouch (https://github.com/ouch-org/ouch),
# which auto-detects format from the file extension so one function covers
# zip/tar/tar.gz/tar.zst/7z/rar/... instead of a per-format case statement.
#
# In zsh, oh-my-zsh's `extract` plugin (sheldon, lazy-loaded on the first
# precmd — see nredf_sheldon.zsh) defines its own `extract` function and
# `alias x=extract` *after* this file has already loaded, so it wins for
# interactive zsh sessions. See docs/shells.md's "Known Parity Exceptions"
# for why that isn't fixed here (it would mean editing sheldon's plugin
# list or its lazy-load hook, both existing files outside this change).
# Bash (no oh-my-zsh) always gets the ouch-based version below.

function extract() {
  if ! command -v ouch &>/dev/null; then
    echo "command \"ouch\" does not exist on system" >&2
    return 1
  fi
  if [[ $# -eq 0 ]]; then
    echo "Usage: extract <archive>..." >&2
    return 1
  fi

  ouch decompress "$@"
}

# Short alias name, matching ouch's own `ouch d`/`ouch c` convention and the
# oh-my-zsh `x` alias this is meant to parallel.
function x() {
  extract "$@"
}

function compress() {
  if ! command -v ouch &>/dev/null; then
    echo "command \"ouch\" does not exist on system" >&2
    return 1
  fi
  if [[ $# -lt 2 ]]; then
    echo "Usage: compress <out> <files...>" >&2
    return 1
  fi

  local out="$1"
  shift
  ouch compress "$@" "${out}"
}
