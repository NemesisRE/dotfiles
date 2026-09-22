#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

function _nredf_set_ssh_agent_wsl
    if not type -q whoami.exe
        printf "Error: whoami.exe not found in PATH. Please ensure it is available.\n" >&2
        return 1
    end
    set -l windows_user (whoami.exe | string replace -r '.*\\\\' '' | string trim -c "\r\n")

    set -l npiperelay_default "/mnt/c/Users/$windows_user/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe/npiperelay.exe"
    set -l npiperelay "$NPIPERELAY_PATH"
    test -n "$npiperelay"; or set npiperelay "$npiperelay_default"

    if not test -x "$npiperelay"; and type -q where.exe; and type -q wslpath
        set -l win_npiperelay (cmd.exe /c "where.exe npiperelay.exe" 2>/dev/null | string trim -c "\r" | head -n1)
        if test -n "$win_npiperelay"
            set -l npiperelay_unix (wslpath -u "$win_npiperelay" 2>/dev/null)
            if test -n "$npiperelay_unix"
                set npiperelay "$NPIPERELAY_PATH"
                test -n "$npiperelay"; or set npiperelay "$npiperelay_unix"
            end
        else
            printf "Error: npiperelay.exe is not executable\n" >&2
            printf "       Please ensure that npiperelay.exe is installed and accessible e.g.:\n" >&2
            printf "       \e[3mwinget install albertony.npiperelay\e[23m\n" >&2
            return 1
        end
    end

    if type -q setsid; and type -q socat
        set -l socat_pid_file "$HOME/.ssh/socat_npiperelay.pid"
        if test -f "$socat_pid_file"
            set -l old_pid (cat "$socat_pid_file")
            if kill -0 "$old_pid" &>/dev/null
                kill "$old_pid" &>/dev/null
            end
            rm -f "$socat_pid_file"
        end
        fish -c "setsid socat UNIX-LISTEN:$SSH_AUTH_SOCK,fork EXEC:'$npiperelay -ei -s //./pipe/openssh-ssh-agent',nofork &>/dev/null" &
        disown
        sleep 0.1
        set -l new_pid (pgrep -f "socat UNIX-LISTEN:$SSH_AUTH_SOCK" | head -n1)
        if test -n "$new_pid"
            echo "$new_pid" >"$socat_pid_file"
        end
    else
        printf "Warning: 'setsid' or 'socat' not found; SSH agent bridging not started.\n" >&2
    end
end

function _nredf_set_ssh_agent_1password
    set -l candidates
    if test "$NREDF_OS" = macos
        set candidates "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else
        set candidates "$HOME/.1password/agent.sock" "$HOME/.config/1Password/agent.sock"
    end

    for sock in $candidates
        if test -S "$sock"
            if _nredf_ssh_agent_socket_works "$sock"
                set -gx SSH_AUTH_SOCK "$sock"
                return 0
            end
        end
    end
    return 1
end

function _nredf_set_ssh_agent_system
    set -l runtime_dir "$XDG_RUNTIME_DIR"
    test -n "$runtime_dir"; or set runtime_dir "/run/user/"(id -u)
    set -l candidates "$runtime_dir/ssh-agent.socket" "$runtime_dir/gcr/ssh" "$runtime_dir/keyring/ssh"

    for sock in $candidates
        if test -S "$sock"
            if _nredf_ssh_agent_socket_works "$sock"
                set -gx SSH_AUTH_SOCK "$sock"
                return 0
            end
        end
    end
    return 1
end

function _nredf_set_ssh_agent_bitwarden
    set -l candidates
    if test "$NREDF_OS" = macos
        set candidates \
            "$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock" \
            "$HOME/.bitwarden-ssh-agent.sock"
    else
        set candidates \
            "$HOME/.bitwarden-ssh-agent.sock" \
            "$HOME/snap/bitwarden/current/.bitwarden-ssh-agent.sock" \
            "$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
    end

    for sock in $candidates
        if test -S "$sock"
            if _nredf_ssh_agent_socket_works "$sock"
                set -gx SSH_AUTH_SOCK "$sock"
                return 0
            end
        end
    end
    return 1
end

function _nredf_set_ssh_agent_gpg
    if type -q gpgconf
        # Only set SSH_AUTH_SOCK if not in an SSH session and this shell did
        # not already set it (gnupg_SSH_AUTH_SOCK_by tracks the PID that set it).
        if test -z "$SSH_CONNECTION"; and test "$gnupg_SSH_AUTH_SOCK_by" != "$fish_pid"
            set -e SSH_AGENT_PID
            set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
            set -gx gnupg_SSH_AUTH_SOCK_by "$fish_pid"
        end
    end
end

function _nredf_ssh_agent_socket_works --argument-names sock
    test -n "$sock"; or set sock "$SSH_AUTH_SOCK"

    if test -z "$sock"; or not test -S "$sock"
        return 1
    end

    if type -q ssh-add
        env SSH_AUTH_SOCK="$sock" ssh-add -l &>/dev/null
        set -l rc $status
        test "$rc" -eq 0; or test "$rc" -eq 1
        return $status
    end

    return 0
end

