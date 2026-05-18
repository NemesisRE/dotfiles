#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
# shellcheck disable=SC2086

function _nredf_github_download_latest() {
  _nredf_init_paths

  local GHUSER=${1}
  local GHREPO=${2}
  local GHFILE=${3}
  local VERSION=${4}
  local VERSIONURLENC

  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    gh release download --clobber -p "${GHFILE}" -R "${GHUSER}/${GHREPO}" -D "${NREDF_DOWNLOADS}" "${VERSION}"
  else
    if [[ ${VERSION} == "latest" ]]; then
      command curl ${NREDF_CURL_GITHUB_AUTH} -Lfso "${NREDF_DOWNLOADS}/${GHFILE}" "https://github.com/${GHUSER}/${GHREPO}/releases/latest/download/${GHFILE}"
    else
      VERSIONURLENC=$(_nredf_urlencode "${VERSION}")
      command curl ${NREDF_CURL_GITHUB_AUTH} -Lfso "${NREDF_DOWNLOADS}/${GHFILE}" "https://github.com/${GHUSER}/${GHREPO}/releases/download/${VERSIONURLENC}/${GHFILE}"
    fi
  fi

  return ${?}
}
