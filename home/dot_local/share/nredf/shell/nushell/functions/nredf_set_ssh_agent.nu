# chezmoi-managed nu function file.

def --env nredf-set-ssh-agent-wsl [] {
    if (which whoami.exe | is-empty) {
        print --stderr "Error: whoami.exe not found in PATH. Please ensure it is available."
        return false
    }
    let windows_user = (^whoami.exe | str replace --regex '.*\\' '' | str trim)

    let npiperelay_default = $"/mnt/c/Users/($windows_user)/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe/npiperelay.exe"
    mut npiperelay = ($env.NPIPERELAY_PATH? | default $npiperelay_default)

    let npiperelay_executable = ((^test -x $npiperelay | complete | get exit_code) == 0)
    if (not $npiperelay_executable) and (not (which where.exe | is-empty)) and (not (which wslpath | is-empty)) {
        let win_npiperelay = (^cmd.exe /c "where.exe npiperelay.exe" | complete | get stdout | str trim | lines | get 0? | default "")
        if not ($win_npiperelay | is-empty) {
            let npiperelay_unix = (^wslpath -u $win_npiperelay | complete | get stdout | str trim)
            if not ($npiperelay_unix | is-empty) {
                $npiperelay = ($env.NPIPERELAY_PATH? | default $npiperelay_unix)
            }
        } else {
            print --stderr "Error: npiperelay.exe is not executable"
            print --stderr "       Please ensure that npiperelay.exe is installed and accessible e.g.:"
            print --stderr "       \e[3mwinget install albertony.npiperelay\e[23m"
            return false
        }
    }

    if (not (which setsid | is-empty)) and (not (which socat | is-empty)) {
        let socat_pid_file = ($env.HOME | path join ".ssh" "socat_npiperelay.pid")
        if ($socat_pid_file | path exists) {
            let old_pid = (open $socat_pid_file | into string | str trim)
            if (^kill -0 $old_pid | complete | get exit_code) == 0 {
                ^kill $old_pid | complete
            }
            rm --force $socat_pid_file
        }
        let sock_arg = $"UNIX-LISTEN:($env.SSH_AUTH_SOCK),fork"
        let exec_arg = $"EXEC:($npiperelay) -ei -s //./pipe/openssh-ssh-agent,nofork"
        job spawn { ^setsid socat $sock_arg $exec_arg | complete | ignore }
        sleep 100ms
        let new_pid = (^pgrep -f $"socat UNIX-LISTEN:($env.SSH_AUTH_SOCK)" | complete | get stdout | str trim | lines | get 0? | default "")
        if not ($new_pid | is-empty) {
            $new_pid | save --force $socat_pid_file
        }
    } else {
        print --stderr "Warning: 'setsid' or 'socat' not found; SSH agent bridging not started."
    }
    true
}

def nredf-ssh-agent-1password-candidates []: nothing -> list<string> {
    if $env.NREDF_OS == "macos" {
        [($env.HOME | path join "Library" "Group Containers" "2BUA8C4S2C.com.1password" "t" "agent.sock")]
    } else {
        [
            ($env.HOME | path join ".1password" "agent.sock")
            ($env.HOME | path join ".config" "1Password" "agent.sock")
        ]
    }
}

def --env nredf-set-ssh-agent-1password [] {
    for sock in (nredf-ssh-agent-1password-candidates) {
        if (($sock | path type) == "socket") and (nredf-ssh-agent-socket-works $sock) {
            $env.SSH_AUTH_SOCK = $sock
            return true
        }
    }
    false
}

def --env nredf-set-ssh-agent-system [] {
    let runtime_dir = ($env.XDG_RUNTIME_DIR? | default $"/run/user/(^id -u | str trim)")
    for sock in [
        ($runtime_dir | path join "ssh-agent.socket")
        ($runtime_dir | path join "gcr" "ssh")
        ($runtime_dir | path join "keyring" "ssh")
    ] {
        if (($sock | path type) == "socket") and (nredf-ssh-agent-socket-works $sock) {
            $env.SSH_AUTH_SOCK = $sock
            return true
        }
    }
    false
}

def nredf-ssh-agent-bitwarden-candidates []: nothing -> list<string> {
    if $env.NREDF_OS == "macos" {
        [
            ($env.HOME | path join "Library" "Containers" "com.bitwarden.desktop" "Data" ".bitwarden-ssh-agent.sock")
            ($env.HOME | path join ".bitwarden-ssh-agent.sock")
        ]
    } else {
        [
            ($env.HOME | path join ".bitwarden-ssh-agent.sock")
            ($env.HOME | path join "snap" "bitwarden" "current" ".bitwarden-ssh-agent.sock")
            ($env.HOME | path join ".var" "app" "com.bitwarden.desktop" "data" ".bitwarden-ssh-agent.sock")
        ]
    }
}

def --env nredf-set-ssh-agent-bitwarden [] {
    for sock in (nredf-ssh-agent-bitwarden-candidates) {
        if (($sock | path type) == "socket") and (nredf-ssh-agent-socket-works $sock) {
            $env.SSH_AUTH_SOCK = $sock
            return true
        }
    }
    false
}

def --env nredf-set-ssh-agent-gpg [] {
    if not (which gpgconf | is-empty) {
        # Only set SSH_AUTH_SOCK if not in an SSH session and this shell did
        # not already set it (gnupg_SSH_AUTH_SOCK_by tracks the PID that set it).
        if ($env.SSH_CONNECTION? | default "" | is-empty) and (($env.gnupg_SSH_AUTH_SOCK_by? | default "") != ($nu.pid | into string)) {
            hide-env --ignore-errors SSH_AGENT_PID
            $env.SSH_AUTH_SOCK = (^gpgconf --list-dirs agent-ssh-socket | str trim)
            $env.gnupg_SSH_AUTH_SOCK_by = ($nu.pid | into string)
        }
    }
}

