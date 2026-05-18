#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function git_remove_submodule() {
	SUBMODULE_NAME=$(echo "${1}" | sed 's/\/$//'); shift

	if git submodule status "${SUBMODULE_NAME}" >/dev/null 2>&1; then
		git submodule deinit -f "${SUBMODULE_NAME}"
		git rm --cached "${SUBMODULE_NAME}"
		rm -rf ".git/modules/${SUBMODULE_NAME}"
		rm -rf "${SUBMODULE_NAME}"
		git config -f .gitmodules --remove-section "submodule.${SUBMODULE_NAME}"
	else
		[ $# -gt 0 ] && echo "fatal: Submodule '${SUBMODULE_NAME}' not found" 1>&2
		exit 1
	fi
}
