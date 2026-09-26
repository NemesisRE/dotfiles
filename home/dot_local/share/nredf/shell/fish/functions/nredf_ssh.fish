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

# Prints the -F config file (possibly empty) on line 1 and the destination of
# an ssh argument list on line 2; prints nothing when there is no destination.
# Mirrors ssh's getopt: option clusters (-4vA) are skipped, and so is the value
# of every option letter that takes one, attached (-p2222) or separate
# (-p 2222). The first non-option is the destination, returned as given:
# `ssh -G` parses [user@]host and ssh:// URIs itself, and needs the user to
# evaluate `Match user` blocks correctly.
function _nredf_ssh_destination
    set -l opts_with_arg B b c D E e F I i J L l m O o P p Q R S W w
    set -l dest
    set -l cfg_file
    set -l want
    set -l end_opts 0
    for arg in $argv
        if test -n "$want"
            test "$want" = F; and set cfg_file "$arg"
            set want
            continue
        end
        if test $end_opts -eq 0; and test "$arg" = --
            set end_opts 1
            continue
        end
        if test $end_opts -eq 0; and string match -qr -- '^-.' "$arg"
            set -l chars (string split '' -- "$arg")
            for i in (seq 2 (count $chars))
                set -l c $chars[$i]
                if contains -- "$c" $opts_with_arg
                    if test $i -lt (count $chars)
                        test "$c" = F; and set cfg_file (string join '' -- $chars[(math $i + 1)..-1])
                    else
                        set want "$c"
                    end
                    break
                end
            end
            continue
        end
        set dest "$arg"
        break
    end

    test -z "$dest"; and return 0

    printf '%s\n%s\n' "$cfg_file" "$dest"
end

function _nredf_sshpass_totp
    if test (count $argv) -eq 0
        echo "Usage: nredf_ssh [ssh_options...] <destination> [command...]" >&2
        return 1
    end

    set -l parsed (_nredf_ssh_destination $argv)
    set -l cfg_file "$parsed[1]"
    set -l host "$parsed[2]"

    # No destination (e.g. `nredf_ssh -V`): nothing to look up.
    if test -z "$host"
        ssh $argv
        return $status
    end

    set -l g_opts
    test -n "$cfg_file"; and set g_opts -F "$cfg_file"

    set -l host_cfg (ssh $g_opts -G "$host" 2>/dev/null)
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
            set -l pj_cfg (ssh $g_opts -G "$pj_first" 2>/dev/null)
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
            # Unlike bash's $(...), fish's (...) runs in this process, so
            # the BW_SESSION exported by _nredf_bw_ensure_session survives.
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
