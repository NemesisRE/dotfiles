#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
# chezmoi-managed: kitty shell integration bootstrap for fish.
#
# kitty ships its fish integration as a vendor_conf.d snippet
# (shell-integration/fish/vendor_conf.d/kitty-shell-integration.fish), which
# fish would normally auto-load on its own — sourcing it explicitly here
# instead keeps the same enable/disable mode control bash/zsh have, and keeps
# this a no-op unless a real kitty install is detected, matching their guard.

function _nredf_init_kitty_shell_integration --argument-names force_init
    if test "$force_init" != --force; and test "$NREDF_KITTY_SHELL_INTEGRATION_DONE" = 1
        return 0
    end

    set -l kitty_dir "$KITTY_INSTALLATION_DIR"
    test -n "$kitty_dir"; or return 0

    set -l kitty_mode "$KITTY_SHELL_INTEGRATION"
    test -n "$kitty_mode"; or set kitty_mode "$NREDF_KITTY_SHELL_INTEGRATION_MODE"
    test -n "$kitty_mode"; or set kitty_mode enabled

    if string match -q '*disabled*' -- " $kitty_mode "
        return 0
    end

    set kitty_mode (string replace -a no-rc '' -- "$kitty_mode")
    set kitty_mode (string trim -- "$kitty_mode")
    test -n "$kitty_mode"; or set kitty_mode enabled

    set -gx NREDF_KITTY_SHELL_INTEGRATION_MODE "$kitty_mode"

    set -l kitty_fish "$kitty_dir/shell-integration/fish/vendor_conf.d/kitty-shell-integration.fish"
    if test -f "$kitty_fish"
        set -gx KITTY_SHELL_INTEGRATION "$kitty_mode"
        source "$kitty_fish"
        set -g NREDF_KITTY_SHELL_INTEGRATION_DONE 1
        _nredf_step "kitty integration"
    end
end
