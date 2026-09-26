# chezmoi-managed nu function file.
# -----------------------------------------------------------------------------
# SSH wrapper with Bitwarden / 1Password TOTP and sshpass.
#
# Port of common/functions/nredf_ssh.bash — see that file for the full design
# writeup and SSH config example (SetEnv TOTP_ITEMID=<id>).
# -----------------------------------------------------------------------------

# Reuses the same awk one-liner bash does rather than hand-rolling this
# parsing in nu pipelines — lower-risk for a first port (see the
# implementation plan); a native-nu rewrite can happen later as a cleanup.
def nredf-parse-totp [cfg: string]: nothing -> string {
    $cfg | ^awk '
        tolower($1) == "setenv" {
            for (i = 2; i <= NF; i++) {
                split($i, a, "=")
                if (a[1] == "TOTP_ITEMID") { print a[2]; exit }
            }
        }
    ' | str trim
}

# Finds the destination and -F config file in an ssh argument list; host is ""
# when there is no destination. Mirrors ssh's getopt: option clusters (-4vA)
# are skipped, and so is the value of every option letter that takes one,
# attached (-p2222) or separate (-p 2222). The first non-option is the
# destination, returned as given: `ssh -G` parses [user@]host and ssh:// URIs
# itself, and needs the user to evaluate `Match user` blocks correctly.
def nredf-ssh-destination [args: list<string>]: nothing -> record<config: string, host: string> {
    let opts_with_arg = ("BbcDEeFIiJLlmOoPpQRSWw" | split chars)
    mut dest = ""
    mut cfg_file = ""
    mut want = ""
    mut end_opts = false
    for arg in $args {
        if $want != "" {
            if $want == "F" { $cfg_file = $arg }
            $want = ""
            continue
        }
        if (not $end_opts) and $arg == "--" {
            $end_opts = true
            continue
        }
        if (not $end_opts) and ($arg =~ '^-.') {
            let chars = ($arg | split chars)
            mut i = 1
            while $i < ($chars | length) {
                let c = ($chars | get $i)
                if $c in $opts_with_arg {
                    if $i + 1 < ($chars | length) {
                        if $c == "F" { $cfg_file = ($chars | skip ($i + 1) | str join) }
                    } else {
                        $want = $c
                    }
                    break
                }
                $i += 1
            }
            continue
        }
        $dest = $arg
        break
    }

    {config: $cfg_file, host: $dest}
}

# --env all the way down: nredf-sshpass-bitwarden-totp sets $env.BW_SESSION
# (via nredf-bw-ensure-session), and a single plain `def` in this chain would
# silently drop it, re-prompting for the master password on every TOTP host.
def --env --wrapped nredf-ssh [...args] {
    nredf-sshpass-totp ...$args
}

def --env --wrapped nredf-sshpass-totp [...args] {
    if ($args | is-empty) {
        print --stderr "Usage: nredf-ssh [ssh_options...] <destination> [command...]"
        return
    }

    let parsed = (nredf-ssh-destination ($args | each { into string }))
    let host = $parsed.host
    # No destination (e.g. `nredf-ssh -V`): nothing to look up.
    if ($host | is-empty) {
        ^ssh ...$args
        return
    }
    let g_opts = (if ($parsed.config | is-empty) { [] } else { ["-F" $parsed.config] })

    let host_cfg_result = (^ssh ...$g_opts -G $host | complete)
    if $host_cfg_result.exit_code != 0 {
        ^ssh ...$args
        return
    }
    let host_cfg = $host_cfg_result.stdout

    mut totp_itemid = ""

    let proxyjump = ($host_cfg | ^awk 'tolower($1)=="proxyjump" && $2!="none"{print $2; exit}' | str trim)
    if not ($proxyjump | is-empty) {
        # First hop of a (possibly comma-separated) ProxyJump chain, minus
        # any user@ prefix or :port suffix.
        mut pj_first = ($proxyjump | split row --number 2 "," | get 0? | default "")
        $pj_first = ($pj_first | str replace --regex '^[^@]*@' '')
        $pj_first = ($pj_first | str replace --regex ':.*' '')
        if not ($pj_first | is-empty) {
            let pj_cfg = (^ssh ...$g_opts -G $pj_first | complete | get stdout)
            $totp_itemid = (nredf-parse-totp $pj_cfg)
        }
    }

    if ($totp_itemid | is-empty) {
        $totp_itemid = (nredf-parse-totp $host_cfg)
    }

    if ($totp_itemid | is-empty) {
        ^ssh ...$args
        return
    }

    mut item_totp = ""
    mut totp_provider = ($env.NREDF_SHELL_SSH_TOTP_PROVIDER? | default "")
    $totp_provider = ($totp_provider | str replace --regex '^#' '')

    if ($totp_provider | is-empty) {
        if not (which bw | is-empty) {
            $totp_provider = "bitwarden"
        } else if not (which op | is-empty) {
            $totp_provider = "1password"
        }
    }

    if $totp_provider == "bitwarden" {
        $item_totp = (nredf-sshpass-bitwarden-totp $totp_itemid)
    } else if $totp_provider in ["1password" "onepassword" "op"] {
        $item_totp = (nredf-sshpass-1password-totp $totp_itemid)
    }

    let totp = $item_totp
    if ($totp | is-empty) {
        ^ssh ...$args
    } else {
        # Unset SSH_ASKPASS to prevent GUI password prompts from interfering
        # with sshpass, which needs to handle password input directly via
        # stdin/the controlling terminal.
        with-env {SSH_ASKPASS: "" SSH_ASKPASS_REQUIRE: "" DISPLAY: ""} {
            ^sshpass -p $totp ssh ...$args
        }
    }
}

def --env nredf-sshpass-bitwarden-totp [itemid: string]: nothing -> string {
    if (which bw | is-empty) {
        print --stderr "Bitwarden CLI (bw) is not installed. Run: aqua install"
        return ""
    }

    if not (nredf-bw-ensure-session --force) {
        print --stderr "Bitwarden: failed to unlock vault"
        return ""
    }

    ^bw get totp $itemid --raw | str trim
}

def nredf-sshpass-1password-totp [itemid: string]: nothing -> string {
    if (which op | is-empty) {
        print --stderr "1Password CLI (op) is not installed. Run: aqua install"
        return ""
    }

    let r = (^op item get $itemid --otp | complete)
    if $r.exit_code != 0 {
        print --stderr $"Failed to retrieve TOTP from 1Password for item: ($itemid)"
        return ""
    }

    $r.stdout | str trim
}
