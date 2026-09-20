#!/usr/bin/env bash
#
# Propose a refreshed Yazi package lock for review instead of pushing it to main.
#
# `ya pkg upgrade --discard` (see refresh-yazi-package-lock.sh) takes each plugin
# repository at HEAD, so the lock file changes with unreviewed upstream code. This
# used to be committed straight to main with the default GITHUB_TOKEN, which also
# meant CI never ran on it. Now the change lands on a review branch and, when the
# repository allows Actions to open pull requests, as a PR.
#
# Env: GITHUB_REPOSITORY (owner/repo), GH_TOKEN (for gh). Run from the repo root.

set -euo pipefail

file="home/dot_config/yazi/package.toml.tmpl"
branch="${YAZI_LOCK_BRANCH:-chore/yazi-package-lock}"
title="chore(yazi): upgrade plugins and refresh hashes"

if git diff --quiet -- "${file}"; then
  echo "Yazi package lock unchanged; nothing to propose."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# The branch is bot-owned and rebuilt from main every run, so a force-push is
# correct: an already-open PR simply picks up the new commit.
git checkout -B "${branch}"
git add -- "${file}"
git commit -m "${title}"
git push --force origin "HEAD:refs/heads/${branch}"
echo "Pushed ${branch}."

# An open PR for this branch already tracks the branch head; nothing more to do.
open="$(gh pr list --head "${branch}" --state open --json number --jq 'length')"
if [[ "${open}" != "0" ]]; then
  echo "A pull request for ${branch} is already open; it now includes the new commit."
  exit 0
fi

body="Automated refresh of the pinned Yazi plugin revisions and hashes in \`${file}\`.

\`ya pkg upgrade --discard\` takes each plugin repository at its current HEAD, so this pulls in upstream code that has not been reviewed. Please read the rev/hash diff before merging.

CI does not run on this pull request (it is opened with the default \`GITHUB_TOKEN\`, and \`ci.yml\` ignores this file)."

if gh pr create --base main --head "${branch}" --title "${title}" --body "${body}"; then
  exit 0
fi

# Typically: Settings > Actions > General > "Allow GitHub Actions to create and
# approve pull requests" is off. The branch is pushed, so nothing is lost.
echo "::warning title=Yazi lock branch pushed, but no pull request was opened::Open one from https://github.com/${GITHUB_REPOSITORY}/compare/main...${branch}?expand=1 or enable Settings > Actions > General > 'Allow GitHub Actions to create and approve pull requests'."
exit 0
