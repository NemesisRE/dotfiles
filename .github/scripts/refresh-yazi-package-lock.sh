#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
package_file="${repo_root}/dot_config/yazi/package.toml.tmpl"

if ! command -v ya >/dev/null 2>&1; then
  echo "ya is required to refresh Yazi package hashes" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

mkdir -p "${tmp_dir}/config/yazi" "${tmp_dir}/home" "${tmp_dir}/cache" "${tmp_dir}/data"
cp "${package_file}" "${tmp_dir}/config/yazi/package.toml"

env \
  HOME="${tmp_dir}/home" \
  XDG_CACHE_HOME="${tmp_dir}/cache" \
  XDG_CONFIG_HOME="${tmp_dir}/config" \
  XDG_DATA_HOME="${tmp_dir}/data" \
  ya pkg install --discard >/dev/null

cp "${tmp_dir}/config/yazi/package.toml" "${package_file}"
