# chezmoi-managed nu aliases/shortcuts file.
#
# Nu's own `alias` command is a plain word substitution (it cannot hold a
# real pipeline or variable interpolation re-evaluated per call — verified:
# `alias x = a | b` stores the literal text, not a pipeline), so unlike
# bash/zsh/fish's shared alias set, anything here that needs a pipe or a
# variable re-read on each invocation is a `def` instead. Public command
# names are kept identical to bash/fish/PowerShell for muscle memory; only
# internal helpers use nu's own kebab-case convention — see docs/shells.md.

if not (which lsd | is-empty) {
    alias ls = lsd
    alias ll = lsd -lFh --git
    alias la = lsd -lAFh --git
    alias tree = lsd --tree
}

if not (which procs | is-empty) {
    alias pst = procs --tree
}

def root [] {
    ^sudo -E $"HOME=($env.HOME)" su -m
}

def aptall [] {
    if (^sudo apt update | complete | get exit_code) == 0 {
        ^sudo apt full-upgrade -y
    }
    ^sudo apt autoremove --purge -y
    ^sudo apt autoclean
}

alias k = kubectl
alias kctx = kubectx
alias ctx = kubectx
alias kns = kubens
alias ns = kubens

def dipls [] {
    ^docker ps -q
    | ^xargs docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}{{.Name}}'
    | ^sed -e 's/^\//HOST\t\//' -e 's/\//\t/g'
    | ^sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4
}

alias lzg = lazygit
alias lg = lazygit
alias lzd = lazydocker
alias lzj = lazyjournal
alias lj = lazyjournal

def --wrapped grep [...args] {
    ^grep --color=auto ...$args
}

# From shell/bash/aliases.
def gpg_agent [] {
    if (^gpgconf --kill gpg-agent | complete | get exit_code) == 0 {
        ^gpgconf --launch gpg-agent
    }
}
