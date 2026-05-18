#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _unsudo() {
	if [[ "${EUID}" -eq 0 && -n "${SUDO_USER}" && "${HOME}" = $(eval echo "~${SUDO_USER}") ]]; then
		# shellcheck disable=SC2155
		local SUDO_GROUP=$(id -g -n "${SUDO_USER}")
		chown -R "${SUDO_USER}":"${SUDO_GROUP}" "${HOME}"
		exit
	fi
}
