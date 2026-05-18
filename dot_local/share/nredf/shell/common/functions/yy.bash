#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function yy() {
	local tmp
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"

  if [[ ! "$(command -v yazi)" ]]; then
    echo "command \"yazi\" does not exist on system"
    return 1
  fi

	yazi "${@}" --cwd-file="${tmp}"
	if cwd="$(cat -- "${tmp}")" && [ -n "${cwd}" ] && [ "${cwd}" != "${PWD}" ]; then
		cd -- "${cwd}" || return
	fi
	rm -f -- "${tmp}"
}
