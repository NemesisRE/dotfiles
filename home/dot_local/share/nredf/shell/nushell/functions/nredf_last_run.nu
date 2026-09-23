# chezmoi-managed nu function file.
#
# "Run at most once per N seconds" throttle gate. Unlike bash (FUNCNAME) /
# zsh (funcstack), nu closures have no caller-introspection primitive, so
# unlike the bash/zsh version the caller must always pass an explicit <key>
# — see docs/shells.md's parity-exceptions section. This is a plain (non
# --env) def: it only touches the filesystem, never shell-global state.
#
# Usage: nredf-last-run <key> [--success] [--next N]

def nredf-last-run [key: string, --success, --next: int = 0]: nothing -> bool {
    if ($env.NREDF_LRCACHE? | is-empty) {
        nredf-init-paths
    }

    let current_time = (date now | format date "%s" | into int)

    mut interval = 43200
    mut next_run = 0
    if $next == 0 {
        $next_run = $current_time + 43200
    } else if $next < 100_000_000 {
        $interval = $next
        $next_run = $current_time + $next
    } else {
        $next_run = $next
        $interval = $next - $current_time
        if $interval <= 0 { $interval = 1 }
    }

    let last_run_file = ($env.NREDF_LRCACHE | path join $"last_run($key).txt")

    if $success {
        if not ($env.NREDF_LRCACHE | path exists) {
            mkdir $env.NREDF_LRCACHE
        }
        $next_run | save --force $last_run_file
        return true
    }

    if not ($last_run_file | path exists) {
        return false
    }

    let last_run = (open $last_run_file | into string | str trim | into int)
    $last_run > $current_time
}
