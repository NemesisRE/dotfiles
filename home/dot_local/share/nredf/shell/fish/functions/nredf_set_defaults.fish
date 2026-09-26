#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

function _nredf_set_krew_path
    set -l krew_root "$KREW_ROOT"
    test -n "$krew_root"; or set krew_root "$HOME/.krew"
    set -l krew_bin "$krew_root/bin"

    if test -d "$krew_bin"
        set -gx KREW_ROOT "$krew_root"
        if not contains -- "$krew_bin" $PATH
            set -gx PATH "$krew_bin" $PATH
        end
    end
end

# Prepend each directory to PATH, in argument order, unless it is already on
# PATH. The rc re-runs _nredf_set_defaults in every nested shell
# (NREDF_COMMON_DEFAULTS_DONE is not exported, so a child still gets its
# aliases and functions), and a blind prepend grew PATH at every level.
# Skipping entries that are already present also keeps the parent's order.
# (fish_add_path is not used: it also drops directories that don't exist yet,
# which bash/zsh/nu don't.)
function _nredf_path_prepend
    set -l new_dirs
    for dir in $argv
        test -n "$dir"; or continue
        contains -- "$dir" $new_dirs $PATH; or set -a new_dirs "$dir"
    end
    set -q new_dirs[1]; and set -gx PATH $new_dirs $PATH
end

# Cache generator for dircolors: dircolors has no fish output mode, and its
# Bourne output (`LS_COLORS='...'; export LS_COLORS`) is not valid fish, so
# emit the equivalent `set -gx` line instead.
function _nredf_dircolors_fish
    set -l ls_colors (dircolors -b $argv[1] | string match -r "^LS_COLORS='(.*)';\$")[2]
    test -n "$ls_colors"; or return 1
    printf 'set -gx LS_COLORS %s\n' (string escape -- "$ls_colors")
end

