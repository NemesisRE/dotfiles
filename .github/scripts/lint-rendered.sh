#!/usr/bin/env bash
#
# Render every chezmoi template that produces shell code or structured config,
# then lint/parse the RENDERED output. Templates cannot be fed to a linter
# directly (the `{{ }}` delimiters are not valid shell/YAML/JSON/TOML), and zsh
# cannot be parsed by shellcheck at all — so without this step the rc files,
# the function bundles, every .chezmoiscripts/*.sh.tmpl and every rendered
# yaml/json/toml config get zero static analysis.
#
# Usage: .github/scripts/lint-rendered.sh [chezmoi-config-path]
#
# Compatible with bash 3.2 (macOS's system bash, which `#!/usr/bin/env bash`
# may resolve to even when this is invoked from check.sh).

set -euo pipefail

# check.sh's header promises "the secret templates never reach a vault"
# (CI=1 makes get-github-token.tmpl/get-signing-key.tmpl/get-mcp-servers.tmpl
# short-circuit before calling bitwarden/keepassxc/1password). GitHub Actions
# sets CI=true for every step automatically, which is what has hidden this so
# far, but nothing here set it for a developer running check.sh (or this
# script directly) on their own machine — if their `secrets.*` config happens
# to resolve to a real vault item, rendering home/.chezmoiscripts/*_claude_mcp*
# below would make a REAL vault call. Force both, the same way dry_run() in
# check.sh does for chezmoi apply.
export CI="${CI:-1}"
export NREDF_NO_BOOTSTRAP="${NREDF_NO_BOOTSTRAP:-1}"

have() { command -v "$1" >/dev/null 2>&1; }

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

CONFIG_ARGS=()
if [[ -n "${1:-}" ]]; then
  CONFIG_ARGS=(--config "$1")
fi
FULL_DATA_ARGS=(--override-data-file "${REPO_ROOT}/.github/fixtures/ci-data-full.yaml")

OUT_DIR="$(mktemp -d)"
trap 'rm -rf "${OUT_DIR}"' EXIT

fail=0
rendered=0

render() {
  # render <source-template> <output-file> [extra chezmoi execute-template args...]
  local src="$1" out="$2"
  shift 2
  if ! chezmoi execute-template --source=. "${CONFIG_ARGS[@]}" "$@" -f "${src}" </dev/null >"${out}" 2>"${OUT_DIR}/err"; then
    echo "::error file=${src}::template failed to render"
    sed 's/^/    /' "${OUT_DIR}/err"
    fail=1
    return 1
  fi
  return 0
}

# A hard-coded (non-glob) source path that has gone missing — e.g. renamed to
# add a .tmpl extension — must fail loudly. A real glob (functions/*.fish) is
# allowed to expand to zero matches; only call this on explicit filenames.
require_paths() {
  local p
  for p in "$@"; do
    if [[ ! -e "${p}" ]]; then
      echo "::error file=${p}::required source file is missing (renamed or removed?)"
      fail=1
    fi
  done
}

check_bash() {
  # check_bash <label> <file> [extra shellcheck --exclude codes, comma-separated]
  local label="$1" file="$2" extra_exclude="${3:-}"
  [[ -s "${file}" ]] || return 0   # OS-gated to empty on this platform
  rendered=$((rendered + 1))
  if ! bash -n "${file}" 2>"${OUT_DIR}/err"; then
    echo "::error file=${label}::bash syntax error"
    sed 's/^/    /' "${OUT_DIR}/err"; fail=1; return
  fi
  # SC2317/SC2329 are the same false positive under two codes ("function/command
  # never invoked"): shellcheck 0.9/0.10 reports it as SC2317, 0.11+ as SC2329.
  # These files are sourced libraries, so their functions are called from elsewhere.
  local exclude="SC1090,SC1091,SC2034,SC2317,SC2329"
  [[ -n "${extra_exclude}" ]] && exclude="${exclude},${extra_exclude}"
  if ! shellcheck --shell=bash --severity=style --exclude="${exclude}" "${file}" >"${OUT_DIR}/sc" 2>&1; then
    echo "::error file=${label}::shellcheck"
    sed "s|${file}|${label}|g; s/^/    /" "${OUT_DIR}/sc"; fail=1
  fi
}

