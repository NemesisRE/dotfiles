#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# "Run at most once per N seconds" throttle gate.
#
# Unlike bash (FUNCNAME) / zsh (funcstack), fish has no caller-introspection
# primitive, so unlike the bash/zsh version the caller must always pass an
# explicit <key> — see docs/shells.md's parity-exceptions section.
#
# Usage: _nredf_last_run <key> [success] [interval_or_next_epoch]

function _nredf_last_run --argument-names key success raw_next
    test -n "$NREDF_LRCACHE"; or _nredf_init_paths

    if test -z "$key"
        echo "_nredf_last_run: missing required <key> argument" >&2
        return 1
    end
    test -n "$success"; or set success false

    set -l last_run_file "$NREDF_LRCACHE/last_run$key.txt"

    # Record success. Rare (once per interval per key), so a `date` fork here
    # is fine — only the check path below runs on every shell start.
    if test "$success" = true
        set -l current_time (date +%s)
        set -l next_run
        if test -z "$raw_next"
            set next_run (math "$current_time + 43200")
        else if test "$raw_next" -lt 100000000
            set next_run (math "$current_time + $raw_next")
        else
            set next_run "$raw_next"
        end
        test -d "$NREDF_LRCACHE"; or mkdir -p "$NREDF_LRCACHE"
        echo "$next_run" >"$last_run_file"
        return 0
    end

    # Check path: runs once per cached snippet on every interactive start, so
    # it uses builtins only (no `date`/`cat` forks). Fish has no epoch
    # builtin, but a file's mtime plus its age (`path mtime --relative`) is
    # exactly "now".
    test -f "$last_run_file"; or return 1

    set -l last_run
    read last_run <"$last_run_file"
    set last_run (string trim -- "$last_run")
    string match -qr '^[0-9]+$' -- "$last_run"; or set last_run 0

    # `path mtime` needs fish >= 3.6; older fish (or a vanished file) falls
    # back to forking `date`.
    set -l mtime
    set -l age
    set -l current_time
    if set mtime (path mtime -- "$last_run_file" 2>/dev/null)
        and set age (path mtime --relative -- "$last_run_file" 2>/dev/null)
        set current_time (math "$mtime + $age")
    else
        set current_time (date +%s)
    end
    if test "$last_run" -gt "$current_time"
        return 0
    end
    return 1
end
