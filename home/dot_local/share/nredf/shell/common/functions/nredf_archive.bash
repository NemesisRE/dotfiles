#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function extract() {
	if [ -z "${1}" ]; then
		echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
	else
		if [ -f "${1}" ] ; then
			NAME="${1%.*}"
			mkdir "${NAME}" && cd "${NAME}" || exit
			case "${1}" in
				*.tar.bz2)
          tar xvjf ../"${1}"
        ;;
				*.tar.gz)
          tar xvzf ../"${1}"
        ;;
				*.tar.xz)
          tar xvJf ../"${1}"
        ;;
				*.lzma)
          unlzma ../"${1}"
        ;;
				*.bz2)
          bunzip2 ../"${1}"
        ;;
				*.rar)
          unrar x -ad ../"${1}"
        ;;
				*.gz)
          gunzip ../"${1} "
        ;;
				*.tar)
          tar xvf ../"${1}"
        ;;
				*.tbz2)
          tar xvjf ../"${1}"
        ;;
				*.tgz)
          tar xvzf ../"${1}"
        ;;
				*.zip)
          unzip ../"${1}"
        ;;
				*.Z)
          uncompress ../"${1}"
        ;;
				*.7z)
          7z x ../"${1}"
        ;;
				*.xz)
          unxz ../"${1}"
        ;;
				*.exe)
          cabextract ../"${1}"
        ;;
				*)
          echo "extract: '${1}' - unknown archive method"
        ;;
			esac
		else
			echo "${1} - file does not exist"
		fi
	fi
}

function ac() {
	case "${1}" in
		tar.bz2|.tar.bz2) tar cvjf "${2%%/}.tar.bz2" "${2%%/}/" ;;
		tbz2|.tbz2) tar cvjf "${2%%/}.tbz2" "${2%%/}/" ;;
		tbz|.tbz) tar cvjf "${2%%/}.tbz" "${2%%/}/" ;;
		tar.gz|.tar.gz) tar cvzf "${2%%/}.tar.gz" "${2%%/}/" ;;
		tar.Z|.tar.Z) tar Zcvf "${2%%/}.tar.Z" "${2%%/}/" ;;
		tgz|.tgz) tar cvjf "${2%%/}.tgz" "${2%%/}/" ;;
		tar|.tar) tar cvf "${2%%/}.tar" "${2%%/}/" ;;
		rar|.rar) rar a "${2%%/}.rar" "${2%%/}/" ;;
		zip|.zip) zip -r9 "${2}.zip" "$2" ;;
		7z|.7z) 7z a "${2}.7z" "$2" ;;
		lzo|.lzo) lzop -v "$2" ;;
		gz|.gz) gzip -v "$2" ;;
		bz2|.bz2) bzip2 -v "$2" ;;
		xz|.xz) xz -v "$2" ;;
		lzma|.lzma) lzma -v "$2" ;;
		*) echo "Error, please go away.";;
	esac
}

function ad() {
	for FILENAME in "${@}"; do
		if [ -f "${FILENAME}" ] ; then
			case "${FILENAME}" in
				*.tar)       tar xvf "${FILENAME}"     ;;
				*.tbz2)      tar xvjf "${FILENAME}"    ;;
				*.tgz)       tar xvzf "${FILENAME}"    ;;
				*.tar.bz2)   tar xvjf "${FILENAME}"    ;;
				*.tar.gz)    tar xvzf "${FILENAME}"    ;;
				*.tar.xz)    tar xvJf "${FILENAME}"    ;;
				*.lzma)      unlzma "${FILENAME}"      ;;
				*.bz2)       bunzip2 "${FILENAME}"     ;;
				*.rar)       unrar x -ad "${FILENAME}" || 7z x "${FILENAME}";;
				*.gz)        gunzip "${FILENAME}"      ;;
				*.zip)       unzip "${FILENAME}"       ;;
				*.Z)         uncompress "${FILENAME}"  ;;
				*.7z)        7z x "${FILENAME}"        ;;
				*.xz)        unxz "${FILENAME}"        ;;
				*.exe)       cabextract "${FILENAME}"  ;;
				*)           echo "extract: '${FILENAME}' - unknown archive method" ;;
			esac
		else
			echo "${FILENAME} - file does not exist"
		fi
	done
}

function al() {
	case "${1}" in
		*.tar.bz2|*.tbz2|*.tbz) tar -jtf "${1}" ;;
		*.tar.gz|*.tar.Z) tar -ztf "${1}" ;;
		*.tar|*.tgz) tar -tf "${1}" ;;
		*.gz) gzip -l "${1}" ;;
		*.rar) rar vb "${1}" ;;
		*.zip) unzip -l "${1}" ;;
		*.7z) 7z l "${1}" ;;
		*.lzo) lzop -l "${1}" ;;
		*.xz|*.txz|*.lzma|*.tlz) xz -l "${1}" ;;
		*) echo "Error, please go away.";;
	esac
}
