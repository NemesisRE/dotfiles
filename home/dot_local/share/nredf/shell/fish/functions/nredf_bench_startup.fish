#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# Benchmark interactive startup time of every installed shell with hyperfine.
# `<shell> -i -c exit` is hyperfine's own documented idiom for measuring
# interactive shell startup: `-i` forces PS1/interactive-mode to be set so
# the full rc/config chain actually runs, then `-c exit` exits immediately
# instead of waiting on a prompt.
function nredf_bench_startup
    if not type -q hyperfine
        echo 'command "hyperfine" does not exist on system' >&2
        return 1
    end

    set -l shell_cmds
    for sh in bash zsh fish nu pwsh
        type -q $sh; or continue
        if test "$sh" = pwsh
            set -a shell_cmds -n $sh "pwsh -NoLogo -Command exit"
        else
            set -a shell_cmds -n $sh "$sh -i -c exit"
        end
    end

    if test (count $shell_cmds) -eq 0
        echo "none of bash/zsh/fish/nu/pwsh found on PATH" >&2
        return 1
    end

    # -w 3: warm caches before timing. -N: run each command directly, no
    # extra shell wrapper. $argv lets callers override either, e.g.
    # `nredf_bench_startup --runs 1` for a quick smoke test.
    hyperfine -w 3 -N $argv $shell_cmds
end
