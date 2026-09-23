# chezmoi-managed nu function file.

def nredf-aqua-keyring-available []: nothing -> bool {
    if $env.NREDF_OS == "macos" {
        return true
    }

    # nu never runs on native Windows in a way that skips WSL here (it does
    # run natively on Windows, unlike fish — but the D-Bus secret-service
    # check below is still the right test on Linux/WSL either way).
    if (not ($env.WINDIR? | default "" | is-empty)) and (($env.WSL_DISTRO_NAME? | default "" | is-empty) and ($env.WSL_INTEROP? | default "" | is-empty)) {
        return true
    }

    mut bus = ($env.DBUS_SESSION_BUS_ADDRESS? | default "")
    if ($bus | is-empty) {
        let sock = ($"($env.XDG_RUNTIME_DIR? | default $"/run/user/(^id -u | str trim)")" | path join "bus")
        if ($sock | path type) == "socket" {
            $bus = $"unix:path=($sock)"
        } else {
            return false
        }
    }

    if not (which gdbus | is-empty) {
        return ((with-env {DBUS_SESSION_BUS_ADDRESS: $bus} {
            ^gdbus call --session --dest org.freedesktop.secrets --object-path /org/freedesktop/secrets --method org.freedesktop.DBus.Peer.Ping
        } | complete | get exit_code) == 0)
    }
    if not (which busctl | is-empty) {
        return ((with-env {DBUS_SESSION_BUS_ADDRESS: $bus} {
            ^busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.DBus.Peer Ping
        } | complete | get exit_code) == 0)
    }
    if not (which dbus-send | is-empty) {
        return ((with-env {DBUS_SESSION_BUS_ADDRESS: $bus} {
            ^dbus-send --session --dest=org.freedesktop.secrets --type=method_call --print-reply /org/freedesktop/secrets org.freedesktop.DBus.Peer.Ping
        } | complete | get exit_code) == 0)
    }

    false
}

def --env nredf-set-aqua-env [] {
    let aqua_base_config = ($env.XDG_CONFIG_HOME | path join "aquaproj-aqua" "aqua.yaml")
    let aqua_machine_config = ($env.XDG_CONFIG_HOME | path join "aquaproj-aqua" "machine.yaml")
    let aqua_policy_config = ($env.XDG_CONFIG_HOME | path join "aquaproj-aqua" "aqua-policy.yaml")
    let aqua_config_dir = ($env.NREDF_CONFIG? | default ($env.XDG_CONFIG_HOME | path join "nredf"))

    # Vault-derived (chezmoi-managed) first, then the runtime-local one
    # (nredf-aqua-token-setup's --env mode) so it can override — two different
    # owners of two different files on purpose: chezmoi would otherwise delete
    # a manually-configured token on every apply whenever the vault lookup
    # comes back empty (confirmed empirically).
    nredf-read-dotenv ($aqua_config_dir | path join "aqua-vault.env")
    nredf-read-dotenv ($aqua_config_dir | path join "aqua.env")

    # If the keyring is configured but unavailable on this system (e.g.
    # headless/WSL), deactivate AQUA_KEYRING_ENABLED to prevent aqua CLI errors.
    if (($env.AQUA_KEYRING_ENABLED? | default "") == "true") and not (nredf-aqua-keyring-available) {
        hide-env --ignore-errors AQUA_KEYRING_ENABLED
    }

    if ($aqua_base_config | path exists) {
        $env.AQUA_CONFIG = $aqua_base_config
        $env.AQUA_GLOBAL_CONFIG = $aqua_base_config
        if ($aqua_machine_config | path exists) {
            $env.AQUA_GLOBAL_CONFIG = $"($aqua_base_config):($aqua_machine_config)"
        }
    }

    if ($aqua_policy_config | path exists) {
        $env.AQUA_POLICY_CONFIG = $aqua_policy_config
    }
}

