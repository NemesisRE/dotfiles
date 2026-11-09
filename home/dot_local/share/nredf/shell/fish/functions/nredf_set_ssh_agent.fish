#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# Picks the SSH agent for this shell and exports SSH_AUTH_SOCK. Mirrors
# common/functions/nredf_set_ssh_agent.bash — keep the two in sync.
#
# shell.ssh.agent (NREDF_SHELL_SSH_AGENT): default | 1password | onepassword |
# bitwarden | system | gpg | pipe (WSL only). Agent probes run under a timeout
# so a locked desktop agent can never hang shell startup.

# Health check: ssh-add -l exits 0 (keys) or 1 (no keys) for a live agent;
# anything else (2 = unreachable, 124 = timed out) is a dead one.
function _nredf_ssh_agent_socket_works --argument-names sock
    test -n "$sock"; and test -S "$sock"; or return 1
    type -q ssh-add; or return 0

    if type -q timeout
        env SSH_AUTH_SOCK="$sock" timeout 2 ssh-add -l &>/dev/null
    else if type -q gtimeout
        env SSH_AUTH_SOCK="$sock" gtimeout 2 ssh-add -l &>/dev/null
    else
        env SSH_AUTH_SOCK="$sock" ssh-add -l &>/dev/null
    end
    set -l rc $status
    test $rc -eq 0; or test $rc -eq 1
end

# Export the first candidate socket that answers.
function _nredf_ssh_agent_try_sockets
    for sock in $argv
        if _nredf_ssh_agent_socket_works "$sock"
            set -gx SSH_AUTH_SOCK "$sock"
            return 0
        end
    end
    return 1
end

function _nredf_ssh_agent_is_wsl
    test -n "$WSL_DISTRO_NAME$WSL_INTEROP"
end

function _nredf_set_ssh_agent_1password
    if test "$NREDF_OS" = macos
        _nredf_ssh_agent_try_sockets \
            "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else
        _nredf_ssh_agent_try_sockets \
            "$HOME/.1password/agent.sock" \
            "$HOME/.config/1Password/agent.sock"
    end
end

function _nredf_set_ssh_agent_bitwarden
    if test "$NREDF_OS" = macos
        _nredf_ssh_agent_try_sockets \
            "$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock" \
            "$HOME/.bitwarden-ssh-agent.sock"
    else
        _nredf_ssh_agent_try_sockets \
            "$HOME/.bitwarden-ssh-agent.sock" \
            "$HOME/snap/bitwarden/current/.bitwarden-ssh-agent.sock" \
            "$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
    end
end

function _nredf_set_ssh_agent_system
    set -l runtime_dir "$XDG_RUNTIME_DIR"
    test -n "$runtime_dir"; or set runtime_dir "/run/user/"(id -u)
    _nredf_ssh_agent_try_sockets \
        "$runtime_dir/ssh-agent.socket" \
        "$runtime_dir/gcr/ssh" \
        "$runtime_dir/keyring/ssh"
end

function _nredf_set_ssh_agent_gpg
    type -q gpgconf; or return 1
    set -l sock (gpgconf --list-dirs agent-ssh-socket 2>/dev/null)
    test -n "$sock"; or return 1

    # The socket only exists once gpg-agent runs (and has enable-ssh-support).
    test -S "$sock"; or gpgconf --launch gpg-agent &>/dev/null

    set -e SSH_AGENT_PID
    _nredf_ssh_agent_try_sockets "$sock"
end