check_zsh() {
  # check_zsh <label> <file>
  local label="$1" file="$2"
  [[ -s "${file}" ]] || return 0
  rendered=$((rendered + 1))
  if ! zsh -n "${file}" 2>"${OUT_DIR}/err"; then
    echo "::error file=${label}::zsh syntax error"
    sed 's/^/    /' "${OUT_DIR}/err"; fail=1
  fi
}

check_fish() {
  # check_fish <label> <file>
  local label="$1" file="$2"
  have fish || return 0
  [[ -s "${file}" ]] || return 0   # OS-gated to empty on this platform
  rendered=$((rendered + 1))
  if ! fish --no-execute "${file}" 2>"${OUT_DIR}/err"; then
    echo "::error file=${label}::fish syntax error"
    sed 's/^/    /' "${OUT_DIR}/err"; fail=1
  fi
}

check_nu() {
  # check_nu <label> <file> — `nu-check` alone always exits 0 and just
  # prints true/false; `--debug` is what actually gives a real 0/1 exit
  # code (verified empirically), which `run()`/this function's exit-code
  # check both depend on.
  local label="$1" file="$2"
  have nu || return 0
  [[ -s "${file}" ]] || return 0   # OS-gated to empty on this platform
  rendered=$((rendered + 1))
  if ! nu -c "nu-check --debug '${file}'" >"${OUT_DIR}/err" 2>&1; then
    echo "::error file=${label}::nu syntax error"
    sed 's/^/    /' "${OUT_DIR}/err"; fail=1
  fi
}

echo "==> Rendering and linting bash templates"
# Listed once — require_paths (must exist) and the render loop (must be
# checked) both walk this same list, instead of the two hand-maintained
# copies drifting apart the way AGENTS.md warns a hand-maintained include
# list always eventually does.
BASH_TEMPLATES="
home/dot_local/share/nredf/shell/common/rc.tmpl
home/dot_local/share/nredf/shell/bash/rc.tmpl
home/dot_local/share/nredf/shell/common/functions.bundle.tmpl
home/dot_local/bin/executable_nredf-daily-sync.tmpl
home/dot_local/share/nredf/shell/common/aliases.tmpl
home/dot_bashrc.tmpl
home/dot_bash_profile.tmpl
home/dot_blerc.tmpl
"
# shellcheck disable=SC2086 # intentional word-splitting: newline-separated paths, none contain spaces
require_paths ${BASH_TEMPLATES}
while IFS= read -r src; do
  [[ -n "${src}" ]] || continue
  # dot_blerc.tmpl is ble.sh's own config DSL, not a normal bash script:
  # `_ble_bash` is set by ble.sh itself before this is sourced (SC2154), and
  # its single-quoted `ble-bind` action strings are ble.sh's documented
  # syntax, not an accidental missing-expansion bug (SC2016).
  extra=""
  [[ "${src}" == "home/dot_blerc.tmpl" ]] && extra="SC2154,SC2016"
  out="${OUT_DIR}/$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//')"
  render "${src}" "${out}" && check_bash "${src}" "${out}" "${extra}"
  # Every optional toggle defaults to false/absent, so also render with every
  # optional path turned on — otherwise those branches never get parsed.
  out_full="${out}.full"
  render "${src}" "${out_full}" "${FULL_DATA_ARGS[@]}" && check_bash "${src} (ci-data-full)" "${out_full}" "${extra}"
done <<<"${BASH_TEMPLATES}"

echo "==> Rendering and linting zsh templates"
ZSH_TEMPLATES="
home/dot_local/share/nredf/shell/zsh/rc.tmpl
home/dot_local/share/nredf/shell/zsh/functions.bundle.tmpl
home/dot_local/share/nredf/shell/common/aliases.tmpl
home/dot_zshrc.tmpl
home/dot_zprofile.tmpl
home/dot_zshenv.tmpl
"
# shellcheck disable=SC2086 # intentional word-splitting: newline-separated paths, none contain spaces
require_paths ${ZSH_TEMPLATES}
while IFS= read -r src; do
  [[ -n "${src}" ]] || continue
  out="${OUT_DIR}/zsh_$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//')"
  render "${src}" "${out}" && check_zsh "${src}" "${out}"
  out_full="${out}.full"
  render "${src}" "${out_full}" "${FULL_DATA_ARGS[@]}" && check_zsh "${src} (ci-data-full)" "${out_full}"
