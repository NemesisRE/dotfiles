#!/usr/bin/env bash
#
# Render every chezmoi template that produces shell code, then lint the RENDERED
# output. Templates cannot be fed to shellcheck directly (the `{{ }}` delimiters
# are not valid shell), and shellcheck cannot parse zsh at all — so without this
# step the rc files, the function bundles and every .chezmoiscripts/*.sh.tmpl get
# zero static analysis.
#
# Usage: .github/scripts/lint-rendered.sh [chezmoi-config-path]

set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

CONFIG_ARGS=()
if [[ -n "${1:-}" ]]; then
  CONFIG_ARGS=(--config "$1")
fi

OUT_DIR="$(mktemp -d)"
trap 'rm -rf "${OUT_DIR}"' EXIT

fail=0
rendered=0

render() {
  # render <source-template> <output-file>
  if ! chezmoi execute-template --source=. "${CONFIG_ARGS[@]}" -f "$1" </dev/null >"$2" 2>"${OUT_DIR}/err"; then
    echo "::error file=$1::template failed to render"
    sed 's/^/    /' "${OUT_DIR}/err"
    fail=1
    return 1
  fi
  return 0
}

check_bash() {
  # check_bash <label> <file>
  local label="$1" file="$2"
  [[ -s "${file}" ]] || return 0   # OS-gated to empty on this platform
  rendered=$((rendered + 1))
  if ! bash -n "${file}" 2>"${OUT_DIR}/err"; then
    echo "::error file=${label}::bash syntax error"
    sed 's/^/    /' "${OUT_DIR}/err"; fail=1; return
  fi
  # SC2317/SC2329 are the same false positive under two codes ("function/command
  # never invoked"): shellcheck 0.9/0.10 reports it as SC2317, 0.11+ as SC2329.
  # These files are sourced libraries, so their functions are called from elsewhere.
  if ! shellcheck --shell=bash --severity=style --exclude=SC1090,SC1091,SC2034,SC2317,SC2329 "${file}" >"${OUT_DIR}/sc" 2>&1; then
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
while IFS= read -r src; do
  out="${OUT_DIR}/$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//')"
  render "${src}" "${out}" && check_bash "${src}" "${out}"
done < <(
  printf '%s\n' \
    home/.chezmoiscripts/*.sh.tmpl \
    home/dot_local/share/nredf/shell/common/rc.tmpl \
    home/dot_local/share/nredf/shell/bash/rc.tmpl \
    home/dot_local/share/nredf/shell/common/functions.bundle.tmpl \
    home/dot_local/bin/executable_nredf-daily-sync.tmpl
)

echo "==> Rendering and linting zsh templates"
while IFS= read -r src; do
  out="${OUT_DIR}/$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//')"
  render "${src}" "${out}" && check_zsh "${src}" "${out}"
done < <(
  printf '%s\n' \
    home/dot_local/share/nredf/shell/zsh/rc.tmpl \
    home/dot_local/share/nredf/shell/zsh/functions.bundle.tmpl
)

echo "==> Syntax-checking non-template zsh sources"
for src in home/dot_local/share/nredf/shell/zsh/functions/*.zsh; do
  [[ -e "${src}" ]] || continue
  check_zsh "${src}" "${src}"
done

echo "==> Rendering and linting fish templates"
while IFS= read -r src; do
  out="${OUT_DIR}/$(echo "${src}" | tr '/' '_' | sed 's/\.tmpl$//')"
  render "${src}" "${out}" && check_fish "${src}" "${out}"
done < <(
  printf '%s\n' \
    "home/dot_config/fish/config.fish.tmpl" \
    "home/dot_local/share/nredf/shell/fish/rc.tmpl" \
    "home/dot_local/share/nredf/shell/fish/functions.bundle.tmpl"
)

echo "==> Syntax-checking non-template fish sources"
for src in home/dot_local/share/nredf/shell/fish/functions/*.fish home/dot_local/share/nredf/shell/fish/aliases; do
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
# ~/.local/share/nredf/shell/nu/env.nu yet. Work around it the same way this
# was validated by hand during development: render the real homeDir's path,
# then rewrite that prefix to a scratch "home" this script populates with
# the same tree a real `chezmoi apply` would produce, and check that instead.
REAL_HOME="$(chezmoi execute-template --source=. "${CONFIG_ARGS[@]}" '{{ .chezmoi.homeDir }}' </dev/null)"
NU_HOME="${OUT_DIR}/nu_home"
mkdir -p \
  "${NU_HOME}/.local/share/nredf/shell/nu" \
  "${NU_HOME}/.cache/nredf/init" \
  "${NU_HOME}/.config/nu"
for f in atuin zoxide mise omp carapace fzf; do
  : >"${NU_HOME}/.cache/nredf/init/${f}.nu"
done
: >"${NU_HOME}/.config/nu/env.local.nu"
: >"${NU_HOME}/.config/nu/config.local.nu"

render_nu_into_scratch_home() {
  # render_nu_into_scratch_home <source-template> <scratch-relative-target>
  local raw
  raw="${OUT_DIR}/raw_$(basename "$2")"
  render "$1" "${raw}" || return 1
  sed "s#${REAL_HOME}#${NU_HOME}#g" "${raw}" >"${NU_HOME}/$2"
}

render_nu_into_scratch_home "home/dot_local/share/nredf/shell/nu/functions.bundle.tmpl" ".local/share/nredf/shell/nu/functions.bundle"
if [[ -e "home/dot_local/share/nredf/shell/nu/aliases.nu.tmpl" ]]; then
  render_nu_into_scratch_home "home/dot_local/share/nredf/shell/nu/aliases.nu.tmpl" ".local/share/nredf/shell/nu/aliases.nu"
  check_nu "home/dot_local/share/nredf/shell/nu/aliases.nu.tmpl" "${NU_HOME}/.local/share/nredf/shell/nu/aliases.nu"
elif [[ -e "home/dot_local/share/nredf/shell/nu/aliases.nu" ]]; then
  cp "home/dot_local/share/nredf/shell/nu/aliases.nu" "${NU_HOME}/.local/share/nredf/shell/nu/aliases.nu"
fi
render_nu_into_scratch_home "home/dot_local/share/nredf/shell/nu/env.nu.tmpl" ".local/share/nredf/shell/nu/env.nu"
check_nu "home/dot_local/share/nredf/shell/nu/env.nu.tmpl" "${NU_HOME}/.local/share/nredf/shell/nu/env.nu"
render_nu_into_scratch_home "home/dot_local/share/nredf/shell/nu/config.nu.tmpl" ".local/share/nredf/shell/nu/config.nu"
check_nu "home/dot_local/share/nredf/shell/nu/config.nu.tmpl" "${NU_HOME}/.local/share/nredf/shell/nu/config.nu"

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
for src in home/dot_local/share/nredf/shell/nu/functions/*.nu; do
  [[ -e "${src}" ]] || continue
  check_nu "${src}" "${src}"
done

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
