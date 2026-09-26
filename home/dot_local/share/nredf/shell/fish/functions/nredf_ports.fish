#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

# List listening TCP ports. Prefers `ss` (Linux, iproute2), falls back to
# `lsof` (macOS/BSD), then to `netstat` (present on most systems, even
# though deprecated on native Linux).
function ports
    if type -q ss
        ss -tlnp 2>/dev/null; or ss -tln
    else if type -q lsof
        lsof -nP -iTCP -sTCP:LISTEN
    else if type -q netstat
        netstat -an | grep -i listen
    else
        echo 'none of "ss", "lsof" or "netstat" exist on system' >&2
        return 1
    end
end
