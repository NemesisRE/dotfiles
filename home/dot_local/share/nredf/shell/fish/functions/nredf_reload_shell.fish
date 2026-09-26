#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

function _nredf_reload_shell --description 'The `reload` command'
    _nredf_init_paths

    set -l options c/cache d/downloads f/full p/profile l/last-run h/help s/shell=
    argparse -n reload $options -- $argv
    or return 1

    if set -q _flag_help
        printf "NREDF Reload

Usage: reload [options]

Options:
-c, [--cache]               # Delete 'Last Run Cache' and init script snippets
-d, [--downloads]           # Delete aqua pkgs (archives + binaries, keeps bin/ symlinks)
-f, [--full]                # Full refresh: clear caches + chezmoi/aqua
-l, [--last-run]            # Delete only 'Last Run Cache'
-p, [--profile]             # Toggle startup profiling (or one-shot if combined with other options)
-s SHELL, [--shell SHELL]   # Reload with a different shell
-h, [--help]                # Show this help

"
        return 0
    end

    set -l has_other_options false
    set -l lrcache false
    set -l initcache false
    set -l downloads false
    set -l full_reload false

    if set -q _flag_cache
        set lrcache true
        set initcache true
        set has_other_options true
    end
    if set -q _flag_downloads
        set downloads true
        set has_other_options true
    end
    if set -q _flag_full
        set lrcache true
        set initcache true
        set full_reload true
        set has_other_options true
    end
    if set -q _flag_last_run
        set lrcache true
        set has_other_options true
    end
    if set -q _flag_shell
        set has_other_options true
        if type -q "$_flag_shell"
            set -gx NREDF_SHELL_NAME "$_flag_shell"
        else
            printf "\033[1;31m✘ Command not found (%s)\033[0m\n" "$_flag_shell" >&2
            return 1
        end
    end

    if test "$lrcache" = true
        rm -rf "$NREDF_LRCACHE"
    end

    if test "$initcache" = true
        set -l init_cache "$XDG_CACHE_HOME/nredf/init"
        if test -d "$init_cache"
            # Truncate Nushell's *.nu snippets instead of deleting them: nu's
            # `source` needs each file to exist when config.nu is parsed, and
            # the empty placeholders chezmoi seeds are only recreated by the
            # next `chezmoi apply`. A *.nu symlink is left alone. Everything
            # else in the directory is removed.
            find "$init_cache" -mindepth 1 -maxdepth 1 ! -name '*.nu' -exec rm -rf {} +
            for f in "$init_cache"/*.nu
                if test -f "$f"; and not test -L "$f"
                    printf '' >"$f"
                end
            end
        end
        # An unmatched fish glob is only silent inside `set`/`for`/`count`.
        set -l stale "$XDG_CACHE_HOME/sheldon/sheldon.zsh"* "$XDG_CACHE_HOME/zsh/.zcompdump"*
        test (count $stale) -gt 0; and rm -f $stale
    end

    if test "$downloads" = true
        set -l aqua_pkgs "$AQUA_ROOT_DIR"
        test -n "$aqua_pkgs"; or set aqua_pkgs "$XDG_DATA_HOME/aquaproj-aqua"
        set aqua_pkgs "$aqua_pkgs/pkgs"
        if test -d "$aqua_pkgs"
            printf "\033[1mRemoving aqua packages\033[0m\n"
            rm -rf "$aqua_pkgs"
        end
    end

    if test "$full_reload" = true
        printf "\033[1mStarting full reload\033[0m\n"
        if type -q nredf-daily-sync
            nredf-daily-sync --verbose
        end
    end

    if set -q _flag_profile
        if test "$has_other_options" != true
            if test "$NREDF_PROFILE_STARTUP" = 1
                set -e NREDF_PROFILE_STARTUP
                set -e NREDF_PROFILE_STARTUP_ONESHOT
                printf "\033[1;33mℹ Startup profiling disabled\033[0m\n"
            else
                set -gx NREDF_PROFILE_STARTUP 1
                set -e NREDF_PROFILE_STARTUP_ONESHOT
                printf "\033[1;32mℹ Startup profiling enabled (persistent)\033[0m\n"
            end
        else
            set -gx NREDF_PROFILE_STARTUP 1
            set -gx NREDF_PROFILE_STARTUP_ONESHOT 1
        end
    end

    set -l nredf_exec_shell "$NREDF_SHELL_NAME"
    set -l nredf_exec_args

    if test "$NREDF_SHELL_NAME" = fish
        set nredf_exec_shell (status fish-path)
    else if test "$NREDF_SHELL_NAME" = pwsh; or test "$NREDF_SHELL_NAME" = powershell
        set nredf_exec_args -NoLogo
    end

    exec "$nredf_exec_shell" $nredf_exec_args
end
