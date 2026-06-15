#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
package_file="${repo_root}/dot_config/yazi/package.toml.tmpl"

if ! command -v ya >/dev/null 2>&1; then
  echo "ya is required to refresh Yazi package hashes" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to validate Yazi package revisions" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

mkdir -p "${tmp_dir}/config/yazi" "${tmp_dir}/home" "${tmp_dir}/cache" "${tmp_dir}/data"
cp "${package_file}" "${tmp_dir}/config/yazi/package.toml"

rev_fix_file="${tmp_dir}/rev-fixes.tsv"
touch "${rev_fix_file}"

# Ensure each configured revision still exists upstream. If a commit was
# force-pushed away, pin to current HEAD so hash refresh can continue.
while IFS=$'\t' read -r dep rev; do
  [[ -n "${dep}" && -n "${rev}" ]] || continue

  remote="https://github.com/${dep}.git"
  if git ls-remote "${remote}" | awk '{print $1}' | grep -qi "^${rev}"; then
    continue
  fi

  new_rev="$(git ls-remote "${remote}" HEAD | awk 'NR == 1 { print $1 }')"
  if [[ -z "${new_rev}" ]]; then
    echo "Failed to resolve fallback revision for ${dep}" >&2
    exit 1
  fi

  echo "Revision ${rev} for ${dep} is unreachable; falling back to ${new_rev}" >&2
  printf '%s\t%s\t%s\n' "${dep}" "${rev}" "${new_rev}" >> "${rev_fix_file}"
done < <(
  awk '
    /^\[\[(plugin|flavor)\.deps\]\]/ {
      dep = ""
      rev = ""
      next
    }
    /^use[[:space:]]*=/ {
      if (match($0, /"[^"]+"/)) {
        val = substr($0, RSTART + 1, RLENGTH - 2)
        split(val, parts, ":")
        dep = parts[1]
      }
      next
    }
    /^rev[[:space:]]*=/ {
      if (dep != "" && match($0, /"[0-9a-fA-F]+"/)) {
        rev = substr($0, RSTART + 1, RLENGTH - 2)
        print dep "\t" rev
      }
      next
    }
  ' "${tmp_dir}/config/yazi/package.toml"
)

if [[ -s "${rev_fix_file}" ]]; then
  awk -F '\t' '
    FNR == NR {
      key = $1 SUBSEP $2
      fix[key] = $3
      next
    }
    /^\[\[(plugin|flavor)\.deps\]\]/ {
      dep = ""
      print
      next
    }
    /^use[[:space:]]*=/ {
      if (match($0, /"[^"]+"/)) {
        val = substr($0, RSTART + 1, RLENGTH - 2)
        split(val, parts, ":")
        dep = parts[1]
      }
      print
      next
    }
    /^rev[[:space:]]*=/ {
      if (dep != "" && match($0, /"[0-9a-fA-F]+"/)) {
        old = substr($0, RSTART + 1, RLENGTH - 2)
        key = dep SUBSEP old
        if (key in fix) {
          sub(/"[0-9a-fA-F]+"/, "\"" fix[key] "\"")
        }
      }
      print
      next
    }
    {
      print
    }
  ' "${rev_fix_file}" "${tmp_dir}/config/yazi/package.toml" > "${tmp_dir}/config/yazi/package.toml.new"
  mv "${tmp_dir}/config/yazi/package.toml.new" "${tmp_dir}/config/yazi/package.toml"
fi

attempt=1
max_attempts=3
while true; do
  if env \
    HOME="${tmp_dir}/home" \
    XDG_CACHE_HOME="${tmp_dir}/cache" \
    XDG_CONFIG_HOME="${tmp_dir}/config" \
    XDG_DATA_HOME="${tmp_dir}/data" \
    ya pkg install --discard >/dev/null; then
    break
  fi

  if (( attempt >= max_attempts )); then
    echo "Failed to refresh Yazi package hashes after ${attempt} attempts" >&2
    exit 1
  fi

  echo "Retrying Yazi package refresh (attempt $((attempt + 1))/${max_attempts})" >&2
  rm -rf "${tmp_dir}/cache/yazi"
  attempt=$((attempt + 1))
done

cp "${tmp_dir}/config/yazi/package.toml" "${package_file}"
