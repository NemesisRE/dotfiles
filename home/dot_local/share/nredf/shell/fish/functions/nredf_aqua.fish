#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

function _nredf_aqua_keyring_available
    if test "$NREDF_OS" = macos
        return 0
    end

    # Fish never runs on native Windows (no Windows build exists), but it does
    # run under WSL as a real Linux binary — keep the same "is this actually
    # a non-WSL Windows-ish environment" guard bash/zsh use, for parity.
    if test -n "$WINDIR$COMSPEC"; and test -z "$WSL_DISTRO_NAME$WSL_INTEROP"
        return 0
    end

    # Linux/Unix: aqua requires the D-Bus secret service (org.freedesktop.secrets).
    set -l bus "$DBUS_SESSION_BUS_ADDRESS"
    if test -z "$bus"
        set -l sock "$XDG_RUNTIME_DIR"
        test -n "$sock"; or set sock "/run/user/"(id -u 2>/dev/null)
        set sock "$sock/bus"
        if test -S "$sock"
            set bus "unix:path=$sock"
        else
            return 1
        end
    end

    if type -q gdbus
        env DBUS_SESSION_BUS_ADDRESS="$bus" gdbus call --session \
            --dest org.freedesktop.secrets --object-path /org/freedesktop/secrets \
            --method org.freedesktop.DBus.Peer.Ping &>/dev/null
        return $status
    end

    if type -q busctl
        env DBUS_SESSION_BUS_ADDRESS="$bus" busctl --user call \
            org.freedesktop.secrets /org/freedesktop/secrets \
            org.freedesktop.DBus.Peer Ping &>/dev/null
        return $status
    end

    if type -q dbus-send
        env DBUS_SESSION_BUS_ADDRESS="$bus" dbus-send --session --dest=org.freedesktop.secrets \
            --type=method_call --print-reply /org/freedesktop/secrets \
            org.freedesktop.DBus.Peer.Ping &>/dev/null
        return $status
    end

    return 1
end

# ~/.config/nredf/aqua-vault.env and aqua.env are shared with bash/zsh/
# PowerShell and are plain `[export] KEY="value"` dotenv files, not fish
# syntax — bash/zsh `source` them as code, but fish (like PowerShell's
# Defaults.ps1 already does for these same files) parses them as data
# instead, so it never breaks on a value another shell wrote.
function _nredf_read_dotenv --argument-names file
    test -f "$file"; or return 0
    for line in (string split \n -- (cat "$file"))
        set line (string trim -- "$line")
        test -z "$line"; and continue
        string match -q '#*' -- "$line"; and continue
        set line (string replace -r '^export[[:space:]]+' '' -- "$line")
        string match -qr '^[A-Za-z_][A-Za-z0-9_]*=' -- "$line"; or continue
        set -l key (string split -m1 = -- "$line")[1]
        set -l val (string split -m1 = -- "$line")[2]
        set val (string trim -c '\'"' -- "$val")
        set -gx $key "$val"
    end
end

# POSIX single-quoting so a value fish writes stays sourceable by bash/zsh.
function _nredf_posix_quote --argument-names val
    printf "'%s'" (string replace -a "'" "'\\''" -- "$val")
end

