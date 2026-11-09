# chezmoi-managed nu function file.
#
# Picks the SSH agent for this shell and exports SSH_AUTH_SOCK. Mirrors
# common/functions/nredf_set_ssh_agent.bash — keep the two in sync.
#
# shell.ssh.agent (NREDF_SHELL_SSH_AGENT): default | 1password | onepassword |
# bitwarden | system | gpg | pipe (WSL only). Agent probes run under a timeout
# so a locked desktop agent can never hang shell startup.
#
# Every function that (transitively) assigns $env.SSH_AUTH_SOCK is `def --env`;
# a single plain `def` in that chain would silently swallow the mutation.

# Health check: ssh-add -l exits 0 (keys) or 1 (no keys) for a live agent;
# anything else (2 = unreachable, 124 = timed out) is a dead one.
def nredf-ssh-agent-socket-works [sock: string = ""]: nothing -> bool {
    if ($sock | is-empty) or (($sock | path type) != "socket") {
        return false
    }
    if (which ssh-add | is-empty) {
        return true
    }

    let rc = if not (which timeout | is-empty) {
        with-env {SSH_AUTH_SOCK: $sock} { ^timeout 2 ssh-add -l } | complete | get exit_code
    } else if not (which gtimeout | is-empty) {
        with-env {SSH_AUTH_SOCK: $sock} { ^gtimeout 2 ssh-add -l } | complete | get exit_code
    } else {
        with-env {SSH_AUTH_SOCK: $sock} { ^ssh-add -l } | complete | get exit_code
    }
    ($rc == 0) or ($rc == 1)
}

# Export the first candidate socket that answers.
def --env nredf-ssh-agent-try-sockets [candidates: list<string>]: nothing -> bool {
    for sock in $candidates {
        if (nredf-ssh-agent-socket-works $sock) {
            $env.SSH_AUTH_SOCK = $sock
            return true
        }
    }
    false
}

def nredf-ssh-agent-is-wsl []: nothing -> bool {
    not (($env.WSL_DISTRO_NAME? | default "") | is-empty) or not (($env.WSL_INTEROP? | default "") | is-empty)
}

def --env nredf-set-ssh-agent-1password []: nothing -> bool {
    if $env.NREDF_OS == "macos" {
        nredf-ssh-agent-try-sockets [
            ($env.HOME | path join "Library" "Group Containers" "2BUA8C4S2C.com.1password" "t" "agent.sock")
        ]
    } else {
        nredf-ssh-agent-try-sockets [
            ($env.HOME | path join ".1password" "agent.sock")
            ($env.HOME | path join ".config" "1Password" "agent.sock")
        ]
    }
}

def --env nredf-set-ssh-agent-bitwarden []: nothing -> bool {
    if $env.NREDF_OS == "macos" {
        nredf-ssh-agent-try-sockets [
            ($env.HOME | path join "Library" "Containers" "com.bitwarden.desktop" "Data" ".bitwarden-ssh-agent.sock")
            ($env.HOME | path join ".bitwarden-ssh-agent.sock")
        ]
    } else {
        nredf-ssh-agent-try-sockets [
            ($env.HOME | path join ".bitwarden-ssh-agent.sock")
            ($env.HOME | path join "snap" "bitwarden" "current" ".bitwarden-ssh-agent.sock")
            ($env.HOME | path join ".var" "app" "com.bitwarden.desktop" "data" ".bitwarden-ssh-agent.sock")
        ]
    }
}

def --env nredf-set-ssh-agent-system []: nothing -> bool {
    # `^id -u` only runs when XDG_RUNTIME_DIR is actually unset.
    let runtime_dir = if ($env.XDG_RUNTIME_DIR? | default "" | is-empty) {
        $"/run/user/(^id -u | str trim)"
    } else {
        $env.XDG_RUNTIME_DIR
    }
    nredf-ssh-agent-try-sockets [
        ($runtime_dir | path join "ssh-agent.socket")
        ($runtime_dir | path join "gcr" "ssh")
        ($runtime_dir | path join "keyring" "ssh")
    ]
}

def --env nredf-set-ssh-agent-gpg []: nothing -> bool {
    if (which gpgconf | is-empty) {
        return false
    }
    let sock = (^gpgconf --list-dirs agent-ssh-socket | complete | get stdout | str trim)
    if ($sock | is-empty) {
        return false
    }

    # The socket only exists once gpg-agent runs (and has enable-ssh-support).
    if ($sock | path type) != "socket" {
        ^gpgconf --launch gpg-agent | complete | ignore
    }

    hide-env --ignore-errors SSH_AGENT_PID
    nredf-ssh-agent-try-sockets [$sock]
}

