#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

# Source fzf keybindings/completions.
function _nredf_tool_fzf_source
    type -q fzf; or return 0

    set -l fzf_cache "$XDG_CACHE_HOME/nredf/init/fzf.fish.sh"
    if type -q _nredf_refresh_cached_shell_snippet
        _nredf_refresh_cached_shell_snippet _nredf_fzf_init_fish "$fzf_cache" fzf --fish
    else if fzf --fish &>/dev/null
        fzf --fish | source
    end

    if not test -s "$fzf_cache"
        test -f "$HOME/.config/fzf/completion.fish"; and source "$HOME/.config/fzf/completion.fish"
        test -f "$HOME/.config/fzf/key-bindings.fish"; and source "$HOME/.config/fzf/key-bindings.fish"
    end

    # The Ctrl+Space binding for _nredf_fzf_tab_complete itself is set up in
    # fish/rc.tmpl (fish key bindings are `bind`, evaluated once per
    # interactive shell, not sourced from a per-tool snippet).
end

# Fuzzy tab completion with descriptions (Ctrl+Space). `commandline -t` /
# `commandline -t -r` (current token / replace current token) are fish's
# direct analogs of bash's READLINE_LINE + READLINE_POINT dance.
function _nredf_fzf_tab_complete
    type -q fzf; or return 0

    set -l line (commandline -b)
    set -l point (commandline -C)
    set -l prefix (string sub -l "$point" -- "$line")
    set -l cur_word (commandline -t)
    set -l cmd_name (string split " " -- "$prefix")[1]

    set -l candidates
    if test -n "$cmd_name"; and type -q carapace
        set -l compline (string replace -r ' $' " ''" -- "$prefix")
        for c in (carapace "$cmd_name" fish (string split " " -- $compline) 2>/dev/null)
            test -z "$c"; and continue
            string match -qr '^ERR[[:space:]]' -- "$c"; and continue
            set candidates $candidates "$c"
        end
    end

    # Fallback if no carapace candidates: fish's own completion engine.
    if test (count $candidates) -eq 0
        for r in (complete -C"$cur_word")
            test -z "$r"; and continue
            set -l tok (string split \t -- "$r")[1]
            set candidates $candidates "$tok\t$tok"
        end
    end

    set -l total (count $candidates)
    if test "$total" -eq 0
        printf '\a'
        return 0
    end

    set -l selected
    if test "$total" -eq 1
        set selected "$candidates[1]"
    else
        set selected (printf '%s\n' $candidates | fzf \
            --reverse --height=40% --ansi --delimiter=\t --with-nth=2 \
            --bind="tab:down,btab:up" --query="$cur_word")
    end

    test -z "$selected"; and return 0

    set -l value (string split -m1 \t -- "$selected")[1]
    set -l insert "$value"
    if not string match -qr '[/:=]$' -- "$insert"
        set insert "$insert "
    end

    commandline -t -r -- "$insert"
end