function _nredf_set_aqua_env
    set -l aqua_base_config "$XDG_CONFIG_HOME/aquaproj-aqua/aqua.yaml"
    set -l aqua_machine_config "$XDG_CONFIG_HOME/aquaproj-aqua/machine.yaml"
    set -l aqua_policy_config "$XDG_CONFIG_HOME/aquaproj-aqua/aqua-policy.yaml"
    set -l aqua_config_dir "$NREDF_CONFIG"
    test -n "$aqua_config_dir"; or set aqua_config_dir "$XDG_CONFIG_HOME/nredf"

    # Vault-derived (chezmoi-managed) first, then the runtime-local one
    # (nredf_aqua_token_setup's --env mode) so it can override — two different
    # owners of two different files on purpose: chezmoi would otherwise delete
    # a manually-configured token on every apply whenever the vault lookup
    # comes back empty (confirmed empirically).
    _nredf_read_dotenv "$aqua_config_dir/aqua-vault.env"
    _nredf_read_dotenv "$aqua_config_dir/aqua.env"

    # If the keyring is configured but unavailable on this system (e.g.
    # headless/WSL), deactivate AQUA_KEYRING_ENABLED to prevent aqua CLI errors.
    if test "$AQUA_KEYRING_ENABLED" = true; and not _nredf_aqua_keyring_available
        set -e AQUA_KEYRING_ENABLED
    end

    if test -f "$aqua_base_config"
        set -gx AQUA_CONFIG "$aqua_base_config"
        set -gx AQUA_GLOBAL_CONFIG "$aqua_base_config"
        if test -f "$aqua_machine_config"
            set -gx AQUA_GLOBAL_CONFIG "$AQUA_GLOBAL_CONFIG:$aqua_machine_config"
        end
    end

    if test -f "$aqua_policy_config"
        set -gx AQUA_POLICY_CONFIG "$aqua_policy_config"
    end
end

function _nredf_set_aqua_path
    set -l aqua_bin "$AQUA_ROOT_DIR"
    test -n "$aqua_bin"; or set aqua_bin "$XDG_DATA_HOME"
    test -n "$aqua_bin"; or set aqua_bin "$HOME/.local/share"
    if test "$aqua_bin" = "$AQUA_ROOT_DIR"
        # AQUA_ROOT_DIR already points at the aqua root itself.
    else
        set aqua_bin "$aqua_bin/aquaproj-aqua"
    end
    set aqua_bin "$aqua_bin/bin"

    if not contains -- "$aqua_bin" $PATH
        set -gx PATH "$aqua_bin" $PATH
    end
end

function _nredf_aqua_auth_config_file
    set -l config_dir "$NREDF_CONFIG"
    test -n "$config_dir"; or set config_dir "$XDG_CONFIG_HOME/nredf"
    printf "%s/aqua.env" "$config_dir"
end

function _nredf_write_aqua_auth_config --argument-names mode token
    if test -z "$mode"
        echo "missing aqua auth mode" >&2
        return 1
    end

    set -l auth_file (_nredf_aqua_auth_config_file)
    set -l auth_dir (path dirname -- "$auth_file")
    mkdir -p "$auth_dir"
    set -l tmp_file (mktemp "$auth_dir/aqua.env.XXXXXX")

    # This file is shared with bash/zsh (which `source` it directly) and
    # PowerShell (which parses it, like _nredf_read_dotenv above), so it must
    # stay valid POSIX-shell `[export] KEY='value'` syntax regardless of
    # which shell wrote it — never fish's own `set -gx` syntax here.
    begin
        printf "# Local aqua GitHub auth preferences\n"
        printf "NREDF_AQUA_GITHUB_TOKEN_SETUP=%s\n" (_nredf_posix_quote "$mode")
        if test "$mode" = keyring
            printf "AQUA_KEYRING_ENABLED=%s\n" (_nredf_posix_quote true)
        else if test "$mode" = env; and test -n "$token"
            printf "export AQUA_GITHUB_TOKEN=%s\n" (_nredf_posix_quote "$token")
            printf "export GITHUB_TOKEN=%s\n" (_nredf_posix_quote "$token")
        end
    end >"$tmp_file"

    chmod 600 "$tmp_file"
    mv "$tmp_file" "$auth_file"
end

function _nredf_clear_aqua_auth_config
    set -l auth_file (_nredf_aqua_auth_config_file)
    rm -f "$auth_file"
    set -e AQUA_KEYRING_ENABLED
    set -e NREDF_AQUA_GITHUB_TOKEN_SETUP
    set -e AQUA_GITHUB_TOKEN
    set -e GITHUB_TOKEN
end

