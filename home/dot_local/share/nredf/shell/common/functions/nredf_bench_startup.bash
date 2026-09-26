#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
#
# Benchmark interactive startup time of every installed shell with hyperfine.
# `<shell> -i -c exit` is hyperfine's own documented idiom for measuring
# interactive shell startup: `-i` forces PS1 to be set (bash/zsh/fish/nu all
# gate their rc/config loading on being interactive), so the full rc chain
# — including this very function bundle — actually runs, then `-c exit`
# exits immediately instead of waiting on a prompt.
function nredf_bench_startup() {
  if ! command -v hyperfine &>/dev/null; then
    echo "command \"hyperfine\" does not exist on system" >&2
    return 1
  fi

  local -a shell_cmds=()
  local sh
  for sh in bash zsh fish nu pwsh; do
    command -v "${sh}" &>/dev/null || continue
    if [[ "${sh}" == "pwsh" ]]; then
      shell_cmds+=(-n "${sh}" "pwsh -NoLogo -Command exit")
    else
      shell_cmds+=(-n "${sh}" "${sh} -i -c exit")
    fi
  done

  if ((${#shell_cmds[@]} == 0)); then
    echo "none of bash/zsh/fish/nu/pwsh found on PATH" >&2
    return 1
  fi

  # -w 3: warm caches (cached-snippet files, sheldon/zcompile, etc.) before
  # timing. -N: run each command directly, without an extra shell wrapper
  # around the shell being benchmarked. "$@" lets callers override either,
  # e.g. `nredf_bench_startup --runs 1` for a quick smoke test.
  hyperfine -w 3 -N "$@" "${shell_cmds[@]}"
}
