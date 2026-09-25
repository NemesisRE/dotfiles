# chezmoi-managed nu function file.
#
# Print $PATH, one entry per line, matching every other shell's `path`.
# This shadows nu's own built-in `path` command — but only the bare,
# subcommand-less form, which just prints its own help and isn't used
# anywhere in this repo: `path join`/`path exists`/etc. are separate
# multi-word command names nu resolves independently of a bare `path`
# redefinition (verified: defining `path` does not break `path join`).
#
# Returning a single newline-joined string (rather than `print`ing each
# entry, or returning the list<string> as-is) is deliberate: a bare `print`
# never reaches nu's pipeline, and a returned list renders as a boxed
# table — neither behaves like bash/fish's plain, pipeable text output.
# A single string does: it displays as plain lines when run bare, and
# still pipes cleanly into `lines`/`^grep`/etc.

def path [] {
    $env.PATH | str join (char newline)
}
