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
  if ! shellcheck --shell=bash --severity=style --exclude=SC1090,SC1091,SC2034,SC2329 "${file}" >"${OUT_DIR}/sc" 2>&1; then
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
