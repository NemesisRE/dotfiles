# zsh-only local functions

Drop `.zsh` (or plain `.bash`-syntax) files here — each one is `source`d
automatically on shell startup (zsh only; bash has its own equivalent at
`~/.config/bash/functions/`). `.md` files (like this one) are skipped,
everything else is sourced as code.

```zsh
# example.zsh
function my_function() {
  echo "hello from a local function"
}
```

`~/.config/zsh/aliases` and `~/.config/zsh/rc` (both optional, no
extension) work the same way for a single alias file or arbitrary startup
code. For a simple alias or an extra `$PATH` entry shared across every
shell, `~/.config/nredf/local.yaml` is usually less to write — see
`~/.config/nredf/README.md` for the full picture.
