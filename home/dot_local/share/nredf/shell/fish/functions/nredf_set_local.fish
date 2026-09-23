#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# Loads user-local overrides, in the same order bash/zsh use — each shell
# only ever consults its own override paths under $NREDF_RC_LOCAL
# (~/.config/fish here), never a shared "all shells" or "bash+zsh" tier: a
# local function's syntax is never portable across shells anyway, and
# local.yaml (see docs/shells.md) already covers the one thing that
# genuinely was shareable (simple aliases/paths). Fish's own unmatched
# globs already expand to zero elements, so no zsh-style `setopt nullglob`
# equivalent is needed here.
#
# There is no local-functions directory to load here at all, unlike
# bash/zsh: fish already autoloads ~/.config/fish/functions/*.fish natively
# (by filename, on first call, independent of this dotfiles framework
# entirely), so reimplementing that would just be a redundant, worse copy
# of a feature fish already ships.
#
# Usage: _nredf_set_local [true|false]   (true = load aliases, false/omitted = load functions/rc)

function _nredf_set_local --argument-names alias_mode
    _nredf_init_paths

    test -n "$alias_mode"; or set alias_mode false

    if test "$alias_mode" = true
        if test -f "$NREDF_RC_PATH/aliases"
            source "$NREDF_RC_PATH/aliases"
        end

        if test -f "$NREDF_RC_LOCAL/aliases"
            source "$NREDF_RC_LOCAL/aliases"
        end
    else
        test -d "$NREDF_RC_LOCAL"; or mkdir -p "$NREDF_RC_LOCAL"

        if test -s "$NREDF_RC_PATH/functions.bundle"
            source "$NREDF_RC_PATH/functions.bundle"
        else if test -f "$NREDF_RC_PATH/functions"
            source "$NREDF_RC_PATH/functions"
        end

        if test -f "$NREDF_RC_LOCAL/rc"
            source "$NREDF_RC_LOCAL/rc"
        end
    end
end