done <<<"${ZSH_TEMPLATES}"

echo "==> Syntax-checking non-template zsh sources"
for src in home/dot_local/share/nredf/shell/zsh/functions/*.zsh; do
  [[ -e "${src}" ]] || continue
  check_zsh "${src}" "${src}"
done

echo "==> Rendering and linting fish templates"
FISH_TEMPLATES="
home/dot_config/fish/config.fish.tmpl
home/dot_local/share/nredf/shell/fish/rc.tmpl
home/dot_local/share/nredf/shell/fish/functions.bundle.tmpl
home/dot_local/share/nredf/shell/fish/aliases.tmpl
"
# shellcheck disable=SC2086 # intentional word-splitting: newline-separated paths, none contain spaces
require_paths ${FISH_TEMPLATES}
while IFS= read -r src; do
  [[ -n "${src}" ]] || continue
  out="${OUT_DIR}/$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//')"
  render "${src}" "${out}" && check_fish "${src}" "${out}"
  out_full="${out}.full"
  render "${src}" "${out_full}" "${FULL_DATA_ARGS[@]}" && check_fish "${src} (ci-data-full)" "${out_full}"
done <<<"${FISH_TEMPLATES}"

echo "==> Syntax-checking non-template fish sources"
for src in home/dot_local/share/nredf/shell/fish/functions/*.fish; do
  [[ -e "${src}" ]] || continue
  check_fish "${src}" "${src}"
done

echo "==> Rendering and linting nu templates"
# nu's env.nu.tmpl/config.nu.tmpl and the three per-OS stub pairs all
# `source` each other (and the cache/local-override placeholders) by a
# literal path baked in at chezmoi-render time via .chezmoi.homeDir — and
# .chezmoi.homeDir always resolves to the *real* home directory regardless
# of any --destination override (verified: it is not a "safe to redirect"
# field the way apply's destination is). nu's `source` needs that path to
# exist on disk before the file is even parsed, so none of these can be
# nu-checked as rendered — a fresh checkout's real home won't have
# ~/.local/share/nredf/shell/nushell/env.nu yet. Work around it the same way this
# was validated by hand during development: render the real homeDir's path,
# then rewrite that prefix to a scratch "home" this script populates with
# the same tree a real `chezmoi apply` would produce, and check that instead.
REAL_HOME="$(chezmoi execute-template --source=. "${CONFIG_ARGS[@]}" '{{ .chezmoi.homeDir }}' </dev/null)"
NU_HOME="${OUT_DIR}/nu_home"
mkdir -p \
  "${NU_HOME}/.local/share/nredf/shell/nushell" \
  "${NU_HOME}/.cache/nredf/init" \
  "${NU_HOME}/.config/nushell"
# atuin/zoxide/mise/carapace/fzf each write a cached init snippet here that
# config.nu.tmpl sources; oh-my-posh is NOT one of them — it has no nu init
# script to cache at all (confirmed empirically: its stdout/stderr are both
# genuinely empty on success), it writes straight into nu's own
# vendor-autoload directory instead, which nu sources on its own. Keep this
# list in sync with the tools config.nu.tmpl actually sources from
# $XDG_CACHE_HOME/nredf/init/*.nu.
for f in atuin zoxide mise carapace fzf; do
  : >"${NU_HOME}/.cache/nredf/init/${f}.nu"
done
: >"${NU_HOME}/.config/nushell/env.local.nu"
: >"${NU_HOME}/.config/nushell/config.local.nu"

render_nu_into_scratch_home() {
  # render_nu_into_scratch_home <source-template> <scratch-relative-target>
  local raw
  raw="${OUT_DIR}/raw_$(basename "$2")"
  render "$1" "${raw}" || return 1
  sed "s#${REAL_HOME}#${NU_HOME}#g" "${raw}" >"${NU_HOME}/$2"
}

require_paths \
  "home/dot_local/share/nredf/shell/nushell/functions.bundle.tmpl" \
  "home/dot_local/share/nredf/shell/nushell/env.nu.tmpl" \
  "home/dot_local/share/nredf/shell/nushell/config.nu.tmpl"

render_nu_into_scratch_home "home/dot_local/share/nredf/shell/nushell/functions.bundle.tmpl" ".local/share/nredf/shell/nushell/functions.bundle"
if [[ -e "home/dot_local/share/nredf/shell/nushell/aliases.nu.tmpl" ]]; then
  render_nu_into_scratch_home "home/dot_local/share/nredf/shell/nushell/aliases.nu.tmpl" ".local/share/nredf/shell/nushell/aliases.nu"
  check_nu "home/dot_local/share/nredf/shell/nushell/aliases.nu.tmpl" "${NU_HOME}/.local/share/nredf/shell/nushell/aliases.nu"
elif [[ -e "home/dot_local/share/nredf/shell/nushell/aliases.nu" ]]; then
  cp "home/dot_local/share/nredf/shell/nushell/aliases.nu" "${NU_HOME}/.local/share/nredf/shell/nushell/aliases.nu"
fi
render_nu_into_scratch_home "home/dot_local/share/nredf/shell/nushell/env.nu.tmpl" ".local/share/nredf/shell/nushell/env.nu"
check_nu "home/dot_local/share/nredf/shell/nushell/env.nu.tmpl" "${NU_HOME}/.local/share/nredf/shell/nushell/env.nu"
render_nu_into_scratch_home "home/dot_local/share/nredf/shell/nushell/config.nu.tmpl" ".local/share/nredf/shell/nushell/config.nu"
check_nu "home/dot_local/share/nredf/shell/nushell/config.nu.tmpl" "${NU_HOME}/.local/share/nredf/shell/nushell/config.nu"

while IFS= read -r src; do
  out="${OUT_DIR}/raw_$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//')"
  render "${src}" "${out}" || continue
  subst="${OUT_DIR}/$(basename "${out}")"
  sed "s#${REAL_HOME}#${NU_HOME}#g" "${out}" >"${subst}"
  check_nu "${src}" "${subst}"
done < <(
  printf '%s\n' \
    "home/dot_config/nushell/env.nu.tmpl" \
    "home/dot_config/nushell/config.nu.tmpl" \
    "home/private_Library/private_Application Support/nushell/env.nu.tmpl" \
    "home/private_Library/private_Application Support/nushell/config.nu.tmpl" \
    "home/AppData/Roaming/nushell/env.nu.tmpl" \
    "home/AppData/Roaming/nushell/config.nu.tmpl"
)

echo "==> Syntax-checking non-template nu sources"
for src in home/dot_local/share/nredf/shell/nushell/functions/*.nu; do
  [[ -e "${src}" ]] || continue
  check_nu "${src}" "${src}"
done

echo "==> Rendering and shellchecking OS-gated hooks on every applicable OS"
# The CI job that runs this script only runs on ubuntu-latest, so a hook
# gated `eq .chezmoi.os "darwin"` (or "linux") renders empty here and gets
# zero coverage on whichever branch isn't the host OS. Force each OS branch
# the same way check.sh's parse_rendered_powershell forces the Windows
# branch for PowerShell hooks: rewrite the OS comparison's left-hand side to
# a literal before rendering, once per candidate OS.
#
# Limitation: this textually matches `.chezmoi.os "..."` — a hook written as
# `{{ $os := .chezmoi.os }}` and later `eq $os "darwin"` would silently render
# against the real host OS instead of the forced one. No script here does
# that today (all use the inline form directly); if one starts to, extend the
# sed to cover the indirection too.
force_os_and_check() {
  # force_os_and_check <target-os> <source-template>
  local target="$1" src="$2"
  local step1 forced out
  step1="${OUT_DIR}/forced_step1_$(basename "${src}")"
  forced="${OUT_DIR}/forced_$(basename "${src}")"
  sed "s/\\.chezmoi\\.os \"/\"${target}\" \"/g" "${src}" >"${step1}"
  if [[ "${target}" == "linux" ]]; then
    # .chezmoi.kernel.osrelease is only populated by chezmoi when actually
    # running on Linux (it comes from uname, not from --override-data-file,
    # so it can't be supplied the normal way) — a Linux-gated hook that reads
    # it (the WSL exclusion check) would otherwise only render successfully
    # when this script itself happens to run on a real Linux host. Substitute
    # a deterministic non-WSL kernel string, the same way .chezmoi.os itself
    # is forced above, so the check works from any host.
    sed 's/\.chezmoi\.kernel\.osrelease/"5.15.0-generic"/g' "${step1}" >"${forced}"
  else
    cp "${step1}" "${forced}"
  fi
  out="${OUT_DIR}/$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//')_${target}"
  render "${forced}" "${out}" && check_bash "${src} (forced ${target})" "${out}"
  # These hooks pulled out of BASH_TEMPLATES above (which renders/checks each
  # template against both default and ci-data-full data) to get the OS-forcing
  # treatment instead — without this second pass they'd lose ci-data-full
  # coverage entirely, e.g. linux_kitty.sh.tmpl's `.kitty.quake_key` branch.
  local out_full="${out}.full"
  render "${forced}" "${out_full}" "${FULL_DATA_ARGS[@]}" && check_bash "${src} (forced ${target}, ci-data-full)" "${out_full}"
}

for src in home/.chezmoiscripts/*.sh.tmpl; do
  [[ -e "${src}" ]] || continue
  force_os_and_check "linux" "${src}"
  force_os_and_check "darwin" "${src}"
done

echo "==> Rendering and linting YAML templates"
# Pre-existing on origin/main, not touched by this change: these rendered
# configs had zero YAML lint coverage before this check existed, so their
# style drift (trailing blank lines, one over-long line, one indent) is
# reported but not failed here rather than sweeping unrelated dotfiles into
# this PR. Fix opportunistically and drop the entry.
yaml_is_allowlisted() {
  local key="${1% (ci-data-full)}"
  case "${key}" in
    home/dot_config/gh/config.yml.tmpl | \
    home/dot_config/glow/glow.yml.tmpl | \
    home/dot_config/k9s/plugins.yaml.tmpl | \
    home/dot_config/lazydocker/config.yml.tmpl | \
    home/dot_config/lazygit/config.yml.tmpl | \
    home/dot_config/lsd/colors.yaml.tmpl | \
    home/dot_config/lsd/config.yaml.tmpl) return 0 ;;
    *) return 1 ;;
  esac
}
lint_yaml() {
  # lint_yaml <label> <file>
  local label="$1" file="$2" cmd status=0
  [[ -s "${file}" ]] || return 0
  rendered=$((rendered + 1))
  if have yamllint; then cmd=(yamllint); else cmd=(uvx yamllint); fi
  "${cmd[@]}" -c "${REPO_ROOT}/.yamllint.yml" "${file}" >"${OUT_DIR}/err" 2>&1 || status=1
  if (( status )); then
    if yaml_is_allowlisted "${label}"; then
      echo "::warning file=${label}::yamllint (pre-existing, allowlisted)"
      sed "s|${file}|${label}|g; s/^/    /" "${OUT_DIR}/err"
    else
      echo "::error file=${label}::yamllint"
      sed "s|${file}|${label}|g; s/^/    /" "${OUT_DIR}/err"; fail=1
    fi
  fi
}
if have yamllint || have uvx; then
  while IFS= read -r src; do
    [[ -e "${src}" ]] || continue
    out="${OUT_DIR}/$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//').yaml"
    render "${src}" "${out}" && lint_yaml "${src}" "${out}"
    out_full="${out}.full"
    render "${src}" "${out_full}" "${FULL_DATA_ARGS[@]}" && lint_yaml "${src} (ci-data-full)" "${out_full}"
  done < <(find home -type f \( -iname '*.yaml.tmpl' -o -iname '*.yml.tmpl' \) | sort)
else
  echo "    (skipped: yamllint/uv not installed)"
fi

echo "==> Rendering and parsing JSON/JSONC templates"
parse_json() {
  # parse_json <label> <file> <strip-comments:0|1>
  local label="$1" file="$2" jsonc="$3"
  [[ -s "${file}" ]] || return 0
  rendered=$((rendered + 1))
  if [[ "${jsonc}" == "1" ]]; then
    if ! python3 -c "
import json, re, sys
text = open(sys.argv[1], encoding='utf-8').read()
# Strip // line comments and /* */ block comments outside of strings — good
# enough for jsonc config files here, none of which contain '//' inside a
# string value.
text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
text = re.sub(r'(?m)^\s*//.*$', '', text)
json.loads(text)
" "${file}" >"${OUT_DIR}/err" 2>&1; then
      echo "::error file=${label}::invalid JSONC"
      sed "s|${file}|${label}|g; s/^/    /" "${OUT_DIR}/err"; fail=1
    fi
  else
    if ! python3 -m json.tool "${file}" >/dev/null 2>"${OUT_DIR}/err"; then
      echo "::error file=${label}::invalid JSON"
      sed "s|${file}|${label}|g; s/^/    /" "${OUT_DIR}/err"; fail=1
    fi
  fi
}
while IFS= read -r src; do
  [[ -e "${src}" ]] || continue
  jsonc=0
  [[ "${src}" == *.jsonc.tmpl ]] && jsonc=1
  out="${OUT_DIR}/$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//').json"
  render "${src}" "${out}" && parse_json "${src}" "${out}" "${jsonc}"
  out_full="${out}.full"
  render "${src}" "${out_full}" "${FULL_DATA_ARGS[@]}" && parse_json "${src} (ci-data-full)" "${out_full}" "${jsonc}"