def --env nredf-set-aqua-path [] {
    let aqua_bin = (($env.AQUA_ROOT_DIR? | default (($env.XDG_DATA_HOME? | default ($env.HOME | path join ".local" "share")) | path join "aquaproj-aqua")) | path join "bin")
    if not ($aqua_bin in $env.PATH) {
        $env.PATH = ($env.PATH | prepend $aqua_bin)
    }
}

def nredf-aqua-auth-config-file []: nothing -> string {
    (($env.NREDF_CONFIG? | default ($env.XDG_CONFIG_HOME | path join "nredf")) | path join "aqua.env")
}

# This file is shared with bash/zsh (which `source` it directly) and
# PowerShell (which parses it, like nredf-read-dotenv above), so it must stay
# valid POSIX-shell `[export] KEY='value'` syntax regardless of which shell
# wrote it — never nu's own `$env.X = ...` syntax here.
def nredf-write-aqua-auth-config [mode: string, token: string = ""] {
    let auth_file = (nredf-aqua-auth-config-file)
    let auth_dir = ($auth_file | path dirname)
    if not ($auth_dir | path exists) {
        mkdir $auth_dir
    }
    let tmp_file = (^mktemp $"($auth_dir)/aqua.env.XXXXXX" | str trim)

    mut lines = ["# Local aqua GitHub auth preferences" $"NREDF_AQUA_GITHUB_TOKEN_SETUP=(nredf-posix-quote $mode)"]
    if $mode == "keyring" {
        $lines = ($lines | append $"AQUA_KEYRING_ENABLED=(nredf-posix-quote 'true')")
    } else if ($mode == "env") and (not ($token | is-empty)) {
        $lines = ($lines | append $"export AQUA_GITHUB_TOKEN=(nredf-posix-quote $token)")
        $lines = ($lines | append $"export GITHUB_TOKEN=(nredf-posix-quote $token)")
    }

    ($lines | str join "\n") + "\n" | save --force $tmp_file
    ^chmod 600 $tmp_file
    mv $tmp_file $auth_file
}

def nredf-posix-quote [val: string]: nothing -> string {
    $"'($val | str replace --all "'" "'\\''")'"
}

def --env nredf-clear-aqua-auth-config [] {
    rm --force (nredf-aqua-auth-config-file)
    hide-env --ignore-errors AQUA_KEYRING_ENABLED
    hide-env --ignore-errors NREDF_AQUA_GITHUB_TOKEN_SETUP
    hide-env --ignore-errors AQUA_GITHUB_TOKEN
    hide-env --ignore-errors GITHUB_TOKEN
}

# nu has no builtin for "is /dev/tty readable and writable" the way bash's
# `[[ -r /dev/tty && -w /dev/tty ]]` is a plain permission-bit test — reuse
# the external POSIX `test` for the exact same (imperfect, permission-bit-
# only) semantics bash and fish both already accept here.
def nredf-tty-readable-writable []: nothing -> bool {
    ((^test -r /dev/tty | complete | get exit_code) == 0) and ((^test -w /dev/tty | complete | get exit_code) == 0)
}

# Returns 0 = yes, 1 = no, 2 = unanswered (no usable terminal, EOF, or no
# `timeout`/`gtimeout` binary to bound the wait) — "unanswered" must never be
# conflated with "no". nu's `input` has no timeout flag at all (same gap as
# fish's `read`), so this shells out to `timeout`/`gtimeout` if present;
# otherwise it falls back to an untimed prompt, still gated on being a real
# interactive session — see docs/shells.md's parity-exceptions section.
def nredf-prompt-yes-no [prompt: string] {
    if not (nredf-tty-readable-writable) {
        return 2
    }

    mut timeout_bin = ""
    if not (which timeout | is-empty) {
        $timeout_bin = "timeout"
    } else if not (which gtimeout | is-empty) {
        $timeout_bin = "gtimeout"
    }
    let timeout_secs = ($env.NREDF_PROMPT_TIMEOUT? | default "30")

    loop {
        print --no-newline $"($prompt) [y/N]: "
        mut reply = ""
        if not ($timeout_bin | is-empty) {
            let result = (^$timeout_bin $timeout_secs nu -c "input") | complete
            if $result.exit_code != 0 {
                print ""
                return 2
            }
            $reply = ($result.stdout | str trim)
        } else {
            $reply = (input | str trim)
        }
        if $reply in ["y" "Y" "yes" "YES"] {
            return 0
        }
        if $reply in ["n" "N" "no" "NO" ""] {
            return 1
        }
        print "Please answer yes or no."
    }
}