# Returns 0 = yes, 1 = no, 2 = unanswered (no usable terminal, EOF, or no
# `timeout`/`gtimeout` binary to bound the wait). "Unanswered" must never be
# conflated with "no": callers record "no" as a permanent opt-out, which is
# wrong when nobody was there to be asked.
#
# Fish's `read` has no timeout flag at all (unlike bash's `read -t`), so this
# shells out to `timeout`/`gtimeout` if one is installed; if neither is, the
# prompt falls back to an untimed read (still gated on an interactive tty, so
# it never runs in a non-interactive shell — see docs/shells.md).
function _nredf_prompt_yes_no --argument-names prompt
    if not test -r /dev/tty; or not test -w /dev/tty
        return 2
    end

    set -l timeout_bin
    if type -q timeout
        set timeout_bin timeout
    else if type -q gtimeout
        set timeout_bin gtimeout
    end
    set -l timeout_secs "$NREDF_PROMPT_TIMEOUT"
    test -n "$timeout_secs"; or set timeout_secs 30

    while true
        printf "%s [y/N]: " "$prompt" >/dev/tty
        set -l reply
        if test -n "$timeout_bin"
            set reply ($timeout_bin "$timeout_secs" fish -c 'read -l r; and echo $r' </dev/tty)
            if test $status -ne 0
                printf "\n" >/dev/tty
                return 2
            end
        else
            if not read -l reply </dev/tty
                printf "\n" >/dev/tty
                return 2
            end
        end
        switch "$reply"
            case y Y yes YES
                return 0
            case n N no NO ''
                return 1
        end
        printf "Please answer yes or no.\n" >/dev/tty
    end
end

function nredf_aqua_token_setup --argument-names action
    test -n "$action"; or set action --set
    _nredf_init_paths

    switch "$action"
        case --keyring
            if not type -q aqua
                echo "aqua is not installed." >&2
                return 1
            end
            if not _nredf_aqua_keyring_available
                echo "System keyring (org.freedesktop.secrets) is not available on this system." >&2
                echo "Use 'nredf_aqua_token_setup --env' to store the token in local aqua.env instead." >&2
                return 1
            end
            if not aqua token set
                return 1
            end
            _nredf_write_aqua_auth_config keyring
            set -gx AQUA_KEYRING_ENABLED true
            set -gx NREDF_AQUA_GITHUB_TOKEN_SETUP keyring
            echo "Stored aqua's GitHub token in the system keyring."

        case --env
            set -l token
            if test -r /dev/tty; and test -w /dev/tty
                printf "Enter a GitHub access token: " >/dev/tty
                read -s -l token </dev/tty
                printf "\n" >/dev/tty
            else
                printf "Enter a GitHub access token: "
                read -s -l token
                printf "\n"
            end

            if test -z "$token"
                echo "Error: Token cannot be empty." >&2
                return 1
            end

            _nredf_write_aqua_auth_config env "$token"
            set -gx AQUA_GITHUB_TOKEN "$token"
            set -gx GITHUB_TOKEN "$token"
            set -gx NREDF_AQUA_GITHUB_TOKEN_SETUP env
            set -e AQUA_KEYRING_ENABLED
            echo "Stored aqua's GitHub token in "(_nredf_aqua_auth_config_file)" (mode 0600)."

        case --set
            if _nredf_aqua_keyring_available
                if nredf_aqua_token_setup --keyring
                    return 0
                end
                echo "Keyring setup failed. Falling back to file-based token storage..."
            end
            nredf_aqua_token_setup --env

        case --skip
            _nredf_write_aqua_auth_config skip
            set -e AQUA_KEYRING_ENABLED
            set -gx NREDF_AQUA_GITHUB_TOKEN_SETUP skip
            echo "Skipping aqua GitHub token setup for now."

        case --reset
            _nredf_clear_aqua_auth_config
            echo "Reset aqua GitHub token preference."

        case --status
            set -l auth_file (_nredf_aqua_auth_config_file)
            echo "=== aqua GitHub Token Status ==="
            if test -n "$AQUA_GITHUB_TOKEN"
                echo "AQUA_GITHUB_TOKEN: set (length: "(string length -- "$AQUA_GITHUB_TOKEN")")"
            else
                echo "AQUA_GITHUB_TOKEN: unset"
            end
            if test -n "$GITHUB_TOKEN"
                echo "GITHUB_TOKEN:      set (length: "(string length -- "$GITHUB_TOKEN")")"
            else
                echo "GITHUB_TOKEN:      unset"
            end
            set -l keyring_enabled "$AQUA_KEYRING_ENABLED"
            test -n "$keyring_enabled"; or set keyring_enabled unset
            echo "AQUA_KEYRING_ENABLED: $keyring_enabled"
            set -l setup_state "$NREDF_AQUA_GITHUB_TOKEN_SETUP"
            test -n "$setup_state"; or set setup_state unset
            echo "Setup state:          $setup_state"
            if test -f "$auth_file"
                echo "Auth config file:     $auth_file [exists]"
            else
                echo "Auth config file:     $auth_file [missing]"
            end
            if _nredf_aqua_keyring_available
                echo "System keyring:       available"
            else
                echo "System keyring:       unavailable (headless / WSL / no secret service)"
            end

        case '*'
            echo "Usage: nredf_aqua_token_setup [--set|--keyring|--env|--skip|--reset|--status]" >&2
            return 1
    end
