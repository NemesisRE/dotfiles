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

    set -l current_time (date +%s)

    set -l interval 43200
    set -l next_run
    if test -z "$raw_next"
        set next_run (math "$current_time + 43200")
    else if test "$raw_next" -lt 100000000
        set interval "$raw_next"
        set next_run (math "$current_time + $raw_next")
    else
        set next_run "$raw_next"
        set interval (math "$raw_next - $current_time")
        test "$interval" -le 0; and set interval 1
    end

    set -l last_run_file "$NREDF_LRCACHE/last_run$key.txt"

    # Fast path for recording success.
    if test "$success" = true
        test -d "$NREDF_LRCACHE"; or mkdir -p "$NREDF_LRCACHE"
        echo "$next_run" >"$last_run_file"
        return 0
    end

    test -f "$last_run_file"; or return 1

    set -l last_run (string trim -- (cat "$last_run_file" 2>/dev/null))
    string match -qr '^[0-9]+$' -- "$last_run"; or set last_run 0

    if test "$last_run" -gt "$current_time"
        return 0
    end
    return 1
end
