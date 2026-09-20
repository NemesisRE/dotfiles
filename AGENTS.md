# Repository Guidelines for AI Coding Agents

This repository is the **NREDF dotfiles** ecosystem, managed with [chezmoi](https://chezmoi.io). It targets Linux, macOS and Windows, and keeps **Bash, Zsh and PowerShell** at feature parity.

There is almost no test suite. What protects this repo is the verification below, so run it.

---

## 1. Verify every change

```bash
.github/scripts/check.sh            # everything CI runs
.github/scripts/check.sh --offline  # same, minus the checks that download
```

It renders `.chezmoi.toml.tmpl` with `chezmoi init`, dry-runs the whole tree twice (default data, and with every optional path enabled via `.github/fixtures/ci-data-full.yaml`), lints the *rendered* shell (shellcheck for bash, `zsh -n` for zsh), parses the rendered Windows scripts, runs PSScriptAnalyzer and markdownlint, checks Markdown links, exercises the secret templates against a stub `bw`, and re-verifies the pinned checksums. It uses a scratch config and destination, so it never touches your real `$HOME`. A check prints `SKIP` when its tool is not installed.

**Do not treat `chezmoi apply --dry-run` on its own as verification.** It renders templates but never parses or runs scripts, never evaluates `.chezmoi.toml.tmpl` (only `chezmoi init` does), and with default data never reaches any Windows or vault code path.

**What still needs a real machine:** the Windows scripts (CI only parses them), a real Linux install of Kitty, and the GitHub workflows (`refresh-pins.yml` and `yazi-package-lock.yml` only run on a Renovate PR or a schedule). Say so when a change touches them instead of implying it was tested.

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
| `home/dot_local/share/nredf/shell/{common,bash,zsh}/` | The shell framework. `rc.tmpl` is the entry point. |
| `home/Documents/PowerShell/NREDF-POSH/` | The PowerShell equivalent. |
| `docs/` | User documentation. |

**Function bundles are generated.** `functions.bundle.tmpl` (shell) and `Functions.bundle.ps1.tmpl` (PowerShell) `glob` their `functions/` directory, so a new function file is picked up automatically. Never re-introduce a hand-maintained include list: the loaders only fall back to the directory when the bundle is *absent*, so anything missing from a list is silently never loaded.

**Startup performance is a feature.** Initialise CLI tools through the cached snippet helpers (`_nredf_refresh_cached_shell_snippet` in Bash/Zsh, `NREDF_RefreshCachedShellSnippet` in PowerShell). Snippets live under `$XDG_CACHE_HOME/nredf/init/` (`$ENV:NREDF_INITCACHE` in PowerShell). `reload -c` clears the last-run stamps together with those snippets, the sheldon cache and the completion dump; `reload -f` does that plus a full refresh; `reload -p` toggles startup profiling.

**Completions** are declarative [Carapace](https://carapace.sh) specs in `home/dot_config/carapace/specs/`, not shell-specific scripts.

**Tri-shell parity:** when you add a command, alias or completion, update all three shells.

---

## 3. Rules that exist because they were broken

Each of these caused a real defect. Check your change against them.

### chezmoi

- **Anything that can hold a secret is `private_`** (mode `0600`, and the directory too). This applies to rendered MCP configs, `~/.ssh`, `~/.claude`, and anything fed by a vault template. Nothing in the repo's source is a secret; the *rendered* file is.
- **`modify_` scripts must not have a `.tmpl` extension.** With it, `.chezmoi.stdin` does not exist. Start the file with `{{- /* chezmoi:modify-template */ -}}`. `~/.claude/settings.json` is managed this way so keys Claude Code writes itself survive.
- **`.chezmoiignore` matches target paths.** Gate per-OS files there (for example `.config/Code` is Linux-only), not in the file itself.
- **A `run_onchange_` script re-runs only when its rendered text changes.** Embed the hash of each input in a comment, using `include` for plain files and `includeTemplate` for files that render with data.
- **`before` scripts must never abort the apply.** A non-zero exit stops `chezmoi apply` before any dotfile is written, so a missing sudo, no network or a failing package install must warn and continue. Guard every hook with `[[ -n "${CI:-}" ]] && exit 0` and `NREDF_NO_BOOTSTRAP`. Only print "success" when the command succeeded.
- **`bw` returns explicit nulls** (`"notes": null`). `hasKey` is true for those, and a nil reaching `trim` aborts the apply. Read vault values with `index $item "k" | default ""`. `.github/scripts/test-secret-templates.py` guards this.
- **`chezmoi init` does not re-ask questions you already answered.** The prompts use `promptStringOnce`, which keeps the value stored in `~/.config/chezmoi/chezmoi.toml`; use `chezmoi init --prompt` (or edit that file) to change one.
- **Run `.ps1` hooks under `pwsh`.** `home/.chezmoi.toml.tmpl` sets `[interpreters.ps1]`. Windows PowerShell 5.1 fails on `?.` (a parse error) and on `ConvertFrom-Json -AsHashtable`, and chezmoi defaults to it.

### Shell

- **Never prompt, block or print on startup.** A non-interactive login shell (`bash -lc`, `ssh host cmd`) must produce no stdout. Diagnostics go to stderr. Anything that reads `/dev/tty` needs a timeout, and "unanswered" must not be recorded as "no".
- **`BW_SESSION` is restored from the keychain at startup on purpose.** chezmoi (`unlock = "auto"` with its `bitwarden` templates) and any `bw` run by hand read it from the environment, and PowerShell restores it at startup too. It is a vault key inherited by every child process; that trade-off was made deliberately. Do not make it lazy or drop it as a "security fix" without asking, because a regression there only shows up as a master-password prompt on every `chezmoi apply`.
- **Zsh does not expand glob qualifiers inside `[[ ... ]]`.** `[[ -n "$f"(Nmh-24) ]]` is always true. Assign to an array instead: `local -a m=( "$f"(Nmh-24) ); (( ${#m} ))`. Zsh arrays are also 1-indexed.
- **Keep `set -e` in mind.** Inside a function called from an `if`/`||` condition, bash disables it; use explicit `|| exit 1` there.

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