def --env nredf-aqua-token-setup [action: string = "--set"] {
    nredf-init-paths

    if $action == "--keyring" {
        if (which aqua | is-empty) {
            print --stderr "aqua is not installed."
            return
        }
        if not (nredf-aqua-keyring-available) {
            print --stderr "System keyring (org.freedesktop.secrets) is not available on this system."
            print --stderr "Use 'nredf-aqua-token-setup --env' to store the token in local aqua.env instead."
            return
        }
        if (^aqua token set | complete | get exit_code) != 0 {
            return
        }
        nredf-write-aqua-auth-config "keyring"
        $env.AQUA_KEYRING_ENABLED = "true"
        $env.NREDF_AQUA_GITHUB_TOKEN_SETUP = "keyring"
        print "Stored aqua's GitHub token in the system keyring."
    } else if $action == "--env" {
        print --no-newline "Enter a GitHub access token: "
        let token = (input --suppress-output | str trim)
        print ""

        if ($token | is-empty) {
            print --stderr "Error: Token cannot be empty."
            return
        }

        nredf-write-aqua-auth-config "env" $token
        $env.AQUA_GITHUB_TOKEN = $token
        $env.GITHUB_TOKEN = $token
        $env.NREDF_AQUA_GITHUB_TOKEN_SETUP = "env"
        hide-env --ignore-errors AQUA_KEYRING_ENABLED
        print $"Stored aqua's GitHub token in (nredf-aqua-auth-config-file) \(mode 0600\)."
    } else if $action == "--set" {
        if (nredf-aqua-keyring-available) {
            nredf-aqua-token-setup "--keyring"
            if (($env.NREDF_AQUA_GITHUB_TOKEN_SETUP? | default "") == "keyring") {
                return
            }
            print "Keyring setup failed. Falling back to file-based token storage..."
        }
        nredf-aqua-token-setup "--env"
    } else if $action == "--skip" {
        nredf-write-aqua-auth-config "skip"
        hide-env --ignore-errors AQUA_KEYRING_ENABLED
        $env.NREDF_AQUA_GITHUB_TOKEN_SETUP = "skip"
        print "Skipping aqua GitHub token setup for now."
    } else if $action == "--reset" {
        nredf-clear-aqua-auth-config
        print "Reset aqua GitHub token preference."
    } else if $action == "--status" {
        let auth_file = (nredf-aqua-auth-config-file)
        print "=== aqua GitHub Token Status ==="
        if not ($env.AQUA_GITHUB_TOKEN? | default "" | is-empty) {
            print $"AQUA_GITHUB_TOKEN: set \(length: ($env.AQUA_GITHUB_TOKEN | str length)\)"
        } else {
            print "AQUA_GITHUB_TOKEN: unset"
        }
        if not ($env.GITHUB_TOKEN? | default "" | is-empty) {
            print $"GITHUB_TOKEN:      set \(length: ($env.GITHUB_TOKEN | str length)\)"
        } else {
            print "GITHUB_TOKEN:      unset"
        }
        print $"AQUA_KEYRING_ENABLED: ($env.AQUA_KEYRING_ENABLED? | default 'unset')"
        print $"Setup state:          ($env.NREDF_AQUA_GITHUB_TOKEN_SETUP? | default 'unset')"
        if ($auth_file | path exists) {
            print $"Auth config file:     ($auth_file) [exists]"
        } else {
            print $"Auth config file:     ($auth_file) [missing]"
        }
        if (nredf-aqua-keyring-available) {
            print "System keyring:       available"
        } else {
            print "System keyring:       unavailable (headless / WSL / no secret service)"
        }
    } else {
        print --stderr "Usage: nredf-aqua-token-setup [--set|--keyring|--env|--skip|--reset|--status]"
    }
}