# Resolve the Windows-side npiperelay.exe and print its path.
function _nredf_ssh_agent_find_npiperelay
    # 1. Explicit user override
    if test -n "$NPIPERELAY_PATH"; and test -x "$NPIPERELAY_PATH"
        printf '%s' "$NPIPERELAY_PATH"
        return 0
    end

    # 2. Default winget location
    if type -q whoami.exe
        set -l win_user (whoami.exe 2>/dev/null | string replace -r '.*\\\\' '' | string trim)
        set -l candidate "/mnt/c/Users/$win_user/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe/npiperelay.exe"
        if test -n "$win_user"; and test -x "$candidate"
            printf '%s' "$candidate"
            return 0
        end
    end

    # 3. Anything on the Windows PATH
    if type -q where.exe; and type -q wslpath
        set -l win_path (where.exe npiperelay.exe 2>/dev/null | string trim -c "\r" | head -n1)
        if test -n "$win_path"
            set -l candidate (wslpath -u "$win_path" 2>/dev/null)
            if test -n "$candidate"; and test -x "$candidate"
                printf '%s' "$candidate"
                return 0
            end
        end
    end

    return 1
end

# Bridge the Windows OpenSSH agent pipe to a unix socket with socat.
function _nredf_ssh_agent_start_wsl_bridge --argument-names sock
    if not type -q setsid; or not type -q socat
        printf "Warning: 'setsid' or 'socat' not found; SSH agent bridging not started.\n" >&2
        return 1
    end

    set -l npiperelay (_nredf_ssh_agent_find_npiperelay)
    if test -z "$npiperelay"
        printf "Error: npiperelay.exe not found\n" >&2
        printf "       Install it e.g.: \e[3mwinget install albertony.npiperelay\e[23m\n" >&2
        printf "       or point NPIPERELAY_PATH at it.\n" >&2
        return 1
    end

    set -l pid_file "$HOME/.ssh/socat_npiperelay.pid"
    if test -f "$pid_file"
        set -l old_pid (cat "$pid_file")
        # Only kill it if the PID still belongs to a socat (PIDs get recycled).
        if string match -qr '^[0-9]+$' -- "$old_pid"; and test -r "/proc/$old_pid/comm"; and test (cat "/proc/$old_pid/comm") = socat
            kill "$old_pid" &>/dev/null
        end
        rm -f "$pid_file"
    end

    # unlink-early lets socat replace a stale socket file itself.
    command setsid socat "UNIX-LISTEN:$sock,fork,unlink-early" \
        "EXEC:$npiperelay -ei -s //./pipe/openssh-ssh-agent,nofork" \
        </dev/null &>/dev/null &
    set -l pid $last_pid
    disown $pid 2>/dev/null
    echo $pid >"$pid_file"

    # Wait (max ~1s) for the listener to appear.
    for i in (seq 1 10)
        test -S "$sock"; and return 0
        sleep 0.1
    end
    return 1
end

# Start our own ssh-agent on a fixed socket. Several shells may start at once
# (terminal restore, multiplexer panes), so a mkdir lock serialises them and
# whoever loses the race just uses the winner's agent.
function _nredf_ssh_agent_start_own --argument-names sock
    set -l lock "$HOME/.ssh/auth_sock.lock"

    if not type -q ssh-agent
        printf "Warning: 'ssh-agent' not found; no SSH agent could be started.\n" >&2
        return 1
    end

    for i in (seq 1 30)
        mkdir "$lock" 2>/dev/null; and break
        # Another shell holds the lock: its agent may be up by now.
        if _nredf_ssh_agent_socket_works "$sock"
            set -gx SSH_AUTH_SOCK "$sock"
            return 0
        end
        sleep 0.1
        # Stale lock (shell killed mid-start): take it over after ~3s.
        if test $i -eq 30
            rmdir "$lock" 2>/dev/null
            mkdir "$lock" 2>/dev/null; or return 1
        end
    end

    set -l rc 1
    # Re-check under the lock; someone may have finished in the meantime.
    if _nredf_ssh_agent_socket_works "$sock"
        set rc 0
    else
        rm -f "$sock"
        set -e SSH_AGENT_PID
        # ssh-agent -s emits sh syntax, which fish's `eval` cannot interpret;
        # pull the PID out of its output text. SSH_AUTH_SOCK is known already
        # since we told ssh-agent -a which socket to bind.
        set -l agent_output (ssh-agent -s -a "$sock")
        set -l pid_match (string match -r 'SSH_AGENT_PID=([0-9]+);' -- $agent_output)
        if test (count $pid_match) -ge 2
            set -gx SSH_AGENT_PID $pid_match[2]
            _nredf_ssh_agent_socket_works "$sock"; and set rc 0
        end
    end
    rmdir "$lock" 2>/dev/null

    if test $rc -eq 0
        set -gx SSH_AUTH_SOCK "$sock"
        if test -n "$NREDF_PROFILE_STARTUP"; and type -q ssh-add
            env SSH_AUTH_SOCK="$sock" ssh-add -l &>/dev/null
            if test $status -eq 1
                printf "\033[1;33mAdd your SSH key(s) to the agent with 'ssh-add'\033[0m\n" >&2
            end
        end
    else
        printf "Warning: could not start ssh-agent on %s\n" "$sock" >&2
    end
    return $rc
