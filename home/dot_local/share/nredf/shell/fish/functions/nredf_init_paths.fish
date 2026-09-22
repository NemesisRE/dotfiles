#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish

function _nredf_init_paths --description 'Set up XDG + NREDF base directories'
    test -n "$XDG_CONFIG_HOME"; or set -gx XDG_CONFIG_HOME "$HOME/.config"
    test -n "$XDG_CACHE_HOME"; or set -gx XDG_CACHE_HOME "$HOME/.cache"
    test -n "$XDG_BIN_HOME"; or set -gx XDG_BIN_HOME "$HOME/.local/bin"
    test -n "$XDG_DATA_HOME"; or set -gx XDG_DATA_HOME "$HOME/.local/share"
    test -n "$XDG_STATE_HOME"; or set -gx XDG_STATE_HOME "$HOME/.local/state"
    test -n "$NREDF_CONFIG"; or set -gx NREDF_CONFIG "$XDG_CONFIG_HOME/nredf"
    test -n "$NREDF_LRCACHE"; or set -gx NREDF_LRCACHE "$XDG_CACHE_HOME/nredf/LRCache"
    test -n "$NREDF_LKCACHE"; or set -gx NREDF_LKCACHE "$XDG_CACHE_HOME/nredf/LKCache"
    test -n "$NREDF_COMMON_RC_LOCAL"; or set -gx NREDF_COMMON_RC_LOCAL "$HOME/.config/shell"

    if test -n "$NREDF_SHELL_NAME"
        set -gx NREDF_RC_LOCAL "$HOME/.config/$NREDF_SHELL_NAME"
    end

    if test -n "$NREDF_DOT_PATH"; and test -n "$NREDF_SHELL_NAME"
        set -gx NREDF_RC_PATH "$NREDF_DOT_PATH/shell/$NREDF_SHELL_NAME"
    end

    # Fast path: only ensure the directory tree once per shell session.
    if test "$_NREDF_PATHS_INITIALIZED" = 1; and test -d "$NREDF_LRCACHE"
        return 0
    end
    set -g _NREDF_PATHS_INITIALIZED 1

    for nredf_path in $NREDF_RC_LOCAL $NREDF_COMMON_RC_LOCAL $NREDF_CONFIG $NREDF_LRCACHE $NREDF_LKCACHE
        test -d "$nredf_path"; or mkdir -p "$nredf_path"
    end
end
