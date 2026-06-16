#!/usr/bin/env bash
# Refreshes Yazi package rev+hash entries after Renovate bumps revisions.
# Uses `ya pkg upgrade --discard` which clones each repo to HEAD, deploys
# from the extracted working tree, and writes back both rev and hash — the
# same flow used when updating packages locally.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
package_file="${repo_root}/dot_config/yazi/package.toml.tmpl"

if ! command -v ya >/dev/null 2>&1; then
  echo "ya is required to refresh Yazi package lock" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'chmod -R +w "${tmp_dir}" 2>/dev/null || true; rm -rf "${tmp_dir}"' EXIT

mkdir -p "${tmp_dir}/config/yazi" "${tmp_dir}/home" "${tmp_dir}/cache" "${tmp_dir}/data"
cp "${package_file}" "${tmp_dir}/config/yazi/package.toml"

env \
  HOME="${tmp_dir}/home" \
  XDG_CACHE_HOME="${tmp_dir}/cache" \
  XDG_CONFIG_HOME="${tmp_dir}/config" \
  XDG_DATA_HOME="${tmp_dir}/data" \
  ya pkg upgrade --discard

cp "${tmp_dir}/config/yazi/package.toml" "${package_file}"
