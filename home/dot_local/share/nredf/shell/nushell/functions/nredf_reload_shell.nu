# chezmoi-managed nu function file.
#
# The `reload` command. nu's typed named flags replace bash's manual
# while/case argv loop.

def --env reload [
    --cache(-c) # Delete 'Last Run Cache' and init script snippets
    --downloads(-d) # Delete aqua pkgs (archives + binaries, keeps bin/ symlinks)
    --full(-f) # Full refresh: clear caches + chezmoi/aqua
    --profile(-p) # Toggle startup profiling (or one-shot if combined with other options)
    --last-run(-l) # Delete only 'Last Run Cache'
    --shell(-s): string # Reload with a different shell
] {
    mut has_other_options = false
    mut lrcache = false
    mut initcache = false
    mut do_downloads = false
    mut full_reload = false

    if $cache {
        $lrcache = true
        $initcache = true
        $has_other_options = true
    }
    if $downloads {
        $do_downloads = true
        $has_other_options = true
    }
    if $full {
        $lrcache = true
        $initcache = true
        $full_reload = true
        $has_other_options = true
    }
    if $last_run {
        $lrcache = true
        $has_other_options = true
    }

    mut shell_name = ($env.NREDF_SHELL_NAME? | default "nu")
    if $shell != null {
        $has_other_options = true
        if (which $shell | is-empty) {
            print --stderr $"\e[1;31m✘ Command not found \(($shell)\)\e[0m"
            return
        }
        $shell_name = $shell
    }

    if $lrcache {
        rm --recursive --force $env.NREDF_LRCACHE
    }

    if $initcache {
        let init_cache = ($env.XDG_CACHE_HOME | path join "nredf" "init")
        if ($init_cache | path exists) {
            # Truncate the *.nu snippets instead of deleting them: config.nu's
            # `source` lines need each file to exist when config.nu is parsed,
            # and the empty placeholders chezmoi seeds are only recreated by
            # the next `chezmoi apply`. A *.nu symlink is left alone.
            # Everything else is removed.
            for entry in (ls --all $init_cache) {
                if ($entry.name | str ends-with ".nu") {
                    if $entry.type == "file" {
                        "" | save --force $entry.name
                    }
                } else {
                    rm --recursive --force $entry.name
                }
            }
        }
        # Matched by name via `ls` rather than `glob`: nu's glob parser
        # rejects the backslashes and drive colon of a Windows path.
        for stale in [["sheldon" "sheldon.zsh"] ["zsh" ".zcompdump"]] {
            let dir = ($env.XDG_CACHE_HOME | path join $stale.0)
            if ($dir | path exists) {
                ls --all $dir
                | where {|e| ($e.name | path basename | str starts-with $stale.1) }
                | each {|e| rm --force $e.name }
                | ignore
            }
        }
    }

    if $do_downloads {
        let aqua_pkgs = (($env.AQUA_ROOT_DIR? | default ($env.XDG_DATA_HOME | path join "aquaproj-aqua")) | path join "pkgs")
        if ($aqua_pkgs | path exists) {
            print "\e[1mRemoving aqua packages\e[0m"
            rm --recursive --force $aqua_pkgs
        }
    }

    if $full_reload {
        print "\e[1mStarting full reload\e[0m"
        if not (which nredf-daily-sync | is-empty) {
            ^nredf-daily-sync --verbose
        }
    }

    if $profile {
        if not $has_other_options {
            if (($env.NREDF_PROFILE_STARTUP? | default "0") == "1") {
                hide-env --ignore-errors NREDF_PROFILE_STARTUP
                hide-env --ignore-errors NREDF_PROFILE_STARTUP_ONESHOT
                print "\e[1;33mℹ Startup profiling disabled\e[0m"
            } else {
                $env.NREDF_PROFILE_STARTUP = "1"
                hide-env --ignore-errors NREDF_PROFILE_STARTUP_ONESHOT
                print "\e[1;32mℹ Startup profiling enabled \(persistent\)\e[0m"
            }
        } else {
            $env.NREDF_PROFILE_STARTUP = "1"
            $env.NREDF_PROFILE_STARTUP_ONESHOT = "1"
        }
    }

    if $shell_name in ["pwsh" "powershell"] {
        exec $shell_name -NoLogo
    } else {
        exec $shell_name
    }
}