def --env nredf-ensure-aqua-github-token [] {
    if not $nu.is-interactive {
        return
    }
    let setup_state_initial = ($env.NREDF_AQUA_GITHUB_TOKEN_SETUP? | default "")

    # Interactive, but with nothing to ask on: do nothing (and record nothing).
    if not (nredf-tty-readable-writable) {
        return
    }
    if (which aqua | is-empty) {
        return
    }
    if (not ($env.AQUA_GITHUB_TOKEN? | default "" | is-empty)) or (not ($env.GITHUB_TOKEN? | default "" | is-empty)) {
        return
    }

    mut setup_state = $setup_state_initial
    if (($env.AQUA_KEYRING_ENABLED? | default "") == "true") or ($setup_state == "keyring") {
        if (nredf-aqua-keyring-available) {
            $env.AQUA_KEYRING_ENABLED = "true"
            return
        }
        hide-env --ignore-errors AQUA_KEYRING_ENABLED
    }

    let auth_file = (nredf-aqua-auth-config-file)
    if ($setup_state | is-empty) and ($auth_file | path exists) {
        nredf-read-dotenv $auth_file
        $setup_state = ($env.NREDF_AQUA_GITHUB_TOKEN_SETUP? | default "")
    }

    if (not ($env.AQUA_GITHUB_TOKEN? | default "" | is-empty)) or (not ($env.GITHUB_TOKEN? | default "" | is-empty)) {
        return
    }

    if (($env.AQUA_KEYRING_ENABLED? | default "") == "true") or ($setup_state == "keyring") {
        if (nredf-aqua-keyring-available) {
            $env.AQUA_KEYRING_ENABLED = "true"
            return
        }
        hide-env --ignore-errors AQUA_KEYRING_ENABLED
    }

    if $setup_state == "skip" {
        return
    }

    if (nredf-aqua-keyring-available) {
        let answer = (nredf-prompt-yes-no "No GitHub token configured for aqua. Store one in the system keyring now?")
        if $answer == 1 {
            nredf-aqua-token-setup "--skip"
            print "Run 'nredf-aqua-token-setup' later to configure aqua's GitHub token."
            return
        } else if $answer == 2 {
            return
        }

        nredf-aqua-token-setup "--keyring"
        if (($env.NREDF_AQUA_GITHUB_TOKEN_SETUP? | default "") != "keyring") {
            let auth_file2 = (nredf-aqua-auth-config-file)
            let answer2 = (nredf-prompt-yes-no $"Keyring setup failed. Store token in ($auth_file2) \(mode 0600\) instead?")
            if $answer2 == 0 {
                nredf-aqua-token-setup "--env"
            } else if $answer2 == 1 {
                nredf-aqua-token-setup "--skip"
                print "Skipping aqua GitHub token setup for now."
            }
        }
    } else {
        print $"\e[1;33mNo GitHub token configured for aqua \(system keyring unavailable on this system\).\e[0m"
        let answer = (nredf-prompt-yes-no $"Store token in ($auth_file) \(mode 0600\) now?")
        if $answer == 0 {
            nredf-aqua-token-setup "--env"
        } else if $answer == 1 {
            nredf-aqua-token-setup "--skip"
            print "Skipping aqua GitHub token setup for now. Run 'nredf-aqua-token-setup' later to configure."
        }
    }
}
