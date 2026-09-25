#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
#
# fzf-powered pickers, ported to all five shells with identical names and
# behavior. Each is a thin, non-interactive-safe wrapper: it only touches
# fzf's TUI when actually invoked interactively, so none of it runs at
# shell startup.

# Open $EDITOR at a given line number, using the right syntax per editor.
function _nredf_fzf_open_at_line() {
  local file="$1" line="$2"
  local editor="${EDITOR:-vi}"
  case "${editor##*/}" in
    hx | helix)
      "${editor}" "${file}:${line}"
      ;;
    *)
      "${editor}" "+${line}" -- "${file}"
      ;;
  esac
}

# fif <pattern>: ripgrep for a pattern, fzf to pick a match with a bat
# preview centered on the matching line, then open $EDITOR at that line.
function fif() {
  if ! command -v rg &>/dev/null || ! command -v fzf &>/dev/null; then
    echo "commands \"rg\" and \"fzf\" must both exist on system" >&2
    return 1
  fi
  if [[ $# -eq 0 ]]; then
    echo "Usage: fif <pattern>" >&2
    return 1
  fi

  local match
  match=$(rg -n --with-filename --no-heading --color=always "$@" | fzf --ansi --delimiter=: \
    --preview 'bat --style=numbers --color=always --highlight-line={2} -- {1}' \
    --preview-window '+{2}-/2') || return 0
  [[ -z "${match}" ]] && return 0

  local file="${match%%:*}"
  local rest="${match#*:}"
  local line="${rest%%:*}"
  _nredf_fzf_open_at_line "${file}" "${line}"
}

# fe [query]: fd for files, fzf (bat preview) to pick one, open in $EDITOR.
# $query pre-fills fzf's own search box (fzf --query), it is not an fd pattern —
# combine with `FZF_DEFAULT_OPTS='--select-1 --exit-0'` to auto-pick a unique match.
function fe() {
  if ! command -v fd &>/dev/null || ! command -v fzf &>/dev/null; then
    echo "commands \"fd\" and \"fzf\" must both exist on system" >&2
    return 1
  fi

  local file
  file=$(fd --type file --hidden --follow --exclude .git | fzf --ansi --query="${1:-}" \
    --preview 'bat --style=numbers --color=always -- {}') || return 0
  [[ -z "${file}" ]] && return 0

  "${EDITOR:-vi}" -- "${file}"
}

# fbr: list local + remote git branches, fzf to pick one, git switch to it
# (stripping the "remotes/origin/" prefix so a remote branch checks out as
# the equivalent local branch instead of a detached HEAD).
function fbr() {
  if ! command -v git &>/dev/null || ! command -v fzf &>/dev/null; then
    echo "commands \"git\" and \"fzf\" must both exist on system" >&2
    return 1
  fi
  git rev-parse --is-inside-work-tree &>/dev/null || {
    echo "fatal: not a git repository" >&2
    return 1
  }

  # `git branch --all` prefixes every line with a fixed 2-char marker: "* "
  # (current), "+ " (checked out in another worktree) or "  " (neither).
  local branch
  branch=$(git branch --all | grep -v -- '->' | fzf --tac) || return 0
  [[ -z "${branch}" ]] && return 0
  branch="${branch:2}"

  branch="${branch#remotes/origin/}"
  git switch "${branch}"
}

# flog: browse git log --oneline --graph, previewing the selected commit
# with `git show --color | delta` (falls back to plain `git show` if delta
# is missing — delta is aqua-`required` here, but this stays gate-checked
# to keep the function usable during the pre-bootstrap window too).
function flog() {
  if ! command -v git &>/dev/null || ! command -v fzf &>/dev/null; then
    echo "commands \"git\" and \"fzf\" must both exist on system" >&2
    return 1
  fi
  git rev-parse --is-inside-work-tree &>/dev/null || {
    echo "fatal: not a git repository" >&2
    return 1
  }

  local pager="cat"
  command -v delta &>/dev/null && pager="delta"

  git log --oneline --graph --color=always --all |
    fzf --ansi --no-sort --reverse --tiebreak=index \
      --preview "echo {} | grep -oE '[0-9a-f]{7,40}' | head -n1 | xargs -I% git show --color=always % | ${pager}" \
      >/dev/null
}

# fkill [signal]: procs (or ps if procs is missing) -> fzf -m -> kill.
# Signal defaults to 9 (SIGKILL), matching the long-standing fzf-wiki fkill.
function fkill() {
  if ! command -v fzf &>/dev/null; then
    echo "command \"fzf\" does not exist on system" >&2
    return 1
  fi

  local signal="${1:-9}"
  local -a pids=()
  if command -v procs &>/dev/null; then
    mapfile -t pids < <(procs --no-header 2>/dev/null |
      fzf -m --header="kill -${signal}" | awk '{print $1}')
  else
    mapfile -t pids < <(ps -eo pid,user,comm | sed 1d |
      fzf -m --header="kill -${signal}" | awk '{print $1}')
  fi

  ((${#pids[@]})) || return 0
  kill "-${signal}" "${pids[@]}"
}