end

function _nredf_ssh_agent_prepare_dir
    test -d "$HOME/.ssh"; and return 0
    set -l old_umask (umask)
    umask 077
    mkdir -p "$HOME/.ssh"
    umask $old_umask
end

# Try exactly one named provider.
function _nredf_ssh_agent_use_provider --argument-names mode
    switch "$mode"
        case 1password
            _nredf_set_ssh_agent_1password
        case bitwarden
            _nredf_set_ssh_agent_bitwarden
        case system
            _nredf_set_ssh_agent_system
        case gpg
            _nredf_set_ssh_agent_gpg
        case pipe
            _nredf_ssh_agent_is_wsl; or return 1
            set -l sock "$HOME/.ssh/auth_sock"
            if _nredf_ssh_agent_socket_works "$sock"
                set -gx SSH_AUTH_SOCK "$sock"
                return 0
            end
            _nredf_ssh_agent_prepare_dir
            _nredf_ssh_agent_start_wsl_bridge "$sock"; or return 1
            _nredf_ssh_agent_try_sockets "$sock"
        case '*'
            return 1
    end
end

function _nredf_set_ssh_agent
    set -l mode "$NREDF_SHELL_SSH_AGENT"
    test -n "$mode"; or set mode default
    test "$mode" = onepassword; and set mode 1password
    set -l auth_sock "$HOME/.ssh/auth_sock"

    # Never override a forwarded agent.
    test -n "$SSH_CONNECTION"; and return 0

    if test "$mode" != default
        # Explicit provider: it wins; otherwise fall back to whatever already works.
        _nredf_ssh_agent_use_provider "$mode"; and return 0
        _nredf_ssh_agent_socket_works "$SSH_AUTH_SOCK"; and return 0
        return 1
    end

    # default: keep a working agent. macOS launchd always provides its own
    # (usually empty) agent, which "works" and would shadow a running
    # 1Password/Bitwarden agent, so prefer those when available.
    if _nredf_ssh_agent_socket_works "$SSH_AUTH_SOCK"
        if string match -q '*/com.apple.launchd.*/Listeners' -- "$SSH_AUTH_SOCK"
            set -l launchd_sock "$SSH_AUTH_SOCK"
            _nredf_set_ssh_agent_1password; and return 0
            _nredf_set_ssh_agent_bitwarden; and return 0
            set -gx SSH_AUTH_SOCK "$launchd_sock"
        end
        return 0
    end

    # Previously started own agent / bridge.
    _nredf_ssh_agent_try_sockets "$auth_sock"; and return 0

    # Running desktop/systemd agents beat spawning a new process.
    _nredf_set_ssh_agent_1password; and return 0
    _nredf_set_ssh_agent_bitwarden; and return 0
    _nredf_set_ssh_agent_system; and return 0

    _nredf_ssh_agent_prepare_dir
    _nredf_ssh_agent_start_own "$auth_sock"
end
