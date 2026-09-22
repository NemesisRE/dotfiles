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
        mkdir -p (path dirname -- "$cache_file")
        if $argv >"$cache_file" 2>/dev/null
            set -l now (date +%s)
            _nredf_last_run "$cache_key" true (math "$now + $NREDF_24H_INTERVAL")
        else
            rm -f "$cache_file"
        end
    end

    test -s "$cache_file"; and source "$cache_file"
end
