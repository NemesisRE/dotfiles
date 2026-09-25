#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

# List listening TCP ports. Prefers `ss` (Linux, iproute2), falls back to
# `lsof` (macOS/BSD, and any Linux without iproute2), then to `netstat`
# (present on most systems including Git-Bash/WSL, even though deprecated
# on native Linux) so this also works for bash/zsh hosted on Windows.
function ports() {
  if command -v ss &>/dev/null; then
    ss -tlnp 2>/dev/null || ss -tln
  elif command -v lsof &>/dev/null; then
    lsof -nP -iTCP -sTCP:LISTEN
  elif command -v netstat &>/dev/null; then
    netstat -an | grep -i listen
  else
    echo "none of \"ss\", \"lsof\" or \"netstat\" exist on system" >&2
    return 1
  fi
}
