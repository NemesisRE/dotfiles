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

# Prepend each directory to PATH, in argument order, unless it is already on
# PATH, so re-running the defaults (nested shells, `reload`) never grows PATH
# and keeps the parent's order — same helper as bash/zsh/fish.
def --env nredf-path-prepend [...dirs: string] {
    let new_dirs = ($dirs | where {|d| ($d | is-not-empty) and not ($d in $env.PATH) } | uniq)
    if ($new_dirs | is-not-empty) {
        $env.PATH = ($env.PATH | prepend $new_dirs)
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

    # Set the language environment if not already configured with a UTF-8 locale.
    if ($env.LANG? | default "" | is-empty) or ($env.LANG? == "C") {
        mut nredf_locale = "C"
        let locales = (^locale -a | complete | get stdout | str lowercase | lines)
        if ($locales | any {|l| $l =~ '^en_us\.utf-?8$' }) {
            $nredf_locale = "en_US.UTF-8"
        } else if ($locales | any {|l| $l =~ '^c\.utf-?8$' }) {
            $nredf_locale = "C.UTF-8"
        }
        $env.LANG = $nredf_locale
        $env.LANGUAGE = $nredf_locale
        $env.LC_ALL = $nredf_locale
    }

    nredf-init-paths

    nredf-path-prepend ($env.HOME | path join "bin") $env.XDG_BIN_HOME "/usr/local/bin"
    if ("/snap/bin" | path exists) and not ("/snap/bin" in $env.PATH) {
        $env.PATH = ($env.PATH | append "/snap/bin")
    }
    $env.GOPATH = ($env.HOME | path join ".local")
    $env.RLWRAP_HOME = ($env.XDG_CACHE_HOME | path join "RLWRAP")

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

    # Bat defaults.
    $env.BAT_THEME = "OneDarkPro"
    # Render man pages through bat (bat's documented recipe). MANROFFOPT=-c makes
    # groff emit the overstrike output `col -bx` expects. A MANPAGER set by the
    # user or inherited from a parent shell wins.
    if ($env.MANPAGER? | default "" | is-empty) and not (which bat | is-empty) {
        $env.MANPAGER = "sh -c 'col -bx | bat -l man -p'"
        $env.MANROFFOPT = "-c"
    }

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

    # Only point X clients at the XDG runtime copy when nothing (display manager,
    # `ssh -X`) set XAUTHORITY already and that file actually exists. Exporting it
    # unconditionally broke X forwarding and yielded `/Xauthority` on macOS.
    let runtime_dir = ($env.XDG_RUNTIME_DIR? | default "")
    if ($env.XAUTHORITY? | default "" | is-empty) and ($runtime_dir | is-not-empty) and (($runtime_dir | path join "Xauthority") | path exists) {
        $env.XAUTHORITY = ($runtime_dir | path join "Xauthority")
    }

    # Let carapace fall back to other shells' completions for commands it has no
    # spec for. A user-set value wins.
    if ($env.CARAPACE_BRIDGES? | default "" | is-empty) {
        $env.CARAPACE_BRIDGES = "zsh,fish,bash"
    }

    # lesspipe(1) — parse its simple `export LESSOPEN="..."; export LESSCLOSE="...";`
    # output as data (same approach as the shared aqua.env dotenv reader)
    # rather than trying to `source` foreign sh syntax. Not cached like the
    # other shells: a nu cache only takes effect a shell start later, and nu
    # child shells already skip this (NREDF_COMMON_DEFAULTS_DONE is inherited).
    if ("/usr/bin/lesspipe" | path exists) {
        let lesspipe_out = (with-env {SHELL: "/bin/sh"} { ^/usr/bin/lesspipe } | complete | get stdout)
        # \x27 = ' — a literal single quote can't appear inside a single-quoted
        # nu string, so it's hex-escaped for the (Rust-regex) pattern instead.
        for var in [LESSOPEN LESSCLOSE] {
            let match = ($lesspipe_out | parse --regex ($var + '=[\x27"]?([^\x27";\n]*)[\x27"]?'))
            if ($match | is-not-empty) {
                load-env ({} | insert $var ($match | get 0.capture0))
            }
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
}
