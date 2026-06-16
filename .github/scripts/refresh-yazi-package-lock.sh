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

# Ensure each configured revision can actually be fetched and checked out.
# If a commit or tree is no longer usable upstream, pin to current HEAD so
# hash refresh can continue.
while IFS=$'\t' read -r dep rev; do
  [[ -n "${dep}" && -n "${rev}" ]] || continue

  remote="https://github.com/${dep}.git"
  head_rev="$(git ls-remote "${remote}" HEAD | awk 'NR == 1 { print $1 }')"
  if [[ -z "${head_rev}" ]]; then
    echo "Failed to resolve HEAD revision for ${dep}" >&2
    exit 1
  fi

  validate_revision() {
    local candidate="$1"
    local repo_dir checkout_output

    repo_dir="${tmp_dir}/validate-${dep//\//-}-${candidate:0:12}"
    rm -rf "${repo_dir}"
    mkdir -p "${repo_dir}"

    if ! checkout_output="$({
      git -C "${repo_dir}" init -q
      git -C "${repo_dir}" remote add origin "${remote}"
      git -C "${repo_dir}" fetch -q --depth 1 origin "${candidate}"
      git -C "${repo_dir}" checkout -q --detach FETCH_HEAD
    } 2>&1)"; then
      printf '%s\n' "${checkout_output}" >&2
      return 1
    fi

    return 0
  }

  if validate_revision "${rev}"; then
    continue
  fi

  if ! validate_revision "${head_rev}"; then
    echo "Failed to validate either ${rev} or HEAD for ${dep}" >&2
    exit 1
  fi

  echo "Revision ${rev} for ${dep} cannot be checked out; falling back to ${head_rev}" >&2
  printf '%s\t%s\t%s\n' "${dep}" "${rev}" "${head_rev}" >> "${rev_fix_file}"
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
