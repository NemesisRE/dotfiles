#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

# Print $PATH, one entry per line.
#
# In zsh, oh-my-zsh's systemadmin plugin (sheldon, lazy-loaded on the first
# precmd) already defines `alias path='print -l $path'` — functionally the
# same output this produces — and that alias wins for interactive zsh
# sessions since it is defined after this file loads. See
# docs/shells.md's "Known Parity Exceptions": fixing the load order would
# mean editing sheldon's plugin list or its lazy-load hook, both existing
# files outside this change. Bash has no oh-my-zsh, so it always uses the
# function below.
function path() {
  local -a entries
  IFS=':' read -r -a entries <<<"${PATH}"
  printf '%s\n' "${entries[@]}"
}