done < <(find home -type f \( -iname '*.json.tmpl' -o -iname '*.jsonc.tmpl' \) | sort)

echo "==> Rendering and parsing TOML templates"
parse_toml() {
  # parse_toml <label> <file>
  local label="$1" file="$2"
  [[ -s "${file}" ]] || return 0
  rendered=$((rendered + 1))
  if ! python3 -c "
import sys
try:
    import tomllib
except ModuleNotFoundError:
    sys.exit(0)  # python < 3.11: nothing to check with, not a failure
with open(sys.argv[1], 'rb') as f:
    tomllib.load(f)
" "${file}" >"${OUT_DIR}/err" 2>&1; then
    echo "::error file=${label}::invalid TOML"
    sed "s|${file}|${label}|g; s/^/    /" "${OUT_DIR}/err"; fail=1
  fi
}
while IFS= read -r src; do
  [[ -e "${src}" ]] || continue
  # home/.chezmoi.toml.tmpl is not a deployed config: it's the template chezmoi
  # itself renders via `chezmoi init` to produce the config file, and it calls
  # promptStringOnce/promptString — functions that only exist inside `init`'s
  # own template execution, not in a plain `execute-template` render like every
  # other file here. check.sh's "chezmoi init" step already covers it.
  [[ "${src}" == "home/.chezmoi.toml.tmpl" ]] && continue
  out="${OUT_DIR}/$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//').toml"
  render "${src}" "${out}" && parse_toml "${src}" "${out}"
  out_full="${out}.full"
  render "${src}" "${out_full}" "${FULL_DATA_ARGS[@]}" && parse_toml "${src} (ci-data-full)" "${out_full}"
done < <(find home -type f -iname '*.toml.tmpl' | sort)

echo "==> Shellcheck on plain (non-template) shell scripts"
for src in bootstrap.sh .github/scripts/*.sh; do
  [[ -e "${src}" ]] || continue
  rendered=$((rendered + 1))
  if ! shellcheck --severity=style --exclude=SC1090,SC1091 "${src}"; then
    echo "::error file=${src}::shellcheck"
    fail=1
  fi
done

echo
if (( fail )); then
  echo "FAILED — see errors above (${rendered} files checked)"
  exit 1
fi
echo "OK — ${rendered} rendered/plain shell files checked"
