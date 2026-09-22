# Repository Guidelines for AI Coding Agents

This repository is the **NREDF dotfiles** ecosystem, managed with [chezmoi](https://chezmoi.io). It targets Linux, macOS and Windows, and keeps **Bash, Zsh, Fish, Nushell and PowerShell** — the five supported shells — at feature parity, with a small set of documented, justified exceptions (see `docs/shells.md`'s "Known Parity Exceptions" section). Fish has no Windows build at all; it runs on Linux and macOS only.

There is almost no test suite. What protects this repo is the verification below, so run it.

---

## 1. Verify every change

```bash
.github/scripts/check.sh            # everything CI runs
.github/scripts/check.sh --offline  # same, minus the checks that download
```

It renders `.chezmoi.toml.tmpl` with `chezmoi init`, dry-runs the whole tree twice (default data, and with every optional path enabled via `.github/fixtures/ci-data-full.yaml`), lints the *rendered* shell (shellcheck for bash, `zsh -n` for zsh, `fish --no-execute` for fish, `nu -c "nu-check --debug ..."` for nu), parses the rendered Windows scripts, runs PSScriptAnalyzer and markdownlint, checks Markdown links, exercises the secret templates against a stub `bw`, and re-verifies the pinned checksums. It uses a scratch config and destination, so it never touches your real `$HOME`. A check prints `SKIP` when its tool is not installed.

**Do not treat `chezmoi apply --dry-run` on its own as verification.** It renders templates but never parses or runs scripts, never evaluates `.chezmoi.toml.tmpl` (only `chezmoi init` does), and with default data never reaches any Windows or vault code path.

**What still needs a real machine:** the Windows scripts (CI only parses them), a real Linux install of Kitty, a real interactive Fish or Nushell session (CI only syntax-checks the rendered templates — the Ctrl+Space fzf-tab widget, the keychain-backed `bwu`/`bwlock` round trip, and Nushell's one-restart cache lag all need one), and the GitHub workflows (`refresh-pins.yml` and `yazi-package-lock.yml` only run on a Renovate PR or a schedule). Say so when a change touches them instead of implying it was tested.

---

## 2. How the repo is organised

`.chezmoiroot` points chezmoi at `home/`, so `home/dot_config/x` deploys to `~/.config/x`. Paths in `.github/` and the root files are *not* deployed.

| Path | Purpose |
| :--- | :--- |
| `home/.chezmoi.toml.tmpl` | Prompts once at `chezmoi init` and writes `~/.config/chezmoi/chezmoi.toml`. |
| `home/.chezmoidata/*.yaml` | Default data (tool versions, toggles, package lists, pinned checksums). |
| `home/.chezmoiscripts/` | `run_once_before_*`, `run_onchange_before_*` and `run_onchange_after_*` hooks, one per OS family. |
| `home/.chezmoitemplates/` | Shared templates: secret lookups (`get-*.tmpl`) and MCP rendering. |
| `home/.chezmoiignore.tmpl` | Per-OS gating. Patterns are **target** paths, not source paths. |
| `home/dot_local/share/nredf/shell/{common,bash,zsh,fish}/` | The shell framework. `rc.tmpl` is the entry point (bash/zsh share `common/rc.tmpl`; fish has no sibling shell to share one with, so `fish/rc.tmpl` is self-contained). |
| `home/dot_local/share/nredf/shell/nu/` | The Nushell equivalent — `env.nu.tmpl`/`config.nu.tmpl`, **not** under `dot_local/share` for its actual entry points. Nu's config directory is platform-specific and resolved before nu reads any of its own files, so three thin per-OS stubs (`home/dot_config/nushell/`, `home/private_Library/private_Application Support/nushell/`, `home/AppData/Roaming/nushell/`) just `source` this canonical tree — see `docs/shells.md`. |
| `home/Documents/PowerShell/NREDF-POSH/` | The PowerShell equivalent. |
| `docs/` | User documentation. |

**Function bundles are generated.** `functions.bundle.tmpl` (bash/zsh/fish/nu) and `Functions.bundle.ps1.tmpl` (PowerShell) `glob` their `functions/` directory, so a new function file is picked up automatically. Never re-introduce a hand-maintained include list: the loaders only fall back to the directory when the bundle is *absent*, so anything missing from a list is silently never loaded. **Nu has no such fallback at all** — its `source` requires the target to already exist on disk before the file is even parsed, so the generated bundle is nu's only load path, not a fast path.

**Startup performance is a feature.** Initialise CLI tools through the cached snippet helpers (`_nredf_refresh_cached_shell_snippet` in Bash/Zsh/Fish, `NREDF_RefreshCachedShellSnippet` in PowerShell). Snippets live under `$XDG_CACHE_HOME/nredf/init/` (`$ENV:NREDF_INITCACHE` in PowerShell). `reload -c` clears the last-run stamps together with those snippets, the sheldon cache and the completion dump; `reload -f` does that plus a full refresh; `reload -p` toggles startup profiling. **Nu is different**: the same `source`-needs-the-file-to-already-exist restriction means a nu cache can only be refreshed and sourced across two separate shell starts, never within one (`nredf-cache-refresh` in `nu/functions/nredf_refresh_cached_shell_snippet.nu` only handles the regenerate half; the `source` line is written out literally per tool in `config.nu.tmpl`) — a refreshed nu tool integration takes effect on the *next* shell start, not the current one.

**Completions** are declarative [Carapace](https://carapace.sh) specs in `home/dot_config/carapace/specs/`, not shell-specific scripts — this is the one area where all five shells already get equal treatment for free, since carapace itself renders the shell-specific glue.

**Five-shell parity:** when you add a command, alias or completion, update all five shells, or explicitly document why one is exempt (see `docs/shells.md`'s "Known Parity Exceptions" section — e.g. nu has no equivalent of the Ctrl+Space fzf-tab widget, and kitty has no nu shell-integration upstream at all).

---

## 3. Rules that exist because they were broken

Each of these caused a real defect. Check your change against them.

### chezmoi

- **Anything that can hold a secret is `private_`** (mode `0600`, and the directory too). This applies to rendered MCP configs, `~/.ssh`, `~/.claude`, and anything fed by a vault template. Nothing in the repo's source is a secret; the *rendered* file is.
- **`modify_` scripts must not have a `.tmpl` extension.** With it, `.chezmoi.stdin` does not exist. Start the file with `{{- /* chezmoi:modify-template */ -}}`. `~/.claude/settings.json` and `~/.gemini/antigravity-cli/settings.json` are managed this way (shared logic in `merge-json-settings.tmpl`) so keys the tools write themselves survive.
- **`.chezmoiignore` matches target paths.** Gate per-OS files there (for example `.config/Code` and `.config/nushell` are Linux-only), not in the file itself.
- **`create_` only works on a file, not a directory.** `create_dot_cache/foo` deploys a literal directory named `create_dot_cache`, not `.cache/foo` created-once — the attribute has to sit on the filename itself (`dot_cache/create_foo`). A directory only ever needs `dot_`/`private_`, never `create_`.
- **An empty source file is skipped by default, not deployed as an empty file.** Add `empty_` (it composes with `create_`: `create_empty_foo`) when you actually want a real, empty, deployed file — e.g. a placeholder a runtime cache will later overwrite.
- **`.chezmoi.homeDir` always resolves to the real host home directory**, never to `--destination`'s override. A template that bakes in an absolute path via `.chezmoi.homeDir` (nu's entry-point stubs do this, since nu can't resolve `$HOME` lazily at parse time) can't be exercised against a scratch destination without first rewriting that baked prefix — see `check_nu` in `.github/scripts/lint-rendered.sh` for the pattern.
- **A target directory needs consistent attributes across every source path that maps into it.** `home/Library/...` and `home/private_Library/...` cannot coexist — chezmoi refuses with "inconsistent state". Nest a new file under whichever prefix (`private_` or plain) the directory already uses.
- **A `run_onchange_` script re-runs only when its rendered text changes.** Embed the hash of each input in a comment, using `include` for plain files and `includeTemplate` for files that render with data.
- **`before` scripts must never abort the apply.** A non-zero exit stops `chezmoi apply` before any dotfile is written, so a missing sudo, no network or a failing package install must warn and continue. Guard every hook with `[[ -n "${CI:-}" ]] && exit 0` and `NREDF_NO_BOOTSTRAP`. Only print "success" when the command succeeded.
- **`bw` returns explicit nulls** (`"notes": null`). `hasKey` is true for those, and a nil reaching `trim` aborts the apply. Read vault values with `index $item "k" | default ""`. `.github/scripts/test-secret-templates.py` guards this.
- **`chezmoi init` does not re-ask questions you already answered.** The prompts use `promptStringOnce`, which keeps the value stored in `~/.config/chezmoi/chezmoi.toml`; use `chezmoi init --prompt` (or edit that file) to change one.
- **Run `.ps1` hooks under `pwsh`.** `home/.chezmoi.toml.tmpl` sets `[interpreters.ps1]`. Windows PowerShell 5.1 fails on `?.` (a parse error) and on `ConvertFrom-Json -AsHashtable`, and chezmoi defaults to it.

### Shell

- **Never prompt, block or print on startup.** A non-interactive login shell (`bash -lc`, `ssh host cmd`) must produce no stdout. Diagnostics go to stderr. Anything that reads `/dev/tty` needs a timeout, and "unanswered" must not be recorded as "no". **Fish reads `config.fish` for every invocation, interactive or not** (unlike bash's `[ -z "$PS1" ] && return`), so `fish/rc.tmpl` gates everything on `status is-interactive` itself rather than relying on a separate non-interactive entry file. **Nu skips loading `env.nu`/`config.nu` for a plain non-interactive `nu -c`**, but a login-shell invocation (`nu --login -c ...`, some `ssh host cmd` setups) still loads them non-interactively, so `config.nu.tmpl` still gates on `$nu.is-interactive` too, in addition to nu's own default behavior. Neither fish's `read` nor nu's `input` has a timeout flag at all (unlike bash's `read -t`); the token-setup wizard shells out to `timeout`/`gtimeout` if one is installed and otherwise falls back to an untimed prompt, still gated on a real interactive tty.
- **`BW_SESSION` is restored from the keychain at startup on purpose.** chezmoi (`unlock = "auto"` with its `bitwarden` templates) and any `bw` run by hand read it from the environment, and PowerShell/Fish/Nu restore it at startup too. It is a vault key inherited by every child process; that trade-off was made deliberately. Do not make it lazy or drop it as a "security fix" without asking, because a regression there only shows up as a master-password prompt on every `chezmoi apply`. **In Nu specifically**, this only works if every function in the call chain up to the one assigning `$env.BW_SESSION` is declared `def --env` — a single plain `def` anywhere in that chain silently swallows the mutation with no error (see below).
- **Zsh does not expand glob qualifiers inside `[[ ... ]]`.** `[[ -n "$f"(Nmh-24) ]]` is always true. Assign to an array instead: `local -a m=( "$f"(Nmh-24) ); (( ${#m} ))`. Zsh arrays are also 1-indexed.
- **Keep `set -e` in mind.** Inside a function called from an `if`/`||` condition, bash disables it; use explicit `|| exit 1` there.
- **Nu's `def` is not dynamically scoped.** A function only mutates the caller's `$env` if declared `def --env`, and that propagation stops dead at the first non-`--env` hop in the call chain — confirmed by testing a plain `def` that calls an `--env` def: the mutation is visible for the rest of the plain def's own body, but vanishes the instant it returns to *its* caller. Every function anywhere in a chain that needs to reach top-level `$env` must be `--env`, all the way up; `load-env` and `hide-env` need it too, not just `$env.X = ...`.
- **Nu's `source`/`use` need the target file to exist on disk *before the containing file is even parsed*** — not just before that line executes. This holds even inside a runtime `if path exists { source ... }` guard, so a maybe-missing file (a user's local override, a cold tool-init cache) can never be conditionally sourced the way bash/zsh/fish do it; chezmoi has to pre-seed a real placeholder (`create_`/`empty_`) so the file always exists.
- **Nu's own `mkdir` is unconditionally idempotent** (like bash's `mkdir -p`, with no non-`-p` equivalent), so it cannot be used as a `mkdir`-based mutex the way bash's lockfile helper does. Shell out to the external `^mkdir` binary for that, which does fail on an existing directory.
- **`ssh-agent -s`'s output is sh/bash syntax.** Fish's `eval` and Nu's `source`/`eval` can't interpret it; parse the `SSH_AGENT_PID=...;` text out of the output instead of trying to `eval`/`source` it.

### Downloads that get executed

- **Never `curl ... | sh`, and never download `latest`.** Pin the version *and* a SHA-256, and refuse on mismatch. The pins live in `home/.chezmoidata/kitty.yaml` and `aqua-bootstrap.yaml` (plus a copy in `bootstrap.ps1`, which is fetched before chezmoi exists), and `.github/scripts/pins.py verify` re-downloads and checks all of them in CI.
- **To bump a pinned tool,** change its `version` and run `.github/scripts/pins.py update`. Renovate PRs get this automatically from `.github/workflows/refresh-pins.yml`.
- **GitHub Actions are pinned to a commit SHA** with the tag as a comment. Renovate maintains them.
- **A push made with the default `GITHUB_TOKEN` does not trigger workflows.** Anything a bot pushes needs its CI run explicitly (`workflow_dispatch`), and bot output should go to a branch or PR, never straight to `main`.

### Commits

Use Conventional Commits with a scope (`fix(shell): ...`, `ci: ...`, `feat(pins): ...`), and explain *why* in the body.

---

## 4. Formatting standards

`yamllint` and `markdownlint` are enforced in CI (`.yamllint.yml`, `.markdownlint.yaml`); `.editorconfig` covers the rest.

- **YAML:** two-space indent, no tabs, no blank lines at end of file, at most two consecutive blank lines. Check with `uvx yamllint -c .yamllint.yml <file>`.
- **Markdown:** blank line around headings, fenced blocks and lists; a language on every fenced block; no trailing whitespace; single trailing newline. Check with `bunx markdownlint-cli2 --config .markdownlint.yaml <file>`.
- **Every file you create or edit should end with exactly one newline.** Only YAML and Markdown are enforced by a linter; roughly fifty older files (many templates and configs) still end with an extra blank line. Do not sweep them up inside an unrelated change: some are deployed files whose edit re-runs a `run_onchange_` hook.
- **Template tags must not leak whitespace** into the rendered output. Trim with `{{-` / `-}}` where a tag would otherwise emit a stray newline.
- **Relative links only** in Markdown. `.github/scripts/check-md-links.py` rejects `file:///...` and links to files that do not exist.