function _nredf_set_defaults
    _nredf_set_aqua_path
    _nredf_set_aqua_env
    _nredf_set_krew_path

    test -f "$HOME/.proxy.local"; and source "$HOME/.proxy.local"

    # Set the language environment if not already configured with a UTF-8 locale.
    if test -z "$LANG"; or test "$LANG" = C
        set -l nredf_locale C
        set -l nredf_locales (locale -a 2>/dev/null)
        if string match -qir '^en_US\.UTF-?8$' -- $nredf_locales
            set nredf_locale en_US.UTF-8
        else if string match -qir '^C\.UTF-?8$' -- $nredf_locales
            set nredf_locale C.UTF-8
        end
        set -gx LANG "$nredf_locale"
        set -gx LANGUAGE "$nredf_locale"
        set -gx LC_ALL "$nredf_locale"
    end

    _nredf_init_paths

    _nredf_path_prepend "$HOME/bin" "$XDG_BIN_HOME" /usr/local/bin
    if test -d /snap/bin; and not contains -- /snap/bin $PATH
        set -gx PATH $PATH /snap/bin
    end
    set -gx GOPATH "$HOME/.local"
    set -gx RLWRAP_HOME "$XDG_CACHE_HOME/RLWRAP"

    # Set the default editor (nvim -> hx -> vi).
    if type -q nvim
        set -gx EDITOR nvim
        set -gx VISUAL nvim
        set -gx GIT_EDITOR nvim
    else if type -q hx
        set -gx EDITOR hx
        set -gx VISUAL hx
        set -gx GIT_EDITOR hx
    else
        set -gx EDITOR vi
        set -gx VISUAL vi
        set -gx GIT_EDITOR vi
    end

    # Bat defaults.
    set -gx BAT_THEME OneDarkPro
    # Render man pages through bat (bat's documented recipe). MANROFFOPT=-c makes
    # groff emit the overstrike output `col -bx` expects. A MANPAGER set by the
    # user or inherited from a parent shell wins.
    if test -z "$MANPAGER"; and type -q bat
        set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
        set -gx MANROFFOPT -c
    end

    # FZF defaults.
    set -gx FZF_DEFAULT_OPTS '--bind tab:down --bind btab:up --cycle --ansi --color=dark,bg+:#2c313c,bg:#282c34,gutter:#282c34,spinner:#e5c07b,hl:#e06c75,fg:#abb2bf,header:#61afef,info:#56b6c2,pointer:#c678dd,marker:#98c379,fg+:#abb2bf,prompt:#61afef,hl+:#98c379,border:#4f5666'
    if type -q fd
        set -gx FZF_DEFAULT_COMMAND 'fd --type file --follow --hidden --exclude .git --color=always'
        set -gx FZF_ALT_C_COMMAND 'fd --type directory --hidden --follow --exclude .git'
    else
        set -gx FZF_DEFAULT_COMMAND 'find -L'
    end
    set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    if type -q bat
        set -gx FZF_CTRL_T_OPTS "--preview 'bat -n --color=always --theme=OneDarkPro {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
    end
    if type -q lsd
        set -gx FZF_ALT_C_OPTS "--preview 'lsd -A --tree --depth=2 --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
    end

    # Vim/Nvim defaults.
    if test -f "$XDG_CONFIG_HOME/vim/gvimrc"
        set -gx GVIMINIT 'let $MYGVIMRC="$XDG_CONFIG_HOME/vim/gvimrc" | source $MYGVIMRC'
    else
        set -e GVIMINIT
    end
    if test -f "$XDG_CONFIG_HOME/vim/vimrc"
        set -gx VIMINIT 'let $MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc" | source $MYVIMRC'
    else
        set -e VIMINIT
    end
    set -gx NVIM_LOG_FILE "$XDG_STATE_HOME/nvim/log"

    # Timewarrior.
    set -gx TIMEWARRIORDB "$XDG_CACHE_HOME/timewarrior"

    # docker-compose.
    set -gx COMPOSE_PARALLEL_LIMIT 10
    set -gx COMPOSE_HTTP_TIMEOUT 600

    # k9s config directory.
    set -gx K9SCONFIG "$XDG_CONFIG_HOME/k9s"

    # readline config (used by tools that still shell out to GNU readline).
    set -gx INPUTRC "$XDG_CONFIG_HOME/readline/inputrc"

    # Only point X clients at the XDG runtime copy when nothing (display manager,
    # `ssh -X`) set XAUTHORITY already and that file actually exists. Exporting it
    # unconditionally broke X forwarding and yielded `/Xauthority` on macOS.
    if test -z "$XAUTHORITY"; and test -n "$XDG_RUNTIME_DIR"; and test -f "$XDG_RUNTIME_DIR/Xauthority"
        set -gx XAUTHORITY "$XDG_RUNTIME_DIR/Xauthority"
    end

    # Let carapace fall back to other shells' completions for commands it has no
    # spec for. A user-set value wins.
    test -n "$CARAPACE_BRIDGES"; or set -gx CARAPACE_BRIDGES zsh,fish,bash

    # Make less more friendly for non-text input files, see lesspipe(1).
    # Cached like the other tool-init snippets (cleared by `reload -c`), so
    # nested shells do not fork lesspipe/dircolors again. lesspipe's Bourne
    # `export VAR="...";` output is valid fish via fish's `export` wrapper.
    if test -x /usr/bin/lesspipe
        _nredf_refresh_cached_shell_snippet _nredf_lesspipe_fish \
            "$XDG_CACHE_HOME/nredf/init/lesspipe.fish.sh" \
            env SHELL=/bin/sh /usr/bin/lesspipe
    end

    if type -q dircolors; and test -e "$XDG_CONFIG_HOME/dircolors"
        set -l dircolors_cache "$XDG_CACHE_HOME/nredf/init/dircolors.fish.sh"
        # An edited (or re-applied) dircolors file invalidates the cache right
        # away instead of waiting out the 24h stamp.
        if test -e "$dircolors_cache"; and test "$XDG_CONFIG_HOME/dircolors" -nt "$dircolors_cache"
            rm -f "$dircolors_cache"
        end
        _nredf_refresh_cached_shell_snippet _nredf_dircolors_fish \
            "$dircolors_cache" \
            _nredf_dircolors_fish "$XDG_CONFIG_HOME/dircolors"
    end

    # Less pager defaults & history hygiene.
    set -gx LESS '-R -F -X -i'
    set -l state_home "$XDG_STATE_HOME"
    test -n "$state_home"; or set state_home "$HOME/.local/state"
    set -gx LESSHISTFILE "$state_home/less/history"

    # Tool config paths.
    set -gx WGETRC "$XDG_CONFIG_HOME/wgetrc"
    set -gx RIPGREP_CONFIG_PATH "$XDG_CONFIG_HOME/ripgrep/config"
    set -gx GH_CONFIG_DIR "$XDG_CONFIG_HOME/gh"
    set -gx POWERSHELL_UPDATECHECK Off
end
