#!/usr/bin/env bash
#
# Run locally what CI runs, so a change can be verified before it is pushed.
#
#   .github/scripts/check.sh             everything
#   .github/scripts/check.sh --offline   skip checks that download (pins.py verify)
#
# Each check prints PASS / FAIL / SKIP (SKIP = the tool is not installed). Exits
# non-zero if any check FAILS. Nothing here writes to your real HOME or chezmoi
# state: chezmoi runs against a scratch config, cache, persistent state and
# destination (never your real ~/.config/chezmoi or ~/.cache/chezmoi), with
# CI=1 so the secret templates never reach a vault. Compatible with bash 3.2
# (macOS).

set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}" || exit 2

OFFLINE=0
for arg in "$@"; do
  case "${arg}" in
    --offline) OFFLINE=1 ;;
    -h | --help)
      sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown option: ${arg}" >&2
      exit 2
      ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
have chezmoi || { echo "chezmoi is required" >&2; exit 2; }
have python3 || { echo "python3 is required" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
mkdir -p "${TMP}/home"

PASS=0
FAIL=0
SKIP=0
FAILED=()

run() { # run <name> <command...>
  local name="$1"
  shift
  if "$@" >"${TMP}/out" 2>&1; then
    printf '  PASS  %s\n' "${name}"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s\n' "${name}"
    sed 's/^/        /' "${TMP}/out" | tail -25
    FAIL=$((FAIL + 1))
    FAILED+=("${name}")
  fi
}
skip() { # skip <name> <reason>
  printf '  SKIP  %s (%s)\n' "$1" "$2"
  SKIP=$((SKIP + 1))
}

# ── helpers that need more than one command ─────────────────────────────────────
yamllint_all() {
  if have yamllint; then yamllint -c .yamllint.yml .; else uvx yamllint -c .yamllint.yml .; fi
}
markdownlint_all() {
  # Pinned to match ci.yml's `markdownlint-cli2@0.23.3` step — only for the
  # download-on-demand paths; a pre-installed `markdownlint-cli2` on PATH is
  # whatever version the developer has and isn't forced.
  if have markdownlint-cli2; then markdownlint-cli2 --config .markdownlint.yaml "**/*.md"
  elif have bunx; then bunx markdownlint-cli2@0.23.3 --config .markdownlint.yaml "**/*.md"
  else npx --yes markdownlint-cli2@0.23.3 --config .markdownlint.yaml "**/*.md"; fi
}
shellcheck_plain() { # the gate CI's ShellCheck job applies (warning severity)
  { find home/dot_local/share/nredf/shell -type f \( -name '*.bash' -o -name '*.sh' \)
    ls bootstrap.sh .github/scripts/*.sh; } | xargs shellcheck -S warning
}
dry_run() { # dry_run [extra chezmoi args...]
  local excl=()
  (( OFFLINE )) && excl=(--exclude=externals)
  # bash 3.2's `set -u` treats "${excl[@]}" on a genuinely empty array as an
  # unbound-variable error (fixed in later bash — this repo still has to run
  # on macOS's system bash). The `${arr[@]+"${arr[@]}"}` idiom sidesteps it:
  # the parameter-expansion existence test only fires when the array has at
  # least one element.
  #
  # `--exclude=externals` does NOT make this network-free, despite the name —
  # verified empirically (fresh cache, byte-for-byte identical ~14MB fetched
  # into `--cache` with and without it): chezmoi still fetches every
  # `.chezmoiexternals/*` entry (ble.sh, k9s, fzf) to compute the dry-run
  # plan; the flag only excludes them from that plan's *output*/from being
  # written. There is no chezmoi flag that skips the fetch itself with a cold
  # cache — this is a real limitation, not something fixable here. It's kept
  # anyway for a quieter, more focused dry-run diff under --offline, and
  # `--offline` continues to mean, as before this change, "skip pins.py
  # verify's explicit re-download loop" — not "no network at all".
  CI=1 NREDF_NO_BOOTSTRAP=1 chezmoi apply --dry-run --force --source="${ROOT}" \
    --config "${TMP}/chezmoi.toml" --cache "${TMP}/cache" --destination "${TMP}/home" \
    ${excl[@]+"${excl[@]}"} "$@"
}
parse_ps1_tmpl() { # parse_ps1_tmpl <source.ps1.tmpl>
  # --dry-run renders scripts but never parses them, so a PowerShell syntax error
  # would ship. Render, then parse.
  chezmoi execute-template --source="${ROOT}" --config "${TMP}/chezmoi.toml" --cache "${TMP}/cache" \
    --override-data-file .github/fixtures/ci-data-full.yaml -f "$1" \
    </dev/null >"${TMP}/w.ps1" || { echo "render failed: $1"; return 1; }
  [[ -s "${TMP}/w.ps1" ]] || return 0
  # shellcheck disable=SC2016 # `$e` etc. is PowerShell, not bash
  PS_FILE="${TMP}/w.ps1" pwsh -NoProfile -Command '
    $e = $null
    [System.Management.Automation.Language.Parser]::ParseFile($env:PS_FILE, [ref]$null, [ref]$e) | Out-Null
    if ($e) { $e | ForEach-Object { Write-Host $_ }; exit 1 }' || { echo "parse error: $1"; return 1; }
}
parse_rendered_powershell() {
  local f n=0
  # Windows-only scripts are gated on `.chezmoi.os "windows"`; force that branch
  # so this works on any host.
  for f in home/.chezmoiscripts/*.ps1.tmpl home/Documents/WindowsPowerShell/*.ps1.tmpl; do
    [[ -e "${f}" ]] || continue
    sed 's/\.chezmoi\.os "windows"/"windows" "windows"/' "${f}" >"${TMP}/w.tmpl"
    parse_ps1_tmpl "${TMP}/w.tmpl" || return 1
    n=$((n + 1))
  done
  # Cross-platform PowerShell profile templates (pwsh runs on macOS/Linux too) —
  # no OS gate to force.
  for f in home/dot_local/share/nredf/shell/pwsh/*.ps1.tmpl; do
    [[ -e "${f}" ]] || continue
    parse_ps1_tmpl "${f}" || return 1
    n=$((n + 1))
  done
  echo "parsed ${n} rendered PowerShell templates"
}
# run_once_/run_onchange_ scripts are plain subprocesses: `--destination`
# redirects what CHEZMOI ITSELF writes, but a script that reads `${HOME}` at
# its own runtime (several do — e.g. run_once_before_clean-legacy-zsh-
# functions.sh.tmpl's `rm -f "${HOME}/..."`) sees whatever `$HOME` this shell
# has, not `--destination`. Confirmed empirically: a real (non-dry-run)
# `chezmoi apply --destination "$TMP/home"` run without this override still
# leaves scripts seeing the real `$HOME` — exactly the leak check.sh's header
# promises never happens. `.chezmoi.homeDir` follows `$HOME` too (confirmed:
# it does NOT follow `--destination`, matching AGENTS.md's note — but it DOES
# follow the `$HOME` env var), so overriding `$HOME` here redirects both at
# once. --dry-run (used everywhere else in this script) never executes
# scripts at all — confirmed empirically — so only the real-apply path below
# needs this.
# These three always pass --exclude=externals, regardless of --offline: it
# does NOT make chezmoi skip fetching .chezmoiexternals/* over the network
# (verified — see dry_run()'s comment; chezmoi still fetches ble.sh/k9s/fzf to
# compute the apply plan even with a cold cache), so gating it on --offline
# would be misleading here. What it does do is keep those large third-party
# archives from actually being extracted into the scratch destination on
# EVERY run, online or offline — unrelated to what these checks are
# validating (this repo's own templates/scripts), and unnecessary I/O and
# failure surface (an upstream CDN hiccup) a real apply doesn't need to carry.
apply_real() { # apply_real — a REAL (non-dry-run) apply into the scratch
  # destination, so every run_once_/run_onchange_ hook actually executes (under
  # CI=1/NREDF_NO_BOOTSTRAP=1, so none of them do real installs — see AGENTS.md's
  # "before scripts must never abort the apply" and the guards each hook has).
  # --dry-run alone never proves the destination tree it describes is actually
  # writable end-to-end.
  HOME="${TMP}/home" CI=1 NREDF_NO_BOOTSTRAP=1 chezmoi apply --force --source="${ROOT}" \
    --config "${TMP}/chezmoi.toml" --cache "${TMP}/cache" --destination "${TMP}/home" \
    --exclude=externals
}
apply_idempotent() { # a second apply must produce an empty diff — a
  # `run_onchange_` whose hash comment is wrong, or a template with
  # non-deterministic output, would otherwise "converge" to a different state
  # every single apply. Needs its own second `chezmoi apply` call — apply_real's
  # first apply established the baseline this compares against; there is no way
  # to test "does a second apply change anything" with fewer than two applies.
  HOME="${TMP}/home" CI=1 NREDF_NO_BOOTSTRAP=1 chezmoi apply --force --source="${ROOT}" \
    --config "${TMP}/chezmoi.toml" --cache "${TMP}/cache" --destination "${TMP}/home" \
    --exclude=externals || return 1
  local diff
  diff="$(HOME="${TMP}/home" CI=1 NREDF_NO_BOOTSTRAP=1 chezmoi diff --source="${ROOT}" \
    --config "${TMP}/chezmoi.toml" --cache "${TMP}/cache" --destination "${TMP}/home" \
    --exclude=externals)"
  if [[ -n "${diff}" ]]; then
    echo "chezmoi diff is not empty after a second apply:"
    echo "${diff}"
    return 1
  fi
}
verify_destination() {
  HOME="${TMP}/home" CI=1 NREDF_NO_BOOTSTRAP=1 chezmoi verify --source="${ROOT}" \
    --config "${TMP}/chezmoi.toml" --cache "${TMP}/cache" --destination "${TMP}/home" \
    --exclude=externals
}
init_variant() { # init_variant <label> <seed-toml-body> — exercises a branch of
  # .chezmoi.toml.tmpl that --override-data-file can never reach, because only
  # `chezmoi init` evaluates that file at all. promptStringOnce only re-prompts
  # when a key is genuinely unanswered (see AGENTS.md), and neither
  # --promptString nor --promptBool actually feed it one (verified empirically:
  # both are silently ignored by promptStringOnce in chezmoi v2.72.2) — so the
  # supported way to pick a specific branch non-interactively is AGENTS.md's own
  # documented workaround, "edit that file": pre-seed the scratch config's
  # [data] with the answer, which promptStringOnce then treats as already
  # answered and returns unprompted.
  local label="$1" body="$2"
  local cfg="${TMP}/variant-${label}.toml"
  printf '%s\n' "${body}" >"${cfg}"
  chezmoi --config "${cfg}" init --source="${ROOT}" --config-path "${cfg}" \
    --cache "${TMP}/cache" --persistent-state "${TMP}/variant-${label}.boltdb" \
    --promptDefaults --no-tty </dev/null
}

echo "==> Setup"
# `--config` (not just init's own `--config-path`) has to point at the scratch
# file too: promptStringOnce's "already answered?" lookup follows the global
# `--config` resolution, not `--config-path` (which only controls where the
# NEW file gets written) — without it, `chezmoi init` here silently reads (and
# "once"-answers every prompt from) your REAL ~/.config/chezmoi/chezmoi.toml,
# which is exactly the real-$HOME leak this script exists to avoid. Confirmed
# empirically: omitting --config surfaces the real machine's git name/email
# and secret URIs in the generated scratch config. --cache/--persistent-state
# keep the same isolation for chezmoi's cache and its "once" state database
# (both otherwise default under ~/.cache/chezmoi and ~/.config/chezmoi).
if ! chezmoi --config "${TMP}/chezmoi.toml" init --source="${ROOT}" --config-path "${TMP}/chezmoi.toml" \
  --cache "${TMP}/cache" --persistent-state "${TMP}/state.boltdb" --promptDefaults --no-tty \
  </dev/null >"${TMP}/init.out" 2>&1; then
  echo "  FAIL  chezmoi init (renders .chezmoi.toml.tmpl)"
  sed 's/^/        /' "${TMP}/init.out" | tail -15
  exit 1
fi
echo "  PASS  chezmoi init (renders .chezmoi.toml.tmpl)"
PASS=$((PASS + 1))

# Diagnostic only, never gates pass/fail: chezmoi doctor reports on the local
# tool environment (missing optional binaries, version skew) which is useful
# context on a FAIL below but isn't itself a repo-correctness check.
echo "==> chezmoi doctor (diagnostic only)"
HOME="${TMP}/home" chezmoi --config "${TMP}/chezmoi.toml" doctor --cache "${TMP}/cache" --destination "${TMP}/home" 2>&1 | sed 's/^/    /' || true

echo "==> Static checks"
if have yamllint || have uvx; then run "yamllint" yamllint_all; else skip "yamllint" "install yamllint or uv"; fi
if have markdownlint-cli2 || have bunx || have npx; then run "markdownlint" markdownlint_all; else skip "markdownlint" "install markdownlint-cli2, bun or node"; fi
run "markdown links" python3 .github/scripts/check-md-links.py
if have shellcheck; then
  run "shellcheck (plain scripts)" shellcheck_plain
  run "shellcheck/zsh/fish/nu (rendered templates)" ./.github/scripts/lint-rendered.sh "${TMP}/chezmoi.toml"
else
  skip "shellcheck" "not installed"
fi
if have actionlint; then run "actionlint" actionlint -color=false .github/workflows/*.yml; else skip "actionlint" "not installed"; fi
run "repo rules (hooks, modify_, private_, hash comments)" python3 .github/scripts/test-repo-rules.py

echo "==> Templates and behaviour"
run "secret-template tests (stub bw)" python3 .github/scripts/test-secret-templates.py
run "chezmoi apply --dry-run (default data)" dry_run
# Every ci-data-*.yaml fixture turns on one or more otherwise-unreached
# template branches (a toggle default, or a mutually-exclusive value like
# shell.ssh.agent's variants) — iterate instead of hardcoding one filename, so
# a new fixture is picked up automatically.
for fixture in .github/fixtures/ci-data-*.yaml; do
  [[ -e "${fixture}" ]] || continue
  run "chezmoi apply --dry-run ($(basename "${fixture}" .yaml))" dry_run --override-data-file "${fixture}"
done

echo "==> .chezmoi.toml.tmpl branches only \`chezmoi init\` itself renders"
run "chezmoi init (secrets.profile=work)" init_variant work '[data.secrets]
    profile = "work"'
run "chezmoi init (secrets.profile=custom)" init_variant custom '[data.secrets]
    profile = "custom"'
run "chezmoi init (secrets.profile=none)" init_variant none '[data.secrets]
    profile = "none"'
run "chezmoi init (ssh.agent=gpg, quake_key=none, git.format=openpgp)" init_variant alt '[data.shell.ssh]
    agent = "gpg"

[data.kitty]
    quake_key = "none"

[data.git]
    format = "openpgp"'

echo "==> Real apply (scratch destination)"
run "chezmoi apply (real, scratch destination)" apply_real
run "chezmoi apply is idempotent (empty diff on 2nd apply)" apply_idempotent
run "chezmoi verify (scratch destination matches target state)" verify_destination

echo "==> PowerShell"
if have pwsh; then
  run "rendered PowerShell templates parse" parse_rendered_powershell
  # shellcheck disable=SC2016 # `$e` etc. is PowerShell, not bash
  run "bootstrap.ps1 parses" pwsh -NoProfile -Command '
    $e = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "bootstrap.ps1"), [ref]$null, [ref]$e) | Out-Null
    if ($e) { $e | ForEach-Object { Write-Host $_ }; exit 1 }'
  if pwsh -NoProfile -Command 'if (Get-Module -ListAvailable PSScriptAnalyzer) { exit 0 } else { exit 1 }'; then
    run "PSScriptAnalyzer (gated rules)" pwsh -NoProfile -File .github/scripts/analyze-powershell.ps1
  else
    skip "PSScriptAnalyzer" "module not installed"
  fi
else
  skip "PowerShell checks" "pwsh not installed"
fi

echo "==> Pinned checksums"
if (( OFFLINE )); then skip "pins.py verify" "--offline"; else run "pins.py verify (re-downloads artifacts)" python3 .github/scripts/pins.py verify; fi

echo
printf '%d passed, %d failed, %d skipped\n' "${PASS}" "${FAIL}" "${SKIP}"
if (( ${#FAILED[@]} > 0 )); then
  echo "FAILED: ${FAILED[*]}"
  exit 1
fi
