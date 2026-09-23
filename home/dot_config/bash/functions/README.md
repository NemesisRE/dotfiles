# bash-only local functions

Drop `.bash` files here — each one is `source`d automatically on shell
startup (bash only; zsh has its own equivalent at `~/.config/zsh/functions/`).
`.md` files (like this one) are skipped, everything else is sourced as code.

```bash
# example.bash
function my_function() {
  echo "hello from a local function"
}
```

`~/.config/bash/aliases` and `~/.config/bash/rc` (both optional, no
extension) work the same way for a single alias file or arbitrary startup
code. For a simple alias or an extra `$PATH` entry shared across every
shell, `~/.config/nredf/local.yaml` is usually less to write — see
`~/.config/nredf/README.md` for the full picture.
