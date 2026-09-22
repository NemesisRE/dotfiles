# chezmoi-managed nu function file.

def --env nredf-set-krew-path [] {
    let krew_root = ($env.KREW_ROOT? | default ($env.HOME | path join ".krew"))
    let krew_bin = ($krew_root | path join "bin")

    if ($krew_bin | path exists) {
        $env.KREW_ROOT = $krew_root
        if not ($krew_bin in $env.PATH) {
            $env.PATH = ($env.PATH | prepend $krew_bin)
        }
    }
}

def --env nredf-set-defaults [] {
    nredf-set-aqua-path
    nredf-set-aqua-env
    nredf-set-krew-path

    let proxy_local = ($env.HOME | path join ".proxy.local")
    if ($proxy_local | path exists) {
        nredf-read-dotenv $proxy_local
    }

    $env.NREDF_COMMON_RC_LOCAL = ($env.HOME | path join ".config" "shell")
    $env.NREDF_RC_PATH = ($env.NREDF_DOT_PATH | path join "shell" $env.NREDF_SHELL_NAME)
    $env.NREDF_RC_LOCAL = ($env.HOME | path join ".config" $env.NREDF_SHELL_NAME)

    # Set the language environment if not already configured with a UTF-8 locale.
    if ($env.LANG? | default "" | is-empty) or ($env.LANG? == "C") {
        mut nredf_locale = "C"
        let locales = (^locale -a | complete | get stdout)
        if ($locales | str lowercase | str contains "en_us.utf") {
            $nredf_locale = "en_US.UTF-8"
        } else if ($locales | str lowercase | str contains "c.utf") {
            $nredf_locale = "C.UTF-8"
        }
        $env.LANG = $nredf_locale
        $env.LANGUAGE = $nredf_locale
        $env.LC_ALL = $nredf_locale
    }

    nredf-init-paths

    $env.PATH = ($env.PATH | prepend [($env.HOME | path join "bin") $env.XDG_BIN_HOME "/usr/local/bin"])
    if ("/snap/bin" | path exists) {
        $env.PATH = ($env.PATH | append "/snap/bin")
    }
    $env.GOPATH = ($env.HOME | path join ".local")
    $env.RLWRAP_HOME = ($env.XDG_CACHE_HOME | path join "RLWRAP")
    let rvm = ($env.HOME | path join ".rvm" "scripts" "rvm")
    # rvm's script is bash/sh code, not nu — nu has no nu-specific rvm
    # integration upstream, so this is intentionally not sourced here.

    # Set the default editor (nvim -> hx -> vi).
    if not (which nvim | is-empty) {
        $env.EDITOR = "nvim"
        $env.VISUAL = "nvim"
        $env.GIT_EDITOR = "nvim"
    } else if not (which hx | is-empty) {
        $env.EDITOR = "hx"
        $env.VISUAL = "hx"
        $env.GIT_EDITOR = "hx"
    } else {
        $env.EDITOR = "vi"
        $env.VISUAL = "vi"
        $env.GIT_EDITOR = "vi"
    }

    # pyenv has no nu integration upstream (bash/zsh/fish only) — documented
    # gap, not something this repo can fix; `pyenv exec`/`pyenv which` still
    # work fine as plain external commands without shell integration.

    # Bat defaults.
    $env.BAT_THEME = "OneDarkPro"

    # FZF defaults.
    $env.FZF_DEFAULT_OPTS = "--bind tab:down --bind btab:up --cycle --ansi --color=dark,bg+:#2c313c,bg:#282c34,gutter:#282c34,spinner:#e5c07b,hl:#e06c75,fg:#abb2bf,header:#61afef,info:#56b6c2,pointer:#c678dd,marker:#98c379,fg+:#abb2bf,prompt:#61afef,hl+:#98c379,border:#4f5666"
    if not (which fd | is-empty) {
        $env.FZF_DEFAULT_COMMAND = "fd --type file --follow --hidden --exclude .git --color=always"
        $env.FZF_ALT_C_COMMAND = "fd --type directory --hidden --follow --exclude .git"
    } else {
        $env.FZF_DEFAULT_COMMAND = "find -L"
    }
    $env.FZF_CTRL_T_COMMAND = $env.FZF_DEFAULT_COMMAND
    if not (which bat | is-empty) {
        $env.FZF_CTRL_T_OPTS = "--preview 'bat -n --color=always --theme=OneDarkPro {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
    }
    if not (which lsd | is-empty) {
        $env.FZF_ALT_C_OPTS = "--preview 'lsd -A --tree --depth=2 --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
    }

    # Vim/Nvim defaults — these are Vimscript strings for vim itself to
    # interpret, not nu code, so they carry over as literal string values.
    if (($env.XDG_CONFIG_HOME | path join "vim" "gvimrc") | path exists) {
        $env.GVIMINIT = 'let $MYGVIMRC="$XDG_CONFIG_HOME/vim/gvimrc" | source $MYGVIMRC'
    } else {
        hide-env --ignore-errors GVIMINIT
    }
    if (($env.XDG_CONFIG_HOME | path join "vim" "vimrc") | path exists) {
        $env.VIMINIT = 'let $MYVIMRC="$XDG_CONFIG_HOME/vim/vimrc" | source $MYVIMRC'
    } else {
        hide-env --ignore-errors VIMINIT
    }
    $env.NVIM_LOG_FILE = ($env.XDG_STATE_HOME | path join "nvim" "log")

    # Timewarrior.
    $env.TIMEWARRIORDB = ($env.XDG_CACHE_HOME | path join "timewarrior")

    # docker-compose.
    $env.COMPOSE_PARALLEL_LIMIT = "10"
    $env.COMPOSE_HTTP_TIMEOUT = "600"

    # k9s config directory.
    $env.K9SCONFIG = ($env.XDG_CONFIG_HOME | path join "k9s")

    # readline config (used by tools that still shell out to GNU readline).
    $env.INPUTRC = ($env.XDG_CONFIG_HOME | path join "readline" "inputrc")

    if not ($env.XDG_RUNTIME_DIR? | default "" | is-empty) {
        $env.XAUTHORITY = ($env.XDG_RUNTIME_DIR | path join "Xauthority")
    }

    $env._Z_DATA = ($env.XDG_DATA_HOME | path join "z")

    # asdf config.
    $env.ASDF_DATA_DIR = ($env.XDG_DATA_HOME | path join "asdf")
    $env.ASDF_CONFIG_FILE = ($env.XDG_CONFIG_HOME | path join "asdf" "asdfrc")
    $env.ADSF_DEFAULT_TOOL_VERSIONS_FILENAME = ($env.XDG_CONFIG_HOME | path join "asdf" "tool-versions")
    $env.PATH = ($env.PATH | prepend ($env.ASDF_DATA_DIR | path join "shims"))

    # lesspipe(1) — parse its simple `LESSOPEN="..."; export LESSOPEN;`
    # output as data (same approach as the shared aqua.env dotenv reader)
    # rather than trying to `source` foreign sh syntax.
    if ("/usr/bin/lesspipe" | path exists) {
        let lesspipe_out = (with-env {SHELL: "/bin/sh"} { ^lesspipe } | complete | get stdout)
        # \x27 = ' — a literal single quote can't appear inside a single-quoted
        # nu string, so it's hex-escaped for the (Rust-regex) pattern instead.
        let lessopen_match = ($lesspipe_out | parse --regex 'LESSOPEN=[\x27"]?([^\x27";\n]*)[\x27"]?')
        if ($lessopen_match | is-not-empty) {
            $env.LESSOPEN = ($lessopen_match | get 0.capture0)
        }
    }

    # dircolors integration is intentionally skipped for nu: nu's own `ls`
    # builtin has its own color theming (`$env.config.color_config`) and
    # never reads LS_COLORS, unlike bash/zsh/fish's external-`ls`-based
    # `ls`/`ll`/`la` aliases — see docs/shells.md's parity-exceptions section.

    # Less pager defaults & history hygiene.
    $env.LESS = "-R -F -X -i"
    $env.LESSHISTFILE = ($env.XDG_STATE_HOME | path join "less" "history")

    # Tool config paths.
    $env.WGETRC = ($env.XDG_CONFIG_HOME | path join "wgetrc")
    $env.RIPGREP_CONFIG_PATH = ($env.XDG_CONFIG_HOME | path join "ripgrep" "config")
    $env.GH_CONFIG_DIR = ($env.XDG_CONFIG_HOME | path join "gh")
    $env.POWERSHELL_UPDATECHECK = "Off"

    let github_auth = ($env.NREDF_CONFIG | path join "GITHUB.AUTH")
    if ($github_auth | path exists) {
        nredf-read-dotenv $github_auth
        if (not ($env.NREDF_GITHUB_USERNAME? | default "" | is-empty)) and (not ($env.NREDF_GITHUB_TOKEN? | default "" | is-empty)) {
            $env.NREDF_CURL_GITHUB_AUTH = $"-u ($env.NREDF_GITHUB_USERNAME):($env.NREDF_GITHUB_TOKEN)"
        }
    }
}
