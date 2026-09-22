#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
# -----------------------------------------------------------------------------
# Bitwarden session management with OS keychain / biometric unlock
#
# Port of common/functions/nredf_bw.bash — see that file for the full design
# writeup. Backends: macOS `security`, Linux KDE Wallet (gdbus D-Bus calls,
# falling back to `kwallet-query`), GNOME `secret-tool`, plaintext file.
#
# Public functions
# - bwu                  Ensure BW_SESSION is set (keychain -> fresh unlock).
# - bwlock                Lock the vault, unset BW_SESSION, wipe keychain entry.
# - _nredf_bw_restore_session   Silent startup restore.
# - _nredf_bw_ensure_session    Used by nredf_ssh's TOTP helper.
# -----------------------------------------------------------------------------

set -g _NREDF_BW_SERVICE nredf.bw_session

function _nredf_bw_account
    set -l account "$USER"
    test -n "$account"; or set account (id -un 2>/dev/null)
    echo "$account"
end

function _nredf_bw_marker
    set -l base "$XDG_RUNTIME_DIR"
    test -n "$base"; or set base "$TMPDIR"
    test -n "$base"; or set base /tmp
    echo "$base/nredf_bw_"(_nredf_bw_account)".active"
end

# ---------------------------------------------------------------------------
# Internal: helpers for interacting with KWallet via gdbus / D-Bus.
# Works natively on KDE Plasma 6 (kwalletd6) and Plasma 5 (kwalletd5).
# ---------------------------------------------------------------------------
function _nredf_bw_kwallet_service
    type -q gdbus; or return 1
    for s in org.kde.kwalletd6 org.kde.kwalletd5 org.kde.kwalletd
        set -l en (gdbus call --session --dest "$s" --object-path "/modules/"(string split -r -m1 . -- "$s")[2] \
            --method org.kde.KWallet.isEnabled 2>/dev/null)
        if string match -q '*true*' -- "$en"
            echo "$s"
            return 0
        end
        if string match -q '*false*' -- "$en"
            continue
        end
        if gdbus call --session --dest "$s" --object-path "/modules/"(string split -r -m1 . -- "$s")[2] \
            --method org.freedesktop.DBus.Peer.Ping &>/dev/null
            echo "$s"
            return 0
        end
    end
    return 1
end

function _nredf_bw_kwallet_open --argument-names service wallet
    test -n "$wallet"; or set wallet kdewallet
    set -l mod "/modules/"(string split -r -m1 . -- "$service")[2]
    set -l res (gdbus call --session --dest "$service" --object-path "$mod" \
        --method org.kde.KWallet.open "$wallet" 0 nredf 2>/dev/null)
    test -n "$res"; or return 1
    # Extract the numeric handle (gdbus returns '(975485171,)' or '(int32 975485171,)').
    set -l handle (string replace -r '.*\((?:[a-zA-Z0-9]+[[:space:]]+)?(-?[0-9]+).*' '$1' -- "$res")
    if string match -qr '^[0-9]+$' -- "$handle"
        echo "$handle"
        return 0
    end
    return 1
end

# ---------------------------------------------------------------------------
# Internal: detect which keychain backend is available.
# ---------------------------------------------------------------------------
function _nredf_bw_keychain_backend
    if test "$NREDF_OS" = macos
        echo macos
        return 0
    end

    if type -q kwallet-query; or begin
            type -q gdbus; and _nredf_bw_kwallet_service &>/dev/null
        end
        echo kwallet
        return 0
    end

    if type -q secret-tool
        echo secret-tool
        return 0
    end

    echo fallback
end

