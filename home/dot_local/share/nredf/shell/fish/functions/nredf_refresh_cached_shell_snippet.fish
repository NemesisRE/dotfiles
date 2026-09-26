#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# Cached tool-init snippet helper (see AGENTS.md's "startup performance" rule).
# Bash/zsh define this inline in common/rc.tmpl; it lives here instead so it
# joins the rest of the fish function bundle, since fish has no "common" tier
# to share that inline definition with.
#
# Usage: _nredf_refresh_cached_shell_snippet <cache_key> <cache_file> <generator command...>

function _nredf_refresh_cached_shell_snippet
    set -l cache_key $argv[1]
    set -l cache_file $argv[2]
    set -e argv[1..2]

    set -l needs_refresh 1
    if test -s "$cache_file"
        if _nredf_last_run "$cache_key"
            set needs_refresh 0
        end
    end

    if test "$needs_refresh" -eq 1
        set -l cache_dir (path dirname -- "$cache_file")
        test -d "$cache_dir"; or mkdir -p "$cache_dir"
        # Generate into a per-shell temp file and rename it into place only on
        # success: a failing generator then keeps the last good cache, and a
        # concurrently starting shell never sources a half-written file.
        set -l tmp_file "$cache_file.$fish_pid"
        if $argv >"$tmp_file" 2>/dev/null; and test -s "$tmp_file"
            and mv -f "$tmp_file" "$cache_file"
            # An interval (< 1e8) is resolved against "now" by _nredf_last_run
            # itself, which saves a `date` fork here.
            _nredf_last_run "$cache_key" true "$NREDF_24H_INTERVAL"
        else
            rm -f "$tmp_file"
        end
    end

    test -s "$cache_file"; and source "$cache_file"
end
