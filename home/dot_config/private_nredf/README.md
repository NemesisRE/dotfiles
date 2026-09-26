# ~/.config/nredf — your machine-local overrides

Nothing under this directory is chezmoi-managed except the files explicitly
listed below — everything else here is yours: create it, edit it, delete it,
`chezmoi apply` will never touch or overwrite it. Full reference:
`docs/shells.md`'s "Local, Machine-Specific Overrides" section in the
dotfiles repo.

## The simple case: `local.yaml`

Copy [`local.yaml.example`](local.yaml.example) in this same directory to
`local.yaml` and edit it. One file, works identically in bash, zsh, fish and
Nushell (and PowerShell for aliases): declare extra `$PATH`-adjacent
environment variables and simple one-line aliases without writing any
shell-specific code.

## The general case: real functions and shell code

For anything `local.yaml` can't express — conditional aliases, real
functions, arbitrary startup code — every shell loads its own files from
**its own `~/.config/<shell>/` directory**, not from here at all:

| Shell | Aliases | Startup code | Functions directory |
| :--- | :--- | :--- | :--- |
| Bash | `~/.config/bash/aliases` | `~/.config/bash/rc` | `~/.config/bash/functions/*.bash` |
| Zsh | `~/.config/zsh/aliases` | `~/.config/zsh/rc` | `~/.config/zsh/functions/*` |
| Fish | `~/.config/fish/aliases` | `~/.config/fish/rc` | `~/.config/fish/functions/*.fish` — fish's **own native autoload**, not this framework's doing |
| Nushell | not supported | `~/.config/nushell/env.local.nu`, `~/.config/nushell/config.local.nu` | not supported |
| PowerShell | `~/.config/pwsh/aliases.ps1` | `~/.config/pwsh/modules.ps1` (module imports) | `~/.config/pwsh/functions/*.ps1` |

That's deliberate: `~/.config/<shell>/` is where you'd already look for
shell-specific config — consistent across every shell, including
PowerShell (via `XDG_CONFIG_HOME`, which is set on Windows too, unlike
`$PROFILE`'s directory which differs by OS). Putting a local function
anywhere else would either collide with or duplicate a shell's own native
mechanism — fish in particular already autoloads
`~/.config/fish/functions/*.fish` by itself, so this framework doesn't
reimplement that at all for fish, it's simply fish's own feature.

Every file in the table above (except the functions directories) is
already seeded by chezmoi — empty except for a header comment explaining
itself and a commented-out example — so there's nothing to create, just
open and edit. Each `functions/` directory instead has its own
`README.md` with a matching example, since anything real dropped there
gets sourced on every shell startup.

There is no shared "all shells" or "bash+zsh" tier on purpose: a function's
syntax is never portable across shells anyway, and `local.yaml` above
already covers the one thing that genuinely was shareable (simple
aliases/paths) without needing shell-specific code at all. If you want the
same alias in two shells, either put it in `local.yaml` once, or write it
twice in the two shells' own directories.

Nushell's `source` needs the target file to exist before it's even parsed,
so it can't glob a directory the way the others do — `env.local.nu` and
`config.local.nu` are its only two local-override files. Use `local.yaml`
for anything that fits it; put real nu code directly in those two files
otherwise.

## Secrets and package managers

- `aqua-vault.env` — chezmoi-managed, do not create by hand (vault-derived
  aqua GitHub token). `aqua.env` is the separate, runtime-written file
  `nredf_aqua_token_setup --env` uses instead when you have no vault
  configured — both are sourced, vault first, runtime-local second so it can
  override.
- `~/.config/aquaproj-aqua/machine.yaml` — extra aqua-managed packages, same
  format as this repo's own `aqua.yaml`.
- `~/.config/mise/config.local.toml` — extra mise-managed tool versions;
  mise merges it with the managed `config.toml` natively.
