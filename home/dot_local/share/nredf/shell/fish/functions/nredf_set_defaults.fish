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

function _nredf_set_defaults
    _nredf_set_aqua_path
    _nredf_set_aqua_env
    _nredf_set_krew_path

    test -f "$HOME/.proxy.local"; and source "$HOME/.proxy.local"

    set -gx NREDF_RC_PATH "$NREDF_DOT_PATH/shell/$NREDF_SHELL_NAME"
    set -gx NREDF_RC_LOCAL "$HOME/.config/$NREDF_SHELL_NAME"

    # Set the language environment if not already configured with a UTF-8 locale.
    if test -z "$LANG"; or test "$LANG" = C
        set -l nredf_locale C
        if locale -a 2>/dev/null | grep -qiE '^en_US\.UTF-?8$'
            set nredf_locale en_US.UTF-8
        else if locale -a 2>/dev/null | grep -qiE '^C\.UTF-?8$'
            set nredf_locale C.UTF-8
        end
        set -gx LANG "$nredf_locale"
        set -gx LANGUAGE "$nredf_locale"
        set -gx LC_ALL "$nredf_locale"
    end

    _nredf_init_paths

    set -gx PATH "$HOME/bin" "$XDG_BIN_HOME" /usr/local/bin $PATH
    test -d /snap/bin; and set -gx PATH $PATH /snap/bin
    set -gx GOPATH "$HOME/.local"
    set -gx RLWRAP_HOME "$XDG_CACHE_HOME/RLWRAP"
    test -s "$HOME/.rvm/scripts/rvm"; and source "$HOME/.rvm/scripts/rvm"

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

    # Load pyenv if you are using it.
    if test -s "$HOME/.pyenv"
        set -gx PYENV_ROOT "$HOME/.pyenv"
        set -gx PATH "$PYENV_ROOT/bin" $PATH
        pyenv init - | source
    end

    # Bat defaults.
    set -gx BAT_THEME OneDarkPro

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

    set -gx XAUTHORITY "$XDG_RUNTIME_DIR/Xauthority"

    set -gx _Z_DATA "$XDG_DATA_HOME/z"

    # asdf config.
    set -gx ASDF_DATA_DIR "$XDG_DATA_HOME/asdf"
    set -gx ASDF_CONFIG_FILE "$XDG_CONFIG_HOME/asdf/asdfrc"
    set -gx ADSF_DEFAULT_TOOL_VERSIONS_FILENAME "$XDG_CONFIG_HOME/asdf/tool-versions"
    set -gx PATH "$ASDF_DATA_DIR/shims" $PATH

    # Make less more friendly for non-text input files, see lesspipe(1).
    if test -x /usr/bin/lesspipe
        env SHELL=/bin/sh lesspipe | source
    end

    if type -q dircolors
        if test -e "$XDG_CONFIG_HOME/dircolors"
            dircolors "$XDG_CONFIG_HOME/dircolors" | source
        end
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

    if test -f "$NREDF_CONFIG/GITHUB.AUTH"
        # GITHUB.AUTH is plain `KEY=value` shell assignments; fish has no
        # generic `eval` of foreign shell syntax, so read the two keys we
        # actually consume directly instead of sourcing the file as code.
        set -l github_auth_lines (cat "$NREDF_CONFIG/GITHUB.AUTH")
        set -l github_user (string trim -c '\'"' -- (string match -r '^NREDF_GITHUB_USERNAME=(.*)$' -- $github_auth_lines)[2])
        set -l github_token (string trim -c '\'"' -- (string match -r '^NREDF_GITHUB_TOKEN=(.*)$' -- $github_auth_lines)[2])
        if test -n "$github_user"; and test -n "$github_token"
            set -gx NREDF_CURL_GITHUB_AUTH "-u $github_user:$github_token"
        end
    end
end
