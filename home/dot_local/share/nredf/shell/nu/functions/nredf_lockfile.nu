# chezmoi-managed nu function file.
#
# mkdir-based mutex lock with stale-lock (PID liveness) detection. Like
# nredf-last-run, nu has no caller-introspection primitive, so the caller
# must always pass an explicit <key> — see docs/shells.md's parity-exceptions
# section.

def nredf-create-lock [key: string]: nothing -> bool {
    if ($env.NREDF_LKCACHE? | is-empty) {
        nredf-init-paths
    }

    if not ($env.NREDF_LKCACHE | path exists) {
        mkdir $env.NREDF_LKCACHE
    }
    let lock_dir = ($env.NREDF_LKCACHE | path join $"($key).lock")

    if (nredf-try-mkdir $lock_dir) {
        $nu.pid | into string | save --force ($lock_dir | path join "pid")
        return true
    }

    # Check for a stale lock: if the holding process is dead, break the lock.
    let pid_file = ($lock_dir | path join "pid")
    if ($pid_file | path exists) {
        let lock_pid = (open $pid_file | into string | str trim)
        if (not ($lock_pid | is-empty)) and (not (nredf-pid-alive $lock_pid)) {
            rm --recursive --force $lock_dir
            if (nredf-try-mkdir $lock_dir) {
                $nu.pid | into string | save --force $pid_file
                return true
            }
        }
    }

    false
}

def nredf-remove-lock [key: string] {
    if ($env.NREDF_LKCACHE? | is-empty) {
        nredf-init-paths
    }
    let lock_dir = ($env.NREDF_LKCACHE | path join $"($key).lock")
    rm --recursive --force $lock_dir
}

# nu's own `mkdir` builtin is always idempotent (like bash's `mkdir -p`) and
# so cannot serve as an atomic "did I just create this" mutex primitive —
# shell out to the real `mkdir` binary instead, which fails on an existing
# directory exactly like bash's non-`-p` `mkdir` that the lock relies on.
def nredf-try-mkdir [dir: string]: nothing -> bool {
    (^mkdir $dir | complete | get exit_code) == 0
}

def nredf-pid-alive [pid: string]: nothing -> bool {
    (^kill -0 $pid | complete | get exit_code) == 0
}