# Resolve the Windows-side npiperelay.exe; returns "" when not found.
def nredf-ssh-agent-find-npiperelay []: nothing -> string {
    # 1. Explicit user override
    let override = ($env.NPIPERELAY_PATH? | default "")
    if (not ($override | is-empty)) and ((^test -x $override | complete | get exit_code) == 0) {
        return $override
    }

    # 2. Default winget location
    if not (which whoami.exe | is-empty) {
        let win_user = (^whoami.exe | complete | get stdout | str replace --regex '.*\\' '' | str trim)
        let candidate = $"/mnt/c/Users/($win_user)/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay_Microsoft.Winget.Source_8wekyb3d8bbwe/npiperelay.exe"
        if (not ($win_user | is-empty)) and ((^test -x $candidate | complete | get exit_code) == 0) {
            return $candidate
        }
    }

    # 3. Anything on the Windows PATH
    if (not (which where.exe | is-empty)) and (not (which wslpath | is-empty)) {
        let win_path = (^where.exe npiperelay.exe | complete | get stdout | str trim | lines | get 0? | default "")
        if not ($win_path | is-empty) {
            let candidate = (^wslpath -u $win_path | complete | get stdout | str trim)
            if (not ($candidate | is-empty)) and ((^test -x $candidate | complete | get exit_code) == 0) {
                return $candidate
            }
        }
    }

    ""
}

# Bridge the Windows OpenSSH agent pipe to a unix socket with socat.
def nredf-ssh-agent-start-wsl-bridge [sock: string]: nothing -> bool {
    if (which setsid | is-empty) or (which socat | is-empty) {
        print --stderr "Warning: 'setsid' or 'socat' not found; SSH agent bridging not started."
        return false
    }

    let npiperelay = (nredf-ssh-agent-find-npiperelay)
    if ($npiperelay | is-empty) {
        print --stderr "Error: npiperelay.exe not found"
        print --stderr "       Install it e.g.: \e[3mwinget install albertony.npiperelay\e[23m"
        print --stderr "       or point NPIPERELAY_PATH at it."
        return false
    }

    let pid_file = ($env.HOME | path join ".ssh" "socat_npiperelay.pid")
    if ($pid_file | path exists) {
        let old_pid = (open $pid_file | into string | str trim)
        # Only kill it if the PID still belongs to a socat (PIDs get recycled).
        let comm_file = $"/proc/($old_pid)/comm"
        if ($old_pid =~ '^[0-9]+$') and ($comm_file | path exists) and ((open $comm_file | into string | str trim) == "socat") {
            ^kill $old_pid | complete | ignore
        }
        rm --force $pid_file
    }

    # nu has no `&`/`disown`, so let sh start socat detached and report its PID.
    # unlink-early lets socat replace a stale socket file itself.
    let sock_arg = $"UNIX-LISTEN:($sock),fork,unlink-early"
    let exec_arg = $"EXEC:($npiperelay) -ei -s //./pipe/openssh-ssh-agent,nofork"
    let pid = (^sh -c 'setsid socat "$1" "$2" </dev/null >/dev/null 2>&1 & echo $!' sh $sock_arg $exec_arg | complete | get stdout | str trim)
    if ($pid | is-empty) {
        return false
    }
    $pid | save --force $pid_file

    # Wait (max ~1s) for the listener to appear.
    for _ in 1..10 {
        if ($sock | path type) == "socket" {
            return true
        }
        sleep 100ms
    }
    false
}

# Start our own ssh-agent on a fixed socket. Several shells may start at once
# (terminal restore, multiplexer panes), so a mkdir lock serialises them and
# whoever loses the race just uses the winner's agent.
def --env nredf-ssh-agent-start-own [sock: string]: nothing -> bool {
    let lock = ($env.HOME | path join ".ssh" "auth_sock.lock")

    if (which ssh-agent | is-empty) {
        print --stderr "Warning: 'ssh-agent' not found; no SSH agent could be started."
        return false
    }

    # nu's own `mkdir` is always idempotent, so it cannot act as a mutex; use
    # the external binary, which fails on an existing directory.
    mut locked = false
    for i in 1..30 {
        if (^mkdir $lock | complete | get exit_code) == 0 {
            $locked = true
            break
        }
        # Another shell holds the lock: its agent may be up by now.
        if (nredf-ssh-agent-socket-works $sock) {
            $env.SSH_AUTH_SOCK = $sock
            return true
        }
        sleep 100ms
        # Stale lock (shell killed mid-start): take it over after ~3s.
        if $i == 30 {
            ^rmdir $lock | complete | ignore
            $locked = ((^mkdir $lock | complete | get exit_code) == 0)
        }
    }
    if not $locked {
        return false
    }

    mut ok = false
    # Re-check under the lock; someone may have finished in the meantime.
    if (nredf-ssh-agent-socket-works $sock) {
        $ok = true
    } else {
        rm --force $sock
        hide-env --ignore-errors SSH_AGENT_PID
        # ssh-agent -s emits sh syntax that nu cannot `source` (same gap as
        # fish) — pull the PID out of its output text instead.
        let agent_output = (^ssh-agent -s -a $sock | complete | get stdout)
        let pid_match = ($agent_output | str replace --regex '(?s).*SSH_AGENT_PID=([0-9]+);.*' '$1')
        if $pid_match =~ '^[0-9]+$' {
            $env.SSH_AGENT_PID = $pid_match
            $ok = (nredf-ssh-agent-socket-works $sock)
        }
    }
    ^rmdir $lock | complete | ignore

    if $ok {
        $env.SSH_AUTH_SOCK = $sock
        if (not ($env.NREDF_PROFILE_STARTUP? | default "" | is-empty)) and (not (which ssh-add | is-empty)) {
            let rc = (with-env {SSH_AUTH_SOCK: $sock} { ^ssh-add -l } | complete | get exit_code)
            if $rc == 1 {
                print --stderr "\e[1;33mAdd your SSH key\(s\) to the agent with 'ssh-add'\e[0m"
            }
        }
    } else {
        print --stderr $"Warning: could not start ssh-agent on ($sock)"
    }
    $ok
}

