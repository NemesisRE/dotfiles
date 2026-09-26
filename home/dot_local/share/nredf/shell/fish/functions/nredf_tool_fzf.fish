#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

# Source fzf keybindings/completions.
function _nredf_tool_fzf_source
    type -q fzf; or return 0

    # Atuin owns Ctrl+R when installed (matching bash/zsh, which explicitly
    # rebind it to atuin after sourcing fzf) — fzf's own fish integration
    # binds \cr to its own history widget unless FZF_CTRL_R_COMMAND is
    # explicitly set (even to empty), so suppress it here rather than
    # fighting over the binding after the fact.
    if type -q atuin
        set -gx FZF_CTRL_R_COMMAND ""
    end

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

    # The current process up to the cursor (so `foo | git ch<C-Space>`
    # completes git, not foo), as one string even if it spans several lines.
    set -l prefix (commandline -cp | string collect)
    set -l cur_word (commandline -t)

    # carapace takes the words as separate argv entries (bash/zsh get there
    # via `xargs`, which fish can't rely on for unquoting). A trailing space
    # means "complete a new, empty word", which carapace needs as an
    # explicit empty last argument.
    set -l words (string split --no-empty " " -- "$prefix")
    string match -q -- '* ' "$prefix"; and set -a words ""
    set -l cmd_name $words[1]

    set -l candidates
    if test -n "$cmd_name"; and type -q carapace
        for c in (carapace "$cmd_name" fish $words 2>/dev/null)
            test -z "$c"; and continue
            string match -qr '^ERR[[:space:]]' -- "$c"; and continue
            # carapace's fish format is "value<TAB>description"; show both in
            # fzf (field 2) and keep the bare value as field 1 to insert.
            set -l parts (string split -m1 \t -- "$c")
            set -l display $parts[1]
            test -n "$parts[2]"; and set display "$parts[1]  $parts[2]"
            set -a candidates "$parts[1]"\t"$display"
        end
    end

    # Fallback if no carapace candidates: fish's own completion engine.
    if test (count $candidates) -eq 0
        for r in (complete -C "$prefix")
            test -z "$r"; and continue
            set -l tok (string split -m1 \t -- "$r")[1]
            set -a candidates "$tok"\t"$tok"
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
        # fzf drew over the prompt; have fish redraw it.
        commandline -f repaint
    end

    test -z "$selected"; and return 0

    set -l value (string split -m1 \t -- "$selected")[1]
    set -l insert "$value"
    if not string match -qr '[/:=]$' -- "$insert"
        set insert "$insert "
    end

    commandline -t -r -- "$insert"
end
