#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

# mkdir -p the given directory and cd into it in one step.
function mkcd
    if test (count $argv) -eq 0
        echo "Usage: mkcd <dir>" >&2
        return 1
    end

    mkdir -p -- $argv[1]; and cd -- $argv[1]
end
