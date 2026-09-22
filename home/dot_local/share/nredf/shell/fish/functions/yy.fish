#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

function yy
    if not type -q yazi
        echo 'command "yazi" does not exist on system' >&2
        return 1
    end

    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    test -n "$tmp"; or return 1

    yazi $argv --cwd-file="$tmp"
    if test -s "$tmp"
        set -l cwd (string trim -- (cat "$tmp"))
        if test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- "$cwd" 2>/dev/null
        end
    end
    rm -f -- "$tmp"
end
