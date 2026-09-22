# chezmoi-managed nu function file.
#
# Several files this repo reads (~/.config/nredf/aqua.env, GITHUB.AUTH,
# ~/.proxy.local) are shared with bash/zsh (which `source` them directly)
# and, for aqua.env, PowerShell (whose Defaults.ps1 already parses rather
# than evals it). They are plain `[export] KEY="value"` dotenv files, not nu
# syntax, so nu parses them as data too instead of trying to `source` them
# as code — this only supports that simple shape, not arbitrary shell logic,
# which is the assumption those files' own simple contents already make.

def --env nredf-read-dotenv [file: string] {
    if not ($file | path exists) {
        return
    }
    for line in (open $file | into string | lines) {
        mut l = ($line | str trim)
        if ($l | is-empty) or ($l | str starts-with "#") {
            continue
        }
        $l = ($l | str replace --regex '^export\s+' '')
        if not ($l | str contains "=") {
            continue
        }
        let parts = ($l | split row --number 2 "=")
        let key = ($parts | get 0 | str trim)
        if not ($key =~ '^[A-Za-z_][A-Za-z0-9_]*$') {
            continue
        }
        let val = ($parts | get 1 | str trim | str trim --char '"' | str trim --char "'")
        load-env {($key): $val}
    }
}
