#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
# shellcheck disable=SC2086

function _nredf_github_latest_release() {
  _nredf_init_paths

  local GHUSER=${1}
  local GHREPO=${2}
  local TAGREGEX=${3:-""}
  local PREFIX=${4:-""}
  local CACHEFILE="${NREDF_GHCACHE}/nredf_github_latest_release-${GHUSER}-${GHREPO}-${TAGREGEX}"

  if [[ ! -s "${CACHEFILE}" || $(date -r "${CACHEFILE}" +%s) -le $(($(date +%s) - 3600 )) ]]; then
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
      PAGER="" gh release list --exclude-drafts --exclude-pre-releases -R "${GHUSER}/${GHREPO}" --json tagName,isLatest --jq 'first(.[] | select(.tagName | test("'${TAGREGEX}'")) | (.tagName | sub("'^${PREFIX}'"; "")))' > "${CACHEFILE}"
    else
      if command -v jq &>/dev/null; then
        # shellcheck disable=SC2086
        command curl ${NREDF_CURL_GITHUB_AUTH} -fs "https://api.github.com/repos/${GHUSER}/${GHREPO}/releases" | command jq -r 'first(.[] | select(.prerelease == false and .draft == false).tag_name | select(startswith("'${TAGREGEX}'"))) | sub("'^${PREFIX}'"; "")' > "${CACHEFILE}"
      else
        # shellcheck disable=SC2086
        command curl ${NREDF_CURL_GITHUB_AUTH} -fs "https://api.github.com/repos/${GHUSER}/${GHREPO}/releases" | command grep -Eo '"tag_name":[![:space:]]*"'${TAGREGEX}'[-.0-9a-zA-Z]*"' | command awk -F '"' '{print $4}' | command sed -e "s/^${PREFIX}//" | command head -n1 > "${CACHEFILE}"
      fi
    fi
  fi
  cat "${CACHEFILE}"
}
