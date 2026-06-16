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
# chmod before rm so read-only git object files don't block cleanup
trap 'chmod -R +w "${tmp_dir}" 2>/dev/null || true; rm -rf "${tmp_dir}"' EXIT

mkdir -p "${tmp_dir}/config/yazi" "${tmp_dir}/home" "${tmp_dir}/cache" "${tmp_dir}/data"
cp "${package_file}" "${tmp_dir}/config/yazi/package.toml"

rev_fix_file="${tmp_dir}/rev-fixes.tsv"
touch "${rev_fix_file}"

# Validate a revision by replicating exactly what ya pkg install does:
#   git clone --depth 1 <remote>  →  git checkout <rev>
# Using "git init + fetch" is NOT equivalent: the tree for the rev may be
# served by the fetch but silently absent when yazi clones and then tries
# to checkout a historical commit.  Only a real clone+checkout reveals the
# "unable to read tree" failure seen in CI.
validate_clone() {
  local remote="$1" candidate="$2" clone_dir="$3"
  chmod -R +w "${clone_dir}" 2>/dev/null || true
  rm -rf "${clone_dir}" 2>/dev/null || true

  # Step 1 – clone shallowly (mirrors yazi's Git::clone)
  git clone -q --depth 1 "${remote}" "${clone_dir}" 2>/dev/null || return 1

  # Step 2 – checkout the specific rev (mirrors yazi's Git::checkout)
  # If the rev is not in the shallow history, fetch it first.
  if ! git -C "${clone_dir}" checkout -q --detach "${candidate}" 2>/dev/null; then
    git -C "${clone_dir}" fetch -q --depth 1 origin "${candidate}" 2>/dev/null || return 1
    git -C "${clone_dir}" checkout -q --detach FETCH_HEAD 2>/dev/null || return 1
  fi
}

# Collect unique dep+rev pairs to avoid redundant network round-trips
# (yazi-rs/plugins appears once per plugin, all with the same rev).
declare -A _seen_pairs

while IFS=$'\t' read -r dep rev; do
  [[ -n "${dep}" && -n "${rev}" ]] || continue

  pair_key="${dep}	${rev}"
  [[ "${_seen_pairs[${pair_key}]+_}" ]] && continue
  _seen_pairs["${pair_key}"]=1

  remote="https://github.com/${dep}.git"
  clone_dir="${tmp_dir}/validate-${dep//\//-}-${rev:0:12}"

  if validate_clone "${remote}" "${rev}" "${clone_dir}"; then
    continue
  fi

  head_rev="$(git ls-remote "${remote}" HEAD | awk 'NR == 1 { print $1 }')"
  if [[ -z "${head_rev}" ]]; then
    echo "Failed to resolve HEAD for ${dep}" >&2
    exit 1
  fi

  head_clone_dir="${tmp_dir}/validate-${dep//\//-}-HEAD"
  if ! validate_clone "${remote}" "${head_rev}" "${head_clone_dir}"; then
    echo "Failed to validate HEAD for ${dep} — skipping" >&2
    continue
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
