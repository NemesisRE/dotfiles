#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# Universal archive extract/compress via ouch (https://github.com/ouch-org/ouch),
# which auto-detects format from the file extension so one function covers
# zip/tar/tar.gz/tar.zst/7z/rar/... instead of a per-format case statement.
# Fish has no oh-my-zsh-style plugin manager, so there is no `extract`/`x`
# to contend with here the way zsh has (see common/functions/nredf_extract.bash).

function extract
    if not type -q ouch
        echo 'command "ouch" does not exist on system' >&2
        return 1
    end
    if test (count $argv) -eq 0
        echo "Usage: extract <archive>..." >&2
        return 1
    end

    ouch decompress $argv
end

function x
    extract $argv
end

function compress
    if not type -q ouch
        echo 'command "ouch" does not exist on system' >&2
        return 1
    end
    if test (count $argv) -lt 2
        echo "Usage: compress <out> <files...>" >&2
        return 1
    end

    set -l out $argv[1]
    set -e argv[1]
    ouch compress $argv $out
end
