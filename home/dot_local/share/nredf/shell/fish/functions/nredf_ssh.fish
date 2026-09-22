#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
# -----------------------------------------------------------------------------
# SSH wrapper with Bitwarden / 1Password TOTP and sshpass.
#
# Port of common/functions/nredf_ssh.bash — see that file for the full design
# writeup and SSH config example (SetEnv TOTP_ITEMID=<id>).
# -----------------------------------------------------------------------------

function nredf_ssh
    _nredf_sshpass_totp $argv
end

function _nredf_parse_totp
    # $argv is the `ssh -G` output — fish's command substitution already
    # splits it into one list element per line, so rejoin before awk sees it.
    string join \n -- $argv | awk '
        tolower($1) == "setenv" {
            for (i = 2; i <= NF; i++) {
                split($i, a, "=")
                if (a[1] == "TOTP_ITEMID") { print a[2]; exit }
            }
        }
    '
end

function _nredf_sshpass_totp
    set -l host "$argv[1]"

    if test -z "$host"
        echo "Usage: nredf_ssh <ssh_host>"
        return 1
    end

    set -l host_cfg (ssh -G "$host" 2>/dev/null)
    if test -z "$host_cfg"
        ssh $argv
        return $status
    end

    set -l totp_itemid

    set -l proxyjump (string join \n -- $host_cfg | awk 'tolower($1)=="proxyjump" && $2!="none"{print $2; exit}')
    if test -n "$proxyjump"
        # First hop of a (possibly comma-separated) ProxyJump chain, minus
        # any user@ prefix or :port suffix.
        set -l pj_first (string split -m1 , -- "$proxyjump")[1]
        set pj_first (string replace -r '^[^@]*@' '' -- "$pj_first")
        set pj_first (string replace -r ':.*' '' -- "$pj_first")
        if test -n "$pj_first"
            set -l pj_cfg (ssh -G "$pj_first" 2>/dev/null)
            set totp_itemid (_nredf_parse_totp $pj_cfg)
        end
    end

    if test -z "$totp_itemid"
        set totp_itemid (_nredf_parse_totp $host_cfg)
    end

    if test -z "$totp_itemid"
        ssh $argv
        return $status
    end

    set -l item_totp
    set -l totp_provider "$NREDF_SHELL_SSH_TOTP_PROVIDER"
    set totp_provider (string replace -r '^#' '' -- "$totp_provider")

    if test -z "$totp_provider"
        if type -q bw
            set totp_provider bitwarden
        else if type -q op
            set totp_provider 1password
        end
    end

    switch "$totp_provider"
        case bitwarden
            set item_totp (_nredf_sshpass_bitwarden_totp "$totp_itemid")
        case 1password onepassword op
            set item_totp (_nredf_sshpass_1password_totp "$totp_itemid")
    end

    if test -z "$item_totp"
        ssh $argv
    else
        # Unset SSH_ASKPASS to prevent GUI password prompts from interfering
        # with sshpass, which needs to handle password input directly via
        # stdin/the controlling terminal.
        env SSH_ASKPASS= SSH_ASKPASS_REQUIRE= DISPLAY= sshpass -p "$item_totp" ssh $argv
    end
end

function _nredf_sshpass_bitwarden_totp --argument-names itemid
    if not type -q bw
        echo "Bitwarden CLI (bw) is not installed. Run: aqua install" >&2
        return 1
    end

    # Ensure the vault is unlocked (uses keychain / biometrics when available).
    if not _nredf_bw_ensure_session --force
        echo "Bitwarden: failed to unlock vault" >&2
        return 1
    end

    bw get totp "$itemid" --raw
end

function _nredf_sshpass_1password_totp --argument-names itemid
    if not type -q op
        echo "1Password CLI (op) is not installed. Run: aqua install" >&2
        return 1
    end

    set -l totp
    if not set totp (op item get "$itemid" --otp 2>/dev/null)
        echo "Failed to retrieve TOTP from 1Password for item: $itemid" >&2
        return 1
    end

    echo "$totp"
end
