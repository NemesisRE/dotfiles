# Repository Guidelines for AI Coding Agents

This repository contains the **NREDF dotfiles** ecosystem managed with [chezmoi](https://chezmoi.io).
All AI agents working in this repository must strictly adhere to the following standards.

---

## 1. YAML Standards (`yamllint`)

All YAML files (including `aqua.yaml`, Carapace specs in `home/dot_config/carapace/specs/`, and `.chezmoidata/*.yaml`) must strictly conform to `.yamllint.yml`:

- **EOF Rule**: Files must terminate with **exactly one newline character (`\n`)**. Never leave trailing empty/blank lines (`empty-lines: {max-end: 0}`).
- **Indentation**: Exactly 2 spaces per indentation level. No tab characters.
- **Empty Lines**: No more than 2 consecutive blank lines anywhere within a file (`max: 2`).
- **Validation**: Always validate modified YAML files before finishing:

  ```bash
  uvx yamllint -c .yamllint.yml <path-to-yaml-file>
  ```

---

## 2. Markdown Standards (`markdownlint`)

All Markdown documentation (`docs/*.md`, `README.md`, `AGENTS.md`) must conform to `.markdownlint.yaml`:

- **Headings**: Surround all headings with exactly one blank line before and after (`MD022`).
- **Code Fences**: Surround all fenced code blocks with exactly one blank line (`MD031`).
- **Code Block Languages**: Always specify a language identifier on fenced code blocks (e.g. ```` ```bash ````, ```` ```powershell ````, ```` ```yaml ````) (`MD040`).
- **Lists**: Surround lists with a blank line (`MD032`).
- **Whitespace**: No trailing whitespace at line ends (`MD009`), no multiple consecutive blank lines (`MD012`).
- **EOF Rule**: Files must terminate with exactly one newline character (`MD047`).
- **Validation**: Always validate modified Markdown files before finishing:

  ```bash
  bunx markdownlint-cli2 --config .markdownlint.yaml <path-to-markdown-file>
  ```

---

## 3. Shell Architecture & Multi-Shell Parity

NREDF guarantees feature and ergonomic parity across **PowerShell (`pwsh`)**, **Bash**, and **Zsh** on Windows, macOS, and Linux:

- **Tri-Shell Parity**: When introducing new CLI commands, aliases, or completions, ensure all three shells are updated in sync.
- **Startup Performance**: Shell startup latency is tracked down to the millisecond (`reload -p` / `NREDF_Step`). Always use cached snippets for CLI tool initialization (`_nredf_refresh_cached_shell_snippet` in Bash/Zsh, `NREDF_RefreshCachedShellSnippet` in PowerShell).
- **Cache Invalidation**: Cached snippets must reside under `$XDG_CACHE_HOME/nredf/init/` (or `$ENV:NREDF_INITCACHE` in PowerShell) and must be purged when running `reload -c` or `reload -f`.
- **Declarative Completions**: Use [Carapace](https://carapace.sh) declarative specs in `home/dot_config/carapace/specs/` instead of shell-specific static scripts.
- **Template Safety**: Never break chezmoi templating. Always verify changes by running:

  ```powershell
  $env:NREDF_NO_BOOTSTRAP = "1"
  chezmoi apply --dry-run --force --source=.
  ```

---

## 4. Universal File Formatting & EOF Standards

Regardless of file type (Shell, PowerShell, TOML, JSON, templates, configs, etc.):

- **Strict EOF Rule**: Every file must terminate with **exactly one newline character (`\n`)**.
- **No Trailing Blank Lines**: Never generate or leave trailing blank lines at the end of any file (`empty-lines: {max-end: 0}`). The last line of content must be immediately followed by a single newline, never `\n\n`.
- **Template Cleanliness**: In chezmoi templates (`*.tmpl`), ensure template boundary tags (e.g. `{{- end }}`) do not emit extraneous trailing newlines into either the template source or the rendered target output.
