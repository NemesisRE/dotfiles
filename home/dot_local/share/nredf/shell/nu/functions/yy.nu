# chezmoi-managed nu function file.

def --env --wrapped yy [...args] {
    if (which yazi | is-empty) {
        print --stderr 'command "yazi" does not exist on system'
        return
    }

    let tmp = (mktemp -t "yazi-cwd.XXXXXX")
    if ($tmp | is-empty) {
        return
    }

    ^yazi ...$args $"--cwd-file=($tmp)"
    if ($tmp | path exists) {
        let cwd = (open $tmp | into string | str trim)
        if (not ($cwd | is-empty)) and ($cwd != $env.PWD) {
            cd $cwd
        }
    }
    rm --force $tmp
}