# ---------------------------------------------------------------------------
# Internal: retrieve the session token from the keychain.
# Prints the token and returns 0 on success, returns 1 on a miss.
# ---------------------------------------------------------------------------
function _nredf_bw_keychain_get
    set -l backend (_nredf_bw_keychain_backend)
    set -l account (_nredf_bw_account)
    set -l token

    switch "$backend"
        case macos
            for key in "$_NREDF_BW_SERVICE" bw_session BW_SESSION
                set token (security find-generic-password -s "$key" -a "$account" -w 2>/dev/null)
                test -n "$token"; and break
            end

        case kwallet
            if type -q gdbus
                set -l service (_nredf_bw_kwallet_service)
                if test -n "$service"
                    set -l mod "/modules/"(string split -r -m1 . -- "$service")[2]
                    set -l wallets kdewallet
                    for m in networkWallet localWallet
                        set -l def_w (gdbus call --session --dest "$service" --object-path "$mod" \
                            --method "org.kde.KWallet.$m" 2>/dev/null)
                        set def_w (string match -r "'([^']*)'" -- "$def_w")[2]
                        if test -n "$def_w"; and not contains -- "$def_w" $wallets
                            set wallets $wallets "$def_w"
                        end
                    end

                    for w in $wallets
                        set -l handle (_nredf_bw_kwallet_open "$service" "$w")
                        test -n "$handle"; or continue

                        set -l folders Passwords nredf
                        set -l f_raw (gdbus call --session --dest "$service" --object-path "$mod" \
                            --method org.kde.KWallet.folderList "$handle" 2>/dev/null)
                        if test -n "$f_raw"
                            set -l cleaned (printf "%s" "$f_raw" | tr -d "[],()'")
                            for f_item in (string split " " -- $cleaned)
                                test -n "$f_item"; or continue
                                if not contains -- "$f_item" $folders
                                    set folders $folders "$f_item"
                                end
                            end
                        end

                        for folder in $folders
                            for key in "$_NREDF_BW_SERVICE" bw_session BW_SESSION bitwarden Bitwarden bw
                                set -l raw (gdbus call --session --dest "$service" --object-path "$mod" \
                                    --method org.kde.KWallet.readPassword "$handle" "$folder" "$key" nredf 2>/dev/null)
                                set -l candidate (string match -r "'([^']*)'" -- "$raw")[2]
                                if test -n "$candidate"
                                    set token "$candidate"
                                    break
                                end
                            end
                            test -n "$token"; and break
                        end
                        test -n "$token"; and break
                    end
                end
            end

            if test -z "$token"; and type -q kwallet-query
                for folder in Passwords nredf
                    for key in "$_NREDF_BW_SERVICE" bw_session BW_SESSION bitwarden Bitwarden bw
                        set -l candidate (kwallet-query --read-password "$key" --folder "$folder" kdewallet 2>/dev/null)
                        if test -n "$candidate"; and not string match -q '*cannot be read*' -- "$candidate"; and not string match -q '*kann nicht gelesen werden*' -- "$candidate"
                            set token "$candidate"
                            break
                        end
                    end
                    test -n "$token"; and break
                end
            end

        case secret-tool
            for key in "$_NREDF_BW_SERVICE" bw_session
                set token (secret-tool lookup service "$key" username "$account" 2>/dev/null)
                test -n "$token"; and break
                set token (secret-tool lookup service "$key" 2>/dev/null)
                test -n "$token"; and break
            end

        case fallback
            set -l f "$XDG_RUNTIME_DIR"
            test -n "$f"; or set f /tmp
            set f "$f/nredf_bw_session"
            test -f "$f"; and set token (cat "$f")
    end

    if test -n "$token"
        printf "%s" "$token"
        return 0
    end
    return 1
end

# ---------------------------------------------------------------------------
# Internal: save the session token to the keychain.
# ---------------------------------------------------------------------------
function _nredf_bw_keychain_set --argument-names token
    set -l backend (_nredf_bw_keychain_backend)
    set -l account (_nredf_bw_account)

    switch "$backend"
        case macos
            for k in "$_NREDF_BW_SERVICE" bw_session
                security delete-generic-password -s "$k" -a "$account" &>/dev/null
                security add-generic-password -s "$k" -a "$account" -w "$token" -U &>/dev/null
            end

        case kwallet
            set -l saved 1
            if type -q gdbus
                set -l service (_nredf_bw_kwallet_service)
                if test -n "$service"
                    set -l handle (_nredf_bw_kwallet_open "$service")
                    if test -n "$handle"
                        set -l mod "/modules/"(string split -r -m1 . -- "$service")[2]
                        for k in "$_NREDF_BW_SERVICE" bw_session
                            set -l res (gdbus call --session --dest "$service" --object-path "$mod" \
                                --method org.kde.KWallet.writePassword "$handle" Passwords "$k" "$token" nredf 2>/dev/null)
                            string match -q '*(0,)*' -- "$res"; and set saved 0
                        end
                        if test "$saved" -ne 0
                            set -l has_f (gdbus call --session --dest "$service" --object-path "$mod" \
                                --method org.kde.KWallet.hasFolder "$handle" nredf 2>/dev/null)
                            if not string match -q '*true*' -- "$has_f"
                                gdbus call --session --dest "$service" --object-path "$mod" \
                                    --method org.kde.KWallet.createFolder "$handle" nredf &>/dev/null
                            end
                            for k in "$_NREDF_BW_SERVICE" bw_session
                                set -l res (gdbus call --session --dest "$service" --object-path "$mod" \
                                    --method org.kde.KWallet.writePassword "$handle" nredf "$k" "$token" nredf 2>/dev/null)
                                string match -q '*(0,)*' -- "$res"; and set saved 0
                            end
                        end
                    end
                end
            end

            if test "$saved" -ne 0; and type -q kwallet-query
                for k in "$_NREDF_BW_SERVICE" bw_session
                    printf "%s" "$token" | kwallet-query --write-password "$k" --folder Passwords kdewallet &>/dev/null
                    or printf "%s" "$token" | kwallet-query --write-password "$k" --folder nredf kdewallet &>/dev/null
                end
            end

        case secret-tool
            for k in "$_NREDF_BW_SERVICE" bw_session
                printf "%s" "$token" | secret-tool store --label "NREDF Bitwarden session" \
                    service "$k" username "$account" &>/dev/null
            end

        case fallback
            set -l f "$XDG_RUNTIME_DIR"
            test -n "$f"; or set f /tmp
            set f "$f/nredf_bw_session"
            printf "%s" "$token" >"$f"
            chmod 600 "$f"
    end

    touch (_nredf_bw_marker) 2>/dev/null
