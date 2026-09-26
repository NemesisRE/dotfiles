# chezmoi-managed nu function file.
#
# Universal archive extract/compress via ouch (https://github.com/ouch-org/ouch),
# which auto-detects format from the file extension so one function covers
# zip/tar/tar.gz/tar.zst/7z/rar/... instead of a per-format case statement.
# Nu has no plugin manager, so there is no oh-my-zsh-style `extract`/`x` to
# contend with here the way zsh has (see common/functions/nredf_extract.bash).

def --wrapped extract [...archives] {
    if (which ouch | is-empty) {
        print --stderr 'command "ouch" does not exist on system'
        return
    }
    if ($archives | is-empty) {
        print --stderr "Usage: extract <archive>..."
        return
    }
    ^ouch decompress ...$archives
}

def --wrapped x [...archives] {
    extract ...$archives
}

def --wrapped compress [out: string, ...files] {
    if (which ouch | is-empty) {
        print --stderr 'command "ouch" does not exist on system'
        return
    }
    if ($files | is-empty) {
        print --stderr "Usage: compress <out> <files...>"
        return
    }
    ^ouch compress ...$files $out
}
