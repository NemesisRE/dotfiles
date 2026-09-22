# nredf: your machine-local nu environment overrides.
#
# Sourced at the end of env.nu, after every default is set. chezmoi seeded
# this file once, empty, and will never overwrite it again (the `create_`
# attribute) — edit it freely.
#
# Keep this file to plain `$env.X = ...` assignments and `def --env`
# commands: nu's `source` needs a file to exist before it is even parsed, so
# unlike bash/zsh/fish this file (and config.local.nu, its config.nu
# counterpart) is nu's only supported local-override point — see
# docs/shells.md's parity-exceptions section for why the fuller
# functions.local/rc.local cascade those shells get isn't possible here.