end

# ---------------------------------------------------------------------------
# Internal: remove the session token from the keychain.
# ---------------------------------------------------------------------------
function _nredf_bw_keychain_del
    set -l backend (_nredf_bw_keychain_backend)
    set -l account (_nredf_bw_account)

    switch "$backend"
        case macos
            for key in "$_NREDF_BW_SERVICE" bw_session BW_SESSION
                security delete-generic-password -s "$key" -a "$account" &>/dev/null
            end

        case kwallet
            if type -q gdbus
                set -l service (_nredf_bw_kwallet_service)
                if test -n "$service"
                    set -l handle (_nredf_bw_kwallet_open "$service")
                    if test -n "$handle"
                        set -l mod "/modules/"(string split -r -m1 . -- "$service")[2]
                        for folder in Passwords nredf
                            for key in "$_NREDF_BW_SERVICE" bw_session BW_SESSION
                                gdbus call --session --dest "$service" --object-path "$mod" \
                                    --method org.kde.KWallet.removeEntry "$handle" "$folder" "$key" nredf &>/dev/null
                            end
                        end
                    end
                end
            end
            if type -q kwallet-query
                for folder in Passwords nredf
                    for key in "$_NREDF_BW_SERVICE" bw_session BW_SESSION
                        kwallet-query --delete-entry "$key" --folder "$folder" kdewallet &>/dev/null
                    end
                end
            end

        case secret-tool
            for key in "$_NREDF_BW_SERVICE" bw_session
                secret-tool clear service "$key" username "$account" &>/dev/null
            end

        case fallback
            set -l f "$XDG_RUNTIME_DIR"
            test -n "$f"; or set f /tmp
            rm -f "$f/nredf_bw_session"
    end

    rm -f (_nredf_bw_marker) 2>/dev/null
end

# ---------------------------------------------------------------------------
# Internal: detect whether any Bitwarden secret is actually used in config.
# ---------------------------------------------------------------------------
function _nredf_bw_secret_configured
    set -l config_dir "$XDG_CONFIG_HOME/chezmoi"
    for c in "$config_dir/chezmoi.toml" "$config_dir/chezmoi.yaml" "$config_dir/chezmoi.json" \
        "$HOME/.config/chezmoi/chezmoi.toml" "$HOME/.config/chezmoi/chezmoi.yaml" \
        "$HOME/.chezmoi.toml" "$HOME/.chezmoi.yaml"
        test -f "$c"; or continue
        if grep -Eq '^[[:blank:]]*\[(data\.)?bitwarden\]' "$c" 2>/dev/null
            return 0
        end
        if grep -Eq '["'"'"'[:blank:]](bitwarden|bw):' "$c" 2>/dev/null
            return 0
        end
        if grep -Eq '\{\{[[:blank:]]*(\([[:blank:]]*)?bitwarden[[:blank:]]' "$c" 2>/dev/null
            return 0
        end
    end

    set -l src_dir "$NREDF_DOT_PATH"
    test -n "$src_dir"; or set src_dir "$HOME/.local/share/chezmoi"
    if test -d "$src_dir/home/.chezmoidata"
        if grep -rEq '["'"'"'[:blank:]](bitwarden|bw):' "$src_dir/home/.chezmoidata" 2>/dev/null
            return 0
        end
    end
    if test -f "$src_dir/home/.chezmoidata.yaml"
        if grep -Eq '["'"'"'[:blank:]](bitwarden|bw):' "$src_dir/home/.chezmoidata.yaml" 2>/dev/null
            return 0
        end
    end

    return 1
