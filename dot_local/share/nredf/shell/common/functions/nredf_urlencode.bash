#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_urlencode() {
  OLD_LC_COLLATE=${LC_COLLATE}
  LC_COLLATE=C

  local LENGTH="${#1}"
  for (( i = 0; i < LENGTH; i++ )); do
    local COUNT="${1:$i:1}"
    case ${COUNT} in
      [a-zA-Z0-9.~_-])
        printf '%s' "${COUNT}"
      ;;
      *)
        printf '%%%02X' "'${COUNT}"
      ;;
    esac
  done

  LC_COLLATE=${OLD_LC_COLLATE}
}
