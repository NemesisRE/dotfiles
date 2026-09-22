#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# Loads user-local overrides, in the same order bash/zsh use. Fish has no
# sibling shell to share a "common" tier of *user-authored* override files
# with (those are bash-syntax, e.g. $NREDF_CONFIG/shell/common/aliases —
# fish cannot source them), so unlike bash/zsh this only ever consults the
# fish-specific override paths (`$NREDF_CONFIG/shell/fish/...`). Fish's own
# unmatched globs already expand to zero elements, so no zsh-style
# `setopt nullglob` equivalent is needed here.
#
# Usage: _nredf_set_local [true|false]   (true = load aliases, false/omitted = load functions/rc)

function _nredf_set_local --argument-names alias_mode
    _nredf_init_paths

    test -n "$alias_mode"; or set alias_mode false

    if test "$alias_mode" = true
        if test -f "$NREDF_RC_PATH/aliases"
            source "$NREDF_RC_PATH/aliases"
        end

        if test -f "$NREDF_RC_LOCAL/aliases.local"
            source "$NREDF_RC_LOCAL/aliases.local"
        end
    else
        test -d "$NREDF_RC_LOCAL"; or mkdir -p "$NREDF_RC_LOCAL"

        if test -f "$NREDF_RC_LOCAL/functions.local"
            source "$NREDF_RC_LOCAL/functions.local"
        end

        if test -f "$NREDF_COMMON_RC_LOCAL/rc.local"
            source "$NREDF_COMMON_RC_LOCAL/rc.local"
        end

        if test -f "$NREDF_RC_LOCAL/rc.local"
            source "$NREDF_RC_LOCAL/rc.local"
        end

        if test -d "$NREDF_CONFIG/shell/$NREDF_SHELL_NAME/functions"
            for nredf_local_function in "$NREDF_CONFIG/shell/$NREDF_SHELL_NAME/functions/"*
                test -f "$nredf_local_function"; or continue
                source "$nredf_local_function"
            end
        end

        if test -s "$NREDF_RC_PATH/functions.bundle"
            source "$NREDF_RC_PATH/functions.bundle"
        else if test -f "$NREDF_RC_PATH/functions"
            source "$NREDF_RC_PATH/functions"
        end

        if test -f "$NREDF_CONFIG/shell/$NREDF_SHELL_NAME/aliases"
            source "$NREDF_CONFIG/shell/$NREDF_SHELL_NAME/aliases"
        end

        if test -f "$NREDF_CONFIG/shell/$NREDF_SHELL_NAME/rc"
            source "$NREDF_CONFIG/shell/$NREDF_SHELL_NAME/rc"
        end
    end
end
