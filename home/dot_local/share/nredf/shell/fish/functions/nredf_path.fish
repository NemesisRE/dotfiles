#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

# Print $PATH, one entry per line. Fish already keeps PATH as the list
# variable $fish_user_paths + $PATH is itself a list, so no splitting needed
# — bash/zsh/nu/PowerShell all have to split a colon-joined string instead.
function path
    for p in $PATH
        echo $p
    end
end
