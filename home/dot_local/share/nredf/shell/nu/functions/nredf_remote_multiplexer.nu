# chezmoi-managed nu function file.

def nredf-remote-multiplexer [] {
    if (($env.TERM_PROGRAM? | default "") == "vscode") {
        return
    }

    # Never start the multiplexer in a non-interactive or background session.
    if (not (is-terminal --stdin)) or (not (is-terminal --stdout)) {
        return
    }

    if ((which zellij | is-empty)) {
        return
    }

    if not ($env.ZELLIJ? | default "" | is-empty) {
        return
    }

    let is_ssh = (not ($env.SSH_TTY? | default "" | is-empty)) or (not ($env.SSH_CONNECTION? | default "" | is-empty)) or (not ($env.SSH_CLIENT? | default "" | is-empty))

    # Rendered by chezmoi into env.nu at apply time; see NREDF_WSL there.
    let is_wsl = ($env.NREDF_WSL? | default "false") == "true"

    mut should_start = false

    if $is_ssh {
        let multiplexer_enabled = ($env.NREDF_SHELL_MULTIPLEXER? | default ($env.NREDF_SHELL_GENERELL_MULTIPLEXER? | default "true"))
        if $multiplexer_enabled != "false" {
            $should_start = true
        }
    } else if $is_wsl {
        let wsl_multiplexer = ($env.NREDF_SHELL_WSL_MULTIPLEXER? | default ($env.NREDF_SHELL_MULTIPLEXER_WSL? | default "false"))
        if $wsl_multiplexer in ["true" "1" "yes"] {
            $should_start = true
        }
    }

    if not $should_start {
        return
    }

    mut host_name = ($env.HOSTNAME? | default "")
    if ($host_name | is-empty) and (not ($env.HOST? | default "" | is-empty)) {
        $host_name = ($env.HOST | split row "." | first)
    }
    if ($host_name | is-empty) {
        if not (which hostname | is-empty) {
            $host_name = (^hostname -s | str trim)
        } else if not (which hostnamectl | is-empty) {
            $host_name = (^hostnamectl hostname | str trim)
        }
    }

    print $"\e[1mStarting multiplexer \(zellij\)\e[0m"
    ^zellij attach -c $host_name
}
