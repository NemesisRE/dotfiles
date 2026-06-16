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
skip_file="${tmp_dir}/skip-deps.txt"
touch "${skip_file}"

# Validate a revision by replicating EXACTLY what ya pkg install does.
# Yazi's Git::clone issues: git clone <url> <path>  (NO --depth flag)
# Yazi's Git::checkout issues: git checkout <rev> --force
#
# Using a shallow clone is NOT equivalent: GitHub's shallow-pack service
# reconstructs packs on demand and can serve tree objects that are missing
# from a full clone (e.g. when a fork's object store is incomplete/GC'd).
# Only a full clone + checkout catches the "unable to read tree" failure.
validate_clone() {
  local remote="$1" candidate="$2" clone_dir="$3"
  chmod -R +w "${clone_dir}" 2>/dev/null || true
  rm -rf "${clone_dir}" 2>/dev/null || true

  # Full clone – matches yazi's Git::clone (no --depth)
  git clone -q "${remote}" "${clone_dir}" 2>/dev/null || return 1

  # Checkout the specific rev – matches yazi's Git::checkout <rev> --force
  git -C "${clone_dir}" checkout -q --detach "${candidate}" 2>/dev/null || return 1
}

# Collect unique dep+rev pairs to avoid redundant network round-trips.
# (yazi-rs/plugins appears once per plugin, all with the same rev)
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
    # Both the pinned rev and HEAD are broken (e.g. corrupt fork object store).
    # Skip this dep during the install run and restore its original entry.
    echo "Repository ${dep} is broken even at HEAD; will skip during hash refresh" >&2
    printf '%s\n' "${dep}" >> "${skip_file}"
    continue
  fi

  echo "Revision ${rev} for ${dep} cannot be checked out; falling back to ${head_rev}" >&2
  printf '%s\t%s\t%s\n' "${dep}" "${rev}" "${head_rev}" >> "${rev_fix_file}"
done < <(
  awk '
    /^\[\[(plugin|flavor)\.deps\]\]/ { dep = ""; rev = ""; next }
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

# Apply rev fixes to the temp package.toml, and strip entries for broken deps.
if [[ -s "${rev_fix_file}" || -s "${skip_file}" ]]; then
  awk '
    function load_fixes(file,    line, parts) {
      while ((getline line < file) > 0) {
        n = split(line, parts, "\t")
        if (n == 3) fix[parts[1] SUBSEP parts[2]] = parts[3]
      }
      close(file)
    }
    function load_skip(file,    line) {
      while ((getline line < file) > 0) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line != "") skip[line] = 1
      }
      close(file)
    }
    BEGIN {
      load_fixes(fixes_file)
      load_skip(skip_file)
      buf = ""; dep = ""
    }
    /^\[\[(plugin|flavor)\.deps\]\]/ {
      if (buf != "") { if (!(dep in skip)) printf "%s\n", buf; buf = "" }
      buf = $0; dep = ""; next
    }
    /^\[flavor\]/ {
      if (buf != "") { if (!(dep in skip)) printf "%s\n", buf; buf = "" }
      print; dep = ""; next
    }
    /^use[[:space:]]*=/ {
      if (match($0, /"[^"]+"/)) {
        val = substr($0, RSTART + 1, RLENGTH - 2)
        n = split(val, parts, ":"); dep = parts[1]
      }
      buf = buf "\n" $0; next
    }
    /^rev[[:space:]]*=/ {
      if (dep != "" && match($0, /"[0-9a-fA-F]+"/)) {
        old = substr($0, RSTART + 1, RLENGTH - 2)
        key = dep SUBSEP old
        if (key in fix) sub(/"[0-9a-fA-F]+"/, "\"" fix[key] "\"")
      }
      buf = buf "\n" $0; next
    }
    { buf = buf "\n" $0; next }
    END { if (buf != "" && !(dep in skip)) printf "%s\n", buf }
  ' fixes_file="${rev_fix_file}" skip_file="${skip_file}" \
    "${tmp_dir}/config/yazi/package.toml" \
    > "${tmp_dir}/config/yazi/package.toml.new"
  mv "${tmp_dir}/config/yazi/package.toml.new" "${tmp_dir}/config/yazi/package.toml"
fi

env \
  HOME="${tmp_dir}/home" \
  XDG_CACHE_HOME="${tmp_dir}/cache" \
  XDG_CONFIG_HOME="${tmp_dir}/config" \
  XDG_DATA_HOME="${tmp_dir}/data" \
  ya pkg install --discard >/dev/null

# Write the refreshed package.toml back.
# For any dep whose repo was entirely broken, restore its original entry unchanged.
if [[ -s "${skip_file}" ]]; then
  python3 - "${tmp_dir}/config/yazi/package.toml" "${package_file}" "${skip_file}" <<'PYEOF'
import sys, re

refreshed_path, original_path, skip_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(skip_path) as f:
    skip_deps = {l.strip() for l in f if l.strip()}

def parse_blocks(text):
    blocks, current, current_dep = [], [], None
    for line in text.splitlines(keepends=True):
        if re.match(r'^\[\[(plugin|flavor)\.deps\]\]', line):
            if current:
                blocks.append((current_dep, ''.join(current)))
            current = [line]; current_dep = None
        elif re.match(r'^\[flavor\]', line):
            if current:
                blocks.append((current_dep, ''.join(current)))
            current = [line]; current_dep = None
        else:
            m = re.match(r'^use\s*=\s*"([^":]+)', line)
            if m:
                current_dep = m.group(1)
            current.append(line)
    if current:
        blocks.append((current_dep, ''.join(current)))
    return blocks

with open(refreshed_path) as f:
    refreshed = f.read()
with open(original_path) as f:
    original = f.read()

original_by_dep = {dep: text for dep, text in parse_blocks(original) if dep}
refreshed_blocks = parse_blocks(refreshed)

result = [text for _, text in refreshed_blocks]

seen_in_refreshed = {dep for dep, _ in refreshed_blocks if dep}
for dep in skip_deps:
    if dep not in seen_in_refreshed and dep in original_by_dep:
        result.append(original_by_dep[dep])

with open(original_path, 'w') as f:
    f.write(''.join(result))
PYEOF
else
  cp "${tmp_dir}/config/yazi/package.toml" "${package_file}"
fi
