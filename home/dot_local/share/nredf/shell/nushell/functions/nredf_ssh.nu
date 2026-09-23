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

def --wrapped nredf-ssh [...args] {
    nredf-sshpass-totp ...$args
}

def --wrapped nredf-sshpass-totp [...args] {
    let host = ($args | get 0? | default "")
    if ($host | is-empty) {
        print "Usage: nredf-ssh <ssh_host>"
        return
    }

    let host_cfg_result = (^ssh -G $host | complete)
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
            let pj_cfg = (^ssh -G $pj_first | complete | get stdout)
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
