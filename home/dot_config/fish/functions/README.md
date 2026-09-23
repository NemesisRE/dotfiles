# fish-only local functions

This is fish's own native autoload directory, not something this dotfiles
framework adds — fish loads `<name>.fish` from here the first time `<name>`
is called, lazily, purely built into fish itself. Nothing here needs to be
registered anywhere; `.md` files (like this one) are simply never matched
by that lookup, so they're harmless to leave in place.

```fish
# my_function.fish
function my_function
    echo "hello from a local function"
end
```

`~/.config/fish/aliases` and `~/.config/fish/rc` (both optional, no
extension) are this framework's own local-override files — for a single
alias file or arbitrary startup code, since fish has no native equivalent
of those two. For a simple alias or an extra `$PATH` entry shared across
every shell, `~/.config/nredf/local.yaml` is usually less to write — see
`~/.config/nredf/README.md` for the full picture.
