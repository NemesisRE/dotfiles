#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# fzf-powered pickers, ported to all five shells with identical names and
# behavior. Each is a thin, non-interactive-safe wrapper: it only touches
# fzf's TUI when actually invoked interactively, so none of it runs at
# shell startup.

# Open $EDITOR at a given line number, using the right syntax per editor.
function _nredf_fzf_open_at_line
    set -l file $argv[1]
    set -l line $argv[2]
    set -l editor $EDITOR
    test -z "$editor"; and set editor vi

    switch (basename $editor)
        case hx helix
            $editor "$file:$line"
        case '*'
            $editor "+$line" -- $file
    end
end

# fif <pattern>: ripgrep for a pattern, fzf to pick a match with a bat
# preview centered on the matching line, then open $EDITOR at that line.
function fif
    if not type -q rg; or not type -q fzf
        echo 'commands "rg" and "fzf" must both exist on system' >&2
        return 1
    end
    if test (count $argv) -eq 0
        echo "Usage: fif <pattern>" >&2
        return 1
    end

    set -l match (rg -n --with-filename --no-heading --color=always $argv | fzf --ansi --delimiter=: \
        --preview 'bat --style=numbers --color=always --highlight-line={2} -- {1}' \
        --preview-window '+{2}-/2')
    test -z "$match"; and return 0

    set -l parts (string split -m2 ':' -- $match)
    _nredf_fzf_open_at_line $parts[1] $parts[2]
end

# fe [query]: fd for files, fzf (bat preview) to pick one, open in $EDITOR.
# $query pre-fills fzf's own search box (fzf --query), it is not an fd pattern —
# combine with `FZF_DEFAULT_OPTS='--select-1 --exit-0'` to auto-pick a unique match.
function fe
    if not type -q fd; or not type -q fzf
        echo 'commands "fd" and "fzf" must both exist on system' >&2
        return 1
    end

    set -l query $argv[1]
    set -l file (fd --type file --hidden --follow --exclude .git | fzf --ansi --query="$query" \
        --preview 'bat --style=numbers --color=always -- {}')
    test -z "$file"; and return 0

    set -l editor $EDITOR
    test -z "$editor"; and set editor vi
    $editor -- $file
end

# fbr: list local + remote git branches, fzf to pick one, git switch to it
# (stripping the "remotes/origin/" prefix so a remote branch checks out as
# the equivalent local branch instead of a detached HEAD).
function fbr
    if not type -q git; or not type -q fzf
        echo 'commands "git" and "fzf" must both exist on system' >&2
        return 1
    end
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
    or begin
        echo "fatal: not a git repository" >&2
        return 1
    end

    # `git branch --all` prefixes every line with a fixed 2-char marker: "* "
    # (current), "+ " (checked out in another worktree) or "  " (neither).
    set -l branch (git branch --all | grep -v -- '->' | fzf --tac)
    test -z "$branch"; and return 0
    set branch (string sub -s 3 -- $branch)
    set branch (string replace -- 'remotes/origin/' '' $branch)

    git switch $branch
end

# flog: browse git log --oneline --graph, previewing the selected commit
# with `git show --color | delta` (falls back to plain `cat` if delta is
# missing — delta is aqua-`required` here, but this stays gate-checked to
# keep the function usable during the pre-bootstrap window too).
function flog
    if not type -q git; or not type -q fzf
        echo 'commands "git" and "fzf" must both exist on system' >&2
        return 1
    end
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
    or begin
        echo "fatal: not a git repository" >&2
        return 1
    end

    set -l pager cat
    type -q delta; and set pager delta

    git log --oneline --graph --color=always --all | \
        fzf --ansi --no-sort --reverse --tiebreak=index \
            --preview "echo {} | grep -oE '[0-9a-f]{7,40}' | head -n1 | xargs -I% git show --color=always % | $pager" \
            >/dev/null
end

# fkill [signal]: procs (or ps if procs is missing) -> fzf -m -> kill.
# Signal defaults to 9 (SIGKILL), matching the long-standing fzf-wiki fkill.
function fkill
    if not type -q fzf
        echo 'command "fzf" does not exist on system' >&2
        return 1
    end

    set -l signal $argv[1]
    test -z "$signal"; and set signal 9

    set -l pids
    if type -q procs
        set pids (procs --no-header 2>/dev/null | fzf -m --header="kill -$signal" | awk '{print $1}')
    else
        set pids (ps -eo pid,user,comm | sed 1d | fzf -m --header="kill -$signal" | awk '{print $1}')
    end

    test (count $pids) -eq 0; and return 0
    kill "-$signal" $pids
end