function _nredf_configured_ssh_agent_mode
    set -l mode "$NREDF_SHELL_SSH_AGENT"
    test -n "$mode"; or set mode default
    printf "%s" "$mode"
end

function _nredf_set_ssh_agent
    set -l agent_mode (_nredf_configured_ssh_agent_mode)
    set -l prefer_external_provider false
    test "$agent_mode" != default; and set prefer_external_provider true

    # Do not override a forwarded SSH agent.
    test -n "$SSH_CONNECTION"; and return 0

    # With an explicit external-provider preference, try configured providers
    # first and fall back to the current agent only if all preferred providers fail.
    if test "$prefer_external_provider" = true
        if test "$agent_mode" = pipe; and test -n "$WSL_DISTRO_NAME$WSL_INTEROP"
            set -gx SSH_AUTH_SOCK "$HOME/.ssh/auth_sock"
            _nredf_set_ssh_agent_wsl
            _nredf_ssh_agent_socket_works "$SSH_AUTH_SOCK"; and return 0
        end

        if test "$agent_mode" = gpg
            _nredf_set_ssh_agent_gpg
            _nredf_ssh_agent_socket_works "$SSH_AUTH_SOCK"; and return 0
        end

        if test "$agent_mode" = bitwarden
            _nredf_set_ssh_agent_bitwarden
            _nredf_ssh_agent_socket_works "$SSH_AUTH_SOCK"; and return 0
        end

        if test "$agent_mode" = 1password; or test "$agent_mode" = onepassword
            _nredf_set_ssh_agent_1password
            _nredf_ssh_agent_socket_works "$SSH_AUTH_SOCK"; and return 0
        end

        if test "$agent_mode" = system
            _nredf_set_ssh_agent_system
            _nredf_ssh_agent_socket_works "$SSH_AUTH_SOCK"; and return 0
        end

        if _nredf_ssh_agent_socket_works "$SSH_AUTH_SOCK"
            return 0
        end
    else
        # Keep the current agent if it is working.
        if _nredf_ssh_agent_socket_works "$SSH_AUTH_SOCK"
            return 0
        end
    end

    # Ensure the socket directory exists.
    if not test -d "$HOME/.ssh"
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
    end

    # Check whether the socket already exists and is working.
    set -l auth_sock "$HOME/.ssh/auth_sock"
    if _nredf_ssh_agent_socket_works "$auth_sock"
        set -gx SSH_AUTH_SOCK "$auth_sock"
        return 0
    end

    # Remove a stale socket before starting a new agent.
    rm -f "$auth_sock"

    if test "$agent_mode" = pipe; and test -n "$WSL_DISTRO_NAME$WSL_INTEROP"
        set -gx SSH_AUTH_SOCK "$auth_sock"
        if not _nredf_set_ssh_agent_wsl
            printf "Error: Failed to set up WSL SSH agent bridge\n" >&2
            return 1
        end
    else if test "$agent_mode" = gpg
        _nredf_set_ssh_agent_gpg
    else if test "$agent_mode" = bitwarden
        _nredf_set_ssh_agent_bitwarden
    else if test "$agent_mode" = 1password; or test "$agent_mode" = onepassword
        _nredf_set_ssh_agent_1password
    else if test "$agent_mode" = system
        _nredf_set_ssh_agent_system
    else
        # Auto-detect a running 1Password, Bitwarden, or systemd agent before
        # spawning a plain ssh-agent.
        if _nredf_set_ssh_agent_1password
            return 0
        end
        if _nredf_set_ssh_agent_bitwarden
            return 0
        end
        if _nredf_set_ssh_agent_system
            return 0
        end

        set -gx SSH_AUTH_SOCK "$auth_sock"
        if type -q ssh-agent
            set -e SSH_AGENT_PID
            # ssh-agent -s emits sh/bash syntax, which fish's `eval` cannot
            # interpret (unlike bash's `eval "$(ssh-agent -s ...)"`); pull the
            # PID out of its output text instead. SSH_AUTH_SOCK is already
            # correct since we told ssh-agent -a which socket to bind.
            set -l agent_output (ssh-agent -s -a "$SSH_AUTH_SOCK")
            set -l pid_match (string match -r 'SSH_AGENT_PID=([0-9]+);' -- $agent_output)
            if test (count $pid_match) -ge 2
                set -gx SSH_AGENT_PID $pid_match[2]
            end
        else
            printf "Warning: 'ssh-agent' not found; no SSH agent could be started.\n" >&2
            return 1
        end
    end

    # Verify the agent is actually working.
    if test -S "$SSH_AUTH_SOCK"; and type -q ssh-add
        ssh-add -l &>/dev/null
        set -l exit_code $status

        if test "$exit_code" -eq 0
            return 0
        else if test "$exit_code" -eq 1
            if test -n "$NREDF_PROFILE_STARTUP"
                printf "\033[1;33mAdd your SSH key(s) to the agent with 'ssh-add'\033[0m\n" >&2
            end
            return 0
        else if test "$exit_code" -gt 1
            printf "Warning: SSH agent socket exists but agent is not responding\n" >&2
            return 1
        end
    end
end
