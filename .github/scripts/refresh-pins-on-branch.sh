#!/usr/bin/env bash
#
# Finish a Renovate bump of a hash-pinned tool, on the PR branch it lives on.
#
# Renovate changes only `version`. The artifacts are also pinned by SHA-256, so the
# bare bump fails the `pins` CI job. This recomputes the hashes, commits them to the
# same branch and re-runs CI on the new head commit.
#
# Why CI has to be re-run explicitly and why [skip ci] is used: pushing to a PR
# branch with the default GITHUB_TOKEN triggers `pull_request` workflows in an
# `action_required` (approval required) state. `[skip ci]` suppresses those parked
# runs. `workflow_dispatch` is exempt from both skip keywords and approval requirements;
# it runs CI immediately and attaches check runs to the head SHA so Renovate can
# automerge on green.
#
# The commit is authored as github-actions[bot] with the exact address listed in
# renovate.json `gitIgnoredAuthors`, so Renovate does not treat the PR as hand-edited
# and keeps rebasing it (dropping this commit, which this then re-creates).
#
# Usage: refresh-pins-on-branch.sh <branch>     (run from a checkout of that branch)
# Env:   GH_TOKEN (for gh); PINS_UPDATE_CMD overrides the refresh command (tests).

set -euo pipefail

branch="${1:?usage: refresh-pins-on-branch.sh <branch>}"
update_cmd="${PINS_UPDATE_CMD:-python3 .github/scripts/pins.py update}"

# shellcheck disable=SC2086 # intentional word splitting of the command string
${update_cmd}

if git diff --quiet; then
  echo "Pins already match the pinned versions; nothing to commit."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Only tracked files that pins.py rewrites can have changed.
git add -u
git commit -m "chore(pins): refresh SHA-256 pins for the bumped version [skip ci]"
git push origin "HEAD:refs/heads/${branch}"
echo "Pushed refreshed pins to ${branch}."

gh workflow run ci.yml --ref "${branch}"
echo "Triggered CI on ${branch}."
