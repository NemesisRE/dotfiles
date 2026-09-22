#!/usr/bin/env bash
#
# Run locally what CI runs, so a change can be verified before it is pushed.
#
#   .github/scripts/check.sh             everything
#   .github/scripts/check.sh --offline   skip checks that download (pins.py verify)
#
# Each check prints PASS / FAIL / SKIP (SKIP = the tool is not installed). Exits
# non-zero if any check FAILS. Nothing here writes to your real HOME or chezmoi
# state: chezmoi runs against a scratch config and destination, with CI=1 so the
# secret templates never reach a vault. Compatible with bash 3.2 (macOS).

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
  if have markdownlint-cli2; then markdownlint-cli2 --config .markdownlint.yaml "**/*.md"
  elif have bunx; then bunx markdownlint-cli2 --config .markdownlint.yaml "**/*.md"
  else npx --yes markdownlint-cli2 --config .markdownlint.yaml "**/*.md"; fi
}
shellcheck_plain() { # the gate CI's ShellCheck job applies (warning severity)
  { find home/dot_local/share/nredf/shell -type f \( -name '*.bash' -o -name '*.sh' \)
    ls bootstrap.sh .github/scripts/*.sh; } | xargs shellcheck -S warning
}
dry_run() { # dry_run [extra chezmoi args...]
  CI=1 NREDF_NO_BOOTSTRAP=1 chezmoi apply --dry-run --force --source="${ROOT}" \
    --config "${TMP}/chezmoi.toml" --destination "${TMP}/home" "$@"
}
parse_windows_scripts() {
  # --dry-run renders scripts but never parses them, so a PowerShell syntax error
  # would ship. Render each Windows script (forcing the OS test, so this works on any
  # host) with every optional toggle on, then parse it.
  local f n=0
  for f in home/.chezmoiscripts/*.ps1.tmpl; do
    sed 's/\.chezmoi\.os "windows"/"windows" "windows"/' "${f}" >"${TMP}/w.tmpl"
    chezmoi execute-template --source="${ROOT}" --config "${TMP}/chezmoi.toml" \
      --override-data-file .github/fixtures/ci-data-full.yaml -f "${TMP}/w.tmpl" \
      </dev/null >"${TMP}/w.ps1" || { echo "render failed: ${f}"; return 1; }
    [[ -s "${TMP}/w.ps1" ]] || continue
    # shellcheck disable=SC2016 # `$e` etc. is PowerShell, not bash
    PS_FILE="${TMP}/w.ps1" pwsh -NoProfile -Command '
      $e = $null
      [System.Management.Automation.Language.Parser]::ParseFile($env:PS_FILE, [ref]$null, [ref]$e) | Out-Null
      if ($e) { $e | ForEach-Object { Write-Host $_ }; exit 1 }' || { echo "parse error: ${f}"; return 1; }
    n=$((n + 1))
  done
  echo "parsed ${n} rendered Windows scripts"
}

echo "==> Setup"
if ! chezmoi init --source="${ROOT}" --config-path "${TMP}/chezmoi.toml" --promptDefaults --no-tty \
  </dev/null >"${TMP}/init.out" 2>&1; then
  echo "  FAIL  chezmoi init (renders .chezmoi.toml.tmpl)"
  sed 's/^/        /' "${TMP}/init.out" | tail -15
  exit 1
fi
echo "  PASS  chezmoi init (renders .chezmoi.toml.tmpl)"
PASS=$((PASS + 1))

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

echo "==> Templates and behaviour"
run "secret-template tests (stub bw)" python3 .github/scripts/test-secret-templates.py
run "chezmoi apply --dry-run (default data)" dry_run
run "chezmoi apply --dry-run (every optional path on)" dry_run --override-data-file .github/fixtures/ci-data-full.yaml

echo "==> PowerShell"
if have pwsh; then
  run "rendered Windows scripts parse" parse_windows_scripts
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
