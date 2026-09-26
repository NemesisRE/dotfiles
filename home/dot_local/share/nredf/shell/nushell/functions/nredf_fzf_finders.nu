# chezmoi-managed nu function file.
#
# fzf-powered pickers, ported to all five shells with identical names and
# behavior. Each is a thin, non-interactive-safe wrapper: it only touches
# fzf's TUI when actually invoked interactively, so none of it runs at
# shell startup.

# Open $EDITOR at a given line number, using the right syntax per editor.
def nredf-fzf-open-at-line [file: string, line: string] {
    let editor = ($env.EDITOR? | default "vi")
    if (($editor | path basename) in ["hx" "helix"]) {
        ^$editor $"($file):($line)"
    } else {
        ^$editor $"+($line)" -- $file
    }
}

# fif <pattern>: ripgrep for a pattern, fzf to pick a match with a bat
# preview centered on the matching line, then open $EDITOR at that line.
def --wrapped fif [...args] {
    if (which rg | is-empty) or (which fzf | is-empty) {
        print --stderr 'commands "rg" and "fzf" must both exist on system'
        return
    }
    if ($args | is-empty) {
        print --stderr "Usage: fif <pattern>"
        return
    }

    let match = (^rg -n --with-filename --no-heading --color=always ...$args
        | ^fzf --ansi --delimiter=:
            --preview 'bat --style=numbers --color=always --highlight-line={2} -- {1}'
            --preview-window '+{2}-/2'
        | str trim)
    if ($match | is-empty) {
        return
    }

    let i1 = ($match | str index-of ':')
    let rest = ($match | str substring ($i1 + 1)..)
    let i2 = ($rest | str index-of ':')
    let file = ($match | str substring 0..<$i1)
    let line = ($rest | str substring 0..<$i2)
    nredf-fzf-open-at-line $file $line
}

# fe [query]: fd for files, fzf (bat preview) to pick one, open in $EDITOR.
# $query pre-fills fzf's own search box (fzf --query), it is not an fd pattern —
# combine with `FZF_DEFAULT_OPTS='--select-1 --exit-0'` to auto-pick a unique match.
def fe [query?: string] {
    if (which fd | is-empty) or (which fzf | is-empty) {
        print --stderr 'commands "fd" and "fzf" must both exist on system'
        return
    }

    let q = ($query | default "")
    let file = (^fd --type file --hidden --follow --exclude .git
        | ^fzf --ansi $"--query=($q)" --preview 'bat --style=numbers --color=always -- {}'
        | str trim)
    if ($file | is-empty) {
        return
    }

    let editor = ($env.EDITOR? | default "vi")
    ^$editor -- $file
}

# fbr: list local + remote git branches, fzf to pick one, git switch to it
# (stripping the "remotes/origin/" prefix so a remote branch checks out as
# the equivalent local branch instead of a detached HEAD).
def fbr [] {
    if (which git | is-empty) or (which fzf | is-empty) {
        print --stderr 'commands "git" and "fzf" must both exist on system'
        return
    }
    if (^git rev-parse --is-inside-work-tree | complete).exit_code != 0 {
        print --stderr "fatal: not a git repository"
        return
    }

    # `git branch --all` prefixes every line with a fixed 2-char marker: "* "
    # (current), "+ " (checked out in another worktree) or "  " (neither).
    let branch = (^git branch --all | ^grep -v -- '->' | ^fzf --tac | str trim)
    if ($branch | is-empty) {
        return
    }

    let b = ($branch | str substring 2.. | str replace "remotes/origin/" "")
    ^git switch $b
}

# flog: browse git log --oneline --graph, previewing the selected commit
# with `git show --color | delta` (falls back to plain `cat` if delta is
# missing — delta is aqua-`required` here, but this stays gate-checked to
# keep the function usable during the pre-bootstrap window too).
def flog [] {
    if (which git | is-empty) or (which fzf | is-empty) {
        print --stderr 'commands "git" and "fzf" must both exist on system'
        return
    }
    if (^git rev-parse --is-inside-work-tree | complete).exit_code != 0 {
        print --stderr "fatal: not a git repository"
        return
    }

    let pager = if (which delta | is-empty) { "cat" } else { "delta" }
    let preview_cmd = $"echo {} | grep -oE '[0-9a-f]{7,40}' | head -n1 | xargs -I% git show --color=always % | ($pager)"

    ^git log --oneline --graph --color=always --all
        | ^fzf --ansi --no-sort --reverse --tiebreak=index --preview $preview_cmd
        | ignore
}

# fkill [signal]: procs (or ps if procs is missing) -> fzf -m -> kill.
# Signal defaults to 9 (SIGKILL), matching the long-standing fzf-wiki fkill.
def fkill [signal?: string] {
    if (which fzf | is-empty) {
        print --stderr 'command "fzf" does not exist on system'
        return
    }

    let sig = ($signal | default "9")
    let pids = if (which procs | is-empty) {
        (^ps -eo pid,user,comm | ^sed 1d | ^fzf -m $"--header=kill -($sig)" | ^awk '{print $1}' | lines)
    } else {
        (^procs --no-header | ^fzf -m $"--header=kill -($sig)" | ^awk '{print $1}' | lines)
    }

    if ($pids | is-empty) {
        return
    }
    ^kill $"-($sig)" ...$pids
}
