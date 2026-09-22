#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

function _nredf_remote_multiplexer
    if test "$TERM_PROGRAM" = vscode
        return 0
    end

    # Never start the multiplexer in a non-interactive or background session.
    if not isatty stdin; or not isatty stdout
        return 0
    end

    type -q zellij; or return 0

    test -n "$ZELLIJ"; and return 0

    set -l is_ssh false
    if test -n "$SSH_TTY"; or test -n "$SSH_CONNECTION"; or test -n "$SSH_CLIENT"
        set is_ssh true
    end

    # Rendered by chezmoi into fish/rc.tmpl at apply time; see NREDF_WSL there.
    set -l is_wsl "$NREDF_WSL"
    test -n "$is_wsl"; or set is_wsl false

    set -l should_start false

    if test "$is_ssh" = true
        set -l multiplexer_enabled "$NREDF_SHELL_MULTIPLEXER"
        test -n "$multiplexer_enabled"; or set multiplexer_enabled "$NREDF_SHELL_GENERELL_MULTIPLEXER"
        test -n "$multiplexer_enabled"; or set multiplexer_enabled true
        if test "$multiplexer_enabled" != false
            set should_start true
        end
    else if test "$is_wsl" = true
        set -l wsl_multiplexer "$NREDF_SHELL_WSL_MULTIPLEXER"
        test -n "$wsl_multiplexer"; or set wsl_multiplexer "$NREDF_SHELL_MULTIPLEXER_WSL"
        test -n "$wsl_multiplexer"; or set wsl_multiplexer false
        if contains -- "$wsl_multiplexer" true 1 yes
            set should_start true
        end
    end

    if test "$should_start" != true
        return 0
    end

    set -l host_name "$HOSTNAME"
    if test -z "$host_name"; and test -n "$HOST"
        set host_name (string split -m1 . -- "$HOST")[1]
    end
    if test -z "$host_name"
        if type -q hostname
            set host_name (hostname -s 2>/dev/null)
        else if type -q hostnamectl
            set host_name (hostnamectl hostname 2>/dev/null)
        end
    end

    printf '\033[1mStarting multiplexer (zellij)\033[0m\n'
    zellij attach -c "$host_name"
end
