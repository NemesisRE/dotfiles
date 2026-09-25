# chezmoi-managed nu function file.
#
# List listening TCP ports. Prefers `ss` (Linux, iproute2), falls back to
# `lsof` (macOS/BSD), then to `netstat` (present on most systems, even
# though deprecated on native Linux).

def ports [] {
    if not (which ss | is-empty) {
        try {
            ^ss -tlnp
        } catch {
            ^ss -tln
        }
    } else if not (which lsof | is-empty) {
        ^lsof -nP -iTCP -sTCP:LISTEN
    } else if not (which netstat | is-empty) {
        ^netstat -an | ^grep -i listen
    } else {
        print --stderr 'none of "ss", "lsof" or "netstat" exist on system'
        return
    }
}