def nredf-ssh-agent-socket-works [sock: string = ""]: nothing -> bool {
    let s = (if ($sock | is-empty) { $env.SSH_AUTH_SOCK? | default "" } else { $sock })

    if ($s | is-empty) or (not (($s | path type) == "socket")) {
        return false
    }

    if not (which ssh-add | is-empty) {
        let rc = (with-env {SSH_AUTH_SOCK: $s} { ^ssh-add -l } | complete | get exit_code)
        return (($rc == 0) or ($rc == 1))
    }

    true
}

def nredf-configured-ssh-agent-mode []: nothing -> string {
    $env.NREDF_SHELL_SSH_AGENT? | default "default"
}

def --env nredf-set-ssh-agent [] {
    let agent_mode = (nredf-configured-ssh-agent-mode)
    let prefer_external_provider = ($agent_mode != "default")

    # Do not override a forwarded SSH agent.
    if not ($env.SSH_CONNECTION? | default "" | is-empty) {
        return
    }

    if $prefer_external_provider {
        if ($agent_mode == "pipe") and (not ($env.WSL_DISTRO_NAME? | default "" | is-empty) or not ($env.WSL_INTEROP? | default "" | is-empty)) {
            $env.SSH_AUTH_SOCK = ($env.HOME | path join ".ssh" "auth_sock")
            nredf-set-ssh-agent-wsl
            if (nredf-ssh-agent-socket-works $env.SSH_AUTH_SOCK) { return }
        }
        if $agent_mode == "gpg" {
            nredf-set-ssh-agent-gpg
            if (nredf-ssh-agent-socket-works ($env.SSH_AUTH_SOCK? | default "")) { return }
        }
        if $agent_mode == "bitwarden" {
            nredf-set-ssh-agent-bitwarden
            if (nredf-ssh-agent-socket-works ($env.SSH_AUTH_SOCK? | default "")) { return }
        }
        if ($agent_mode == "1password") or ($agent_mode == "onepassword") {
            nredf-set-ssh-agent-1password
            if (nredf-ssh-agent-socket-works ($env.SSH_AUTH_SOCK? | default "")) { return }
        }
        if $agent_mode == "system" {
            nredf-set-ssh-agent-system
            if (nredf-ssh-agent-socket-works ($env.SSH_AUTH_SOCK? | default "")) { return }
        }
        if (nredf-ssh-agent-socket-works ($env.SSH_AUTH_SOCK? | default "")) {
            return
        }
    } else {
        if (nredf-ssh-agent-socket-works ($env.SSH_AUTH_SOCK? | default "")) {
            return
        }
    }

    if not (($env.HOME | path join ".ssh") | path exists) {
        mkdir ($env.HOME | path join ".ssh")
        ^chmod 700 ($env.HOME | path join ".ssh")
    }

    let auth_sock = ($env.HOME | path join ".ssh" "auth_sock")
    if (nredf-ssh-agent-socket-works $auth_sock) {
        $env.SSH_AUTH_SOCK = $auth_sock
        return
    }

    rm --force $auth_sock

    if ($agent_mode == "pipe") and (not ($env.WSL_DISTRO_NAME? | default "" | is-empty) or not ($env.WSL_INTEROP? | default "" | is-empty)) {
        $env.SSH_AUTH_SOCK = $auth_sock
        if not (nredf-set-ssh-agent-wsl) {
            print --stderr "Error: Failed to set up WSL SSH agent bridge"
            return
        }
    } else if $agent_mode == "gpg" {
        nredf-set-ssh-agent-gpg
    } else if $agent_mode == "bitwarden" {
        nredf-set-ssh-agent-bitwarden
    } else if ($agent_mode == "1password") or ($agent_mode == "onepassword") {
        nredf-set-ssh-agent-1password
    } else if $agent_mode == "system" {
        nredf-set-ssh-agent-system
    } else {
        if (nredf-set-ssh-agent-1password) { return }
        if (nredf-set-ssh-agent-bitwarden) { return }
        if (nredf-set-ssh-agent-system) { return }

        $env.SSH_AUTH_SOCK = $auth_sock
        if not (which ssh-agent | is-empty) {
            hide-env --ignore-errors SSH_AGENT_PID
            # ssh-agent -s emits sh/bash syntax that nu cannot `source` (same
            # gap as fish) — pull the PID out of its output text instead.
            let agent_output = (^ssh-agent -s -a $env.SSH_AUTH_SOCK | complete | get stdout)
            let pid_match = ($agent_output | str replace --regex '(?s).*SSH_AGENT_PID=([0-9]+);.*' '$1')
            if $pid_match =~ '^[0-9]+$' {
                $env.SSH_AGENT_PID = $pid_match
            }
        } else {
            print --stderr "Warning: 'ssh-agent' not found; no SSH agent could be started."
            return
        }
    }

    if (($env.SSH_AUTH_SOCK | path type) == "socket") and (not (which ssh-add | is-empty)) {
        let exit_code = (^ssh-add -l | complete | get exit_code)
        if $exit_code == 1 {
            if not ($env.NREDF_PROFILE_STARTUP? | default "" | is-empty) {
                print --stderr "\e[1;33mAdd your SSH key\(s\) to the agent with 'ssh-add'\e[0m"
            }
        } else if $exit_code > 1 {
            print --stderr "Warning: SSH agent socket exists but agent is not responding"
        }
    }
}
