# chezmoi-managed nu function file.
#
# Opt-in startup profiler (NREDF_PROFILE_STARTUP=1, toggled via `reload -p`).
# Unlike bash/fish, nu has a native nanosecond-precision clock (`date now`),
# so this needs no external-`date` fallback.

def nredf-now-ns []: nothing -> int {
    date now | format date "%s%f" | into int
}

def --env nredf-profile-init [] {
    if (($env.NREDF_PROFILE_STARTUP? | default "0") == "1") {
        let t0 = (nredf-now-ns)
        $env.NREDF_T0 = $t0
        $env.NREDF_T_LAST = $t0
    }
}

def --env nredf-step [label: string] {
    if (($env.NREDF_PROFILE_STARTUP? | default "0") != "1") {
        return
    }
    let now = (nredf-now-ns)
    let elapsed_ms = (($now - ($env.NREDF_T_LAST? | default $now)) / 1_000_000)
    print --stderr $"\e[2m  [+(($elapsed_ms | into int) | fill --alignment right --character ' ' --width 4)ms] ($label)\e[0m"
    $env.NREDF_T_LAST = $now
}

def --env nredf-profile-finish [] {
    if (($env.NREDF_PROFILE_STARTUP? | default "0") != "1") {
        return
    }
    if (($env.NREDF_PROFILE_FINISHED? | default "0") == "1") {
        return
    }
    $env.NREDF_PROFILE_FINISHED = "1"

    if not ($env.NREDF_T0? | is-empty) {
        let now = (nredf-now-ns)
        let total_ms = (($now - $env.NREDF_T0) / 1_000_000)
        print --stderr $"\e[1;36m  [+(($total_ms | into int) | fill --alignment right --character ' ' --width 4)ms] Total shell startup time\e[0m"
    }

    if (($env.NREDF_PROFILE_STARTUP_ONESHOT? | default "0") == "1") {
        hide-env NREDF_PROFILE_STARTUP
        hide-env NREDF_PROFILE_STARTUP_ONESHOT
    }
}