def nredf-ssh-agent-prepare-dir [] {
    let dir = ($env.HOME | path join ".ssh")
    if not ($dir | path exists) {
        # mkdir -m is atomic, so there is no window where ~/.ssh is world-readable.
        ^mkdir -m 700 -p $dir
    }
}

# Try exactly one named provider.
def --env nredf-ssh-agent-use-provider [mode: string]: nothing -> bool {
    match $mode {
        "1password" => { nredf-set-ssh-agent-1password }
        "bitwarden" => { nredf-set-ssh-agent-bitwarden }
        "system" => { nredf-set-ssh-agent-system }
        "gpg" => { nredf-set-ssh-agent-gpg }
        "pipe" => {
            if not (nredf-ssh-agent-is-wsl) {
                return false
            }
            let sock = ($env.HOME | path join ".ssh" "auth_sock")
            if (nredf-ssh-agent-socket-works $sock) {
                $env.SSH_AUTH_SOCK = $sock
                return true
            }
            nredf-ssh-agent-prepare-dir
            if not (nredf-ssh-agent-start-wsl-bridge $sock) {
                return false
            }
            nredf-ssh-agent-try-sockets [$sock]
        }
        _ => { false }
    }
}

def --env nredf-set-ssh-agent [] {
    # Native Windows uses OpenSSH's own ssh-agent service over a named pipe
    # (\\.\pipe\openssh-ssh-agent), which ssh.exe finds with SSH_AUTH_SOCK
    # unset. Everything below is Unix-socket logic that would either fail
    # outright or export a Unix path that overrides the pipe — same documented
    # gap as PowerShell (docs/shells.md). WSL reports NREDF_OS == "linux", so
    # its npiperelay bridge is unaffected.
    if ($env.NREDF_OS? | default "") == "windows" {
        return
    }

    # Never override a forwarded agent.
    if not ($env.SSH_CONNECTION? | default "" | is-empty) {
        return
    }

    mut mode = ($env.NREDF_SHELL_SSH_AGENT? | default "default")
    if $mode == "onepassword" {
        $mode = "1password"
    }
    let auth_sock = ($env.HOME | path join ".ssh" "auth_sock")
    let current = ($env.SSH_AUTH_SOCK? | default "")

    if $mode != "default" {
        # Explicit provider: it wins; otherwise fall back to whatever already works.
        nredf-ssh-agent-use-provider $mode | ignore
        return
    }

    # default: keep a working agent. macOS launchd always provides its own
    # (usually empty) agent, which "works" and would shadow a running
    # 1Password/Bitwarden agent, so prefer those when available.
    if (nredf-ssh-agent-socket-works $current) {
        if ($current =~ '/com\.apple\.launchd\..*/Listeners$') {
            if (nredf-set-ssh-agent-1password) or (nredf-set-ssh-agent-bitwarden) {
                return
            }
            $env.SSH_AUTH_SOCK = $current
        }
        return
    }

    # Previously started own agent / bridge.
    if (nredf-ssh-agent-try-sockets [$auth_sock]) { return }

    # Running desktop/systemd agents beat spawning a new process.
    if (nredf-set-ssh-agent-1password) { return }
    if (nredf-set-ssh-agent-bitwarden) { return }
    if (nredf-set-ssh-agent-system) { return }

    nredf-ssh-agent-prepare-dir
    nredf-ssh-agent-start-own $auth_sock | ignore
}