end

function _nredf_ensure_aqua_github_token
    if not status is-interactive
        return 0
    end

    set -l setup_state "$NREDF_AQUA_GITHUB_TOKEN_SETUP"

    # Interactive, but with nothing to ask on: do nothing (and record nothing).
    if not test -r /dev/tty; or not test -w /dev/tty
        return 0
    end

    if not type -q aqua
        return 0
    end

    if test -n "$AQUA_GITHUB_TOKEN$GITHUB_TOKEN"
        return 0
    end

    if test "$AQUA_KEYRING_ENABLED" = true; or test "$setup_state" = keyring
        if _nredf_aqua_keyring_available
            set -gx AQUA_KEYRING_ENABLED true
            return 0
        end
        set -e AQUA_KEYRING_ENABLED
    end

    set -l auth_file (_nredf_aqua_auth_config_file)
    if test -z "$setup_state"; and test -f "$auth_file"
        _nredf_read_dotenv "$auth_file"
        set setup_state "$NREDF_AQUA_GITHUB_TOKEN_SETUP"
    end

    if test -n "$AQUA_GITHUB_TOKEN$GITHUB_TOKEN"
        return 0
    end

    if test "$AQUA_KEYRING_ENABLED" = true; or test "$setup_state" = keyring
        if _nredf_aqua_keyring_available
            set -gx AQUA_KEYRING_ENABLED true
            return 0
        end
        set -e AQUA_KEYRING_ENABLED
    end

    if test "$setup_state" = skip
        return 0
    end

    if _nredf_aqua_keyring_available
        _nredf_prompt_yes_no "No GitHub token configured for aqua. Store one in the system keyring now?"
        switch $status
            case 0
                # fall through
            case 1
                nredf_aqua_token_setup --skip >/dev/null
                printf "Run 'nredf_aqua_token_setup' later to configure aqua's GitHub token.\n" >/dev/tty
                return 0
            case '*'
                return 0 # unanswered: ask again in a later shell
        end

        if not nredf_aqua_token_setup --keyring
            _nredf_prompt_yes_no "Keyring setup failed. Store token in $auth_file (mode 0600) instead?"
            switch $status
                case 0
                    nredf_aqua_token_setup --env
                case 1
                    nredf_aqua_token_setup --skip >/dev/null
                    printf "Skipping aqua GitHub token setup for now.\n" >/dev/tty
            end
        end
    else
        printf "\033[1;33mNo GitHub token configured for aqua (system keyring unavailable on this system).\033[0m\n" >/dev/tty
        _nredf_prompt_yes_no "Store token in $auth_file (mode 0600) now?"
        switch $status
            case 0
                nredf_aqua_token_setup --env
            case 1
                nredf_aqua_token_setup --skip >/dev/null
                printf "Skipping aqua GitHub token setup for now. Run 'nredf_aqua_token_setup' later to configure.\n" >/dev/tty
        end
    end

    return 0
end
