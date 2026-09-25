# chezmoi-managed nu function file.
#
# Benchmark interactive startup time of every installed shell with hyperfine.
# `<shell> -i -c exit` is hyperfine's own documented idiom for measuring
# interactive shell startup: `-i` forces interactive mode so the full
# rc/config chain actually runs (nu itself only loads env.nu/config.nu when
# `$nu.is-interactive` is true — see docs/shells.md), then `-c exit` exits
# immediately instead of waiting on a prompt.
#
# Named `nredf-bench-startup` (kebab-case), not `nredf_bench_startup`, to
# match this file's own internal-helper naming convention — see
# docs/shells.md's note on nu's kebab-case vs. bash/zsh/fish/PowerShell's
# `nredf_`/`NREDF_` conventions.

def --wrapped nredf-bench-startup [...args] {
    if (which hyperfine | is-empty) {
        print --stderr 'command "hyperfine" does not exist on system'
        return
    }

    mut shell_args = []
    for sh in [bash zsh fish nu pwsh] {
        if (which $sh | is-empty) {
            continue
        }
        let cmd = if $sh == "pwsh" { "pwsh -NoLogo -Command exit" } else { $"($sh) -i -c exit" }
        $shell_args = ($shell_args | append [-n $sh $cmd])
    }

    if ($shell_args | is-empty) {
        print --stderr "none of bash/zsh/fish/nu/pwsh found on PATH"
        return
    }

    ^hyperfine -w 3 -N ...$args ...$shell_args
}
