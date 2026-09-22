#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# mkdir-based mutex lock with stale-lock (PID liveness) detection.
#
# Unlike bash/zsh, fish has no caller-introspection primitive, so the caller
# must always pass an explicit <key> — see docs/shells.md's parity-exceptions
# section.

function _nredf_create_lock --argument-names key
    _nredf_init_paths

    if test -z "$key"
        echo "_nredf_create_lock: missing required <key> argument" >&2
        return 1
    end

    test -d "$NREDF_LKCACHE"; or mkdir -p "$NREDF_LKCACHE"
    set -l lock_dir "$NREDF_LKCACHE/$key.lock"

    if mkdir "$lock_dir" 2>/dev/null
        echo $fish_pid >"$lock_dir/pid" 2>/dev/null
        return 0
    end

    # Check for a stale lock: if the holding process is dead, break the lock.
    set -l lock_pid
    if test -f "$lock_dir/pid"
        set lock_pid (string trim -- (cat "$lock_dir/pid" 2>/dev/null))
        if test -n "$lock_pid"; and not kill -0 "$lock_pid" 2>/dev/null
            rm -rf "$lock_dir"
            if mkdir "$lock_dir" 2>/dev/null
                echo $fish_pid >"$lock_dir/pid" 2>/dev/null
                return 0
            end
        end
    end

    return 1
end

function _nredf_remove_lock --argument-names key
    _nredf_init_paths

    if test -z "$key"
        echo "_nredf_remove_lock: missing required <key> argument" >&2
        return 1
    end

    set -l lock_dir "$NREDF_LKCACHE/$key.lock"
    rm -rf "$lock_dir"
    # Clean up legacy .lock files if present.
    rm -f "$NREDF_LKCACHE/$key.lock"
end