end

# ---------------------------------------------------------------------------
# Internal: perform a fresh bw unlock/login and persist the session.
# ---------------------------------------------------------------------------
function _nredf_bw_do_unlock
    if not type -q bw
        echo "Bitwarden CLI (bw) is not installed. Run: aqua install" >&2
        return 1
    end

    set -l session
    if not bw login --check &>/dev/null
        echo "Bitwarden: not logged in — running bw login" >&2
        set session (bw login --raw)
        or return 1
    else
        echo "Bitwarden: vault locked — running bw unlock" >&2
        set session (bw unlock --raw)
        or return 1
    end

    if test -z "$session"
        echo "Bitwarden: unlock returned an empty session token" >&2
        return 1
    end

    _nredf_bw_keychain_set "$session"
    set -gx BW_SESSION "$session"
    return 0
end

# ---------------------------------------------------------------------------
# Public: _nredf_bw_restore_session
# Restores BW_SESSION from the OS keychain if not already set. Fast and
# non-blocking: never prompts, suitable for shell startup.
# ---------------------------------------------------------------------------
function _nredf_bw_restore_session
    test -n "$BW_SESSION"; and return 0

    set -l cached (_nredf_bw_keychain_get 2>/dev/null)
    if test -n "$cached"
        set -gx BW_SESSION "$cached"
        touch (_nredf_bw_marker) 2>/dev/null
    end
end

# ---------------------------------------------------------------------------
# Public: _nredf_bw_ensure_session
# Ensures BW_SESSION is set and valid. Returns 0 on success, 1 on failure.
# ---------------------------------------------------------------------------
function _nredf_bw_ensure_session --argument-names force
    if not type -q bw
        echo "Bitwarden CLI (bw) is not installed. Run: aqua install" >&2
        return 1
    end

    if test -n "$BW_SESSION"
        if bw unlock --check &>/dev/null
            _nredf_bw_keychain_set "$BW_SESSION"
            return 0
        end
        set -e BW_SESSION
    end

    set -l cached_session (_nredf_bw_keychain_get 2>/dev/null)
    if test -n "$cached_session"
        set -gx BW_SESSION "$cached_session"
        if bw unlock --check &>/dev/null
            return 0
        end
        set -e BW_SESSION
        _nredf_bw_keychain_del
    end

    if test "$force" != true; and test "$force" != --force; and not _nredf_bw_secret_configured
        return 0
    end

    _nredf_bw_do_unlock
end

# ---------------------------------------------------------------------------
# Public: bwu — Bitwarden Unlock.
# ---------------------------------------------------------------------------
function bwu
    if test -n "$BW_SESSION"; and bw unlock --check &>/dev/null
        _nredf_bw_keychain_set "$BW_SESSION"
        printf "\033[1;32m✔ Bitwarden vault already unlocked (keychain synchronized)\033[0m\n"
        return 0
    end

    set -l cached_session (_nredf_bw_keychain_get 2>/dev/null)
    if test -n "$cached_session"
        set -gx BW_SESSION "$cached_session"
        if bw unlock --check &>/dev/null
            _nredf_bw_keychain_set "$BW_SESSION"
            printf "\033[1;32m✔ Bitwarden vault unlocked from keychain\033[0m\n"
            return 0
        end
        set -e BW_SESSION
        _nredf_bw_keychain_del
    end

    if _nredf_bw_ensure_session --force
        printf "\033[1;32m✔ Bitwarden vault unlocked\033[0m\n"
        return 0
    else
        printf "\033[1;31m✘ Failed to unlock Bitwarden vault\033[0m\n" >&2
        return 1
    end
end

# ---------------------------------------------------------------------------
# Public: bwlock — lock the vault and wipe the keychain entry.
# ---------------------------------------------------------------------------
function bwlock
    _nredf_bw_keychain_del

    if test -n "$BW_SESSION"
        bw lock &>/dev/null
        set -e BW_SESSION
    end

    printf "\033[1;33m⚿ Bitwarden vault locked and session cleared\033[0m\n"
end
