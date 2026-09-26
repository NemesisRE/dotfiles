# chezmoi-managed nu function file.
#
# Unlike bash/zsh/fish, a single generic "regenerate and source" helper is
# not possible in nu: `source` requires a parse-time-constant path to a file
# that must already exist on disk when the containing file is PARSED, before
# any of it has executed — so it can never live inside a function body with
# a caller-supplied path. This handles only the "is the cache stale, and if
# so, regenerate it" half; the `source "<literal path>"` line itself is
# written out literally, once per tool, at the top level of config.nu (with
# the path baked in at chezmoi-render time via .chezmoi.homeDir, so nu itself
# never needs to build the path from a variable at all). See
# docs/shells.md's parity-exceptions section for the one-restart-lag this
# implies: a refreshed cache only takes effect on the *next* shell start.

def nredf-cache-refresh [key: string, file: string, generator: closure] {
    mut needs_refresh = true
    # Stat the file rather than reading it: only "is it non-empty" matters,
    # and some tool-init caches are large.
    if ($file | path exists) and ((ls $file | get 0.size) > 0b) {
        if (nredf-last-run $key) {
            $needs_refresh = false
        }
    }

    if not $needs_refresh {
        return
    }

    let dir = ($file | path dirname)
    if not ($dir | path exists) {
        mkdir $dir
    }
    try {
        let content = (do $generator | into string)
        if not ($content | str trim | is-empty) {
            $content | save --force $file
            nredf-last-run $key --success --next $env.NREDF_24H_INTERVAL
        }
    } catch {
        # Leave whatever cache file is already there (possibly the empty
        # chezmoi-deployed placeholder) rather than deleting it — nu's
        # `source` needs the file to exist at parse time, so removing it
        # here would break the *next* shell start outright.
    }
}
