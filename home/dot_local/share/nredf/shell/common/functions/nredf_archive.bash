#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function extract() {
	if [ -z "${1}" ]; then
		echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|zst|tar.bz2|tar.gz|tar.xz|tar.zst>" >&2
		return 1
	fi

	if [ ! -f "${1}" ]; then
		echo "${1} - file does not exist" >&2
		return 1
	fi

	if command -v ouch &>/dev/null; then
		ouch decompress "$@"
		return $?
	fi

	local name="${1}"
	case "${name}" in
		*.tar.bz2|*.tar.gz|*.tar.xz|*.tar.zst) name="${name%.tar.*}" ;;
		*) name="${name%.*}" ;;
	esac

	mkdir -p "${name}" && cd "${name}" || return 1
	case "${1}" in
		*.tar.bz2|*.tbz2|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar) tar xvf ../"${1}" ;;
		*.tar.zst|*.tzst) tar --zstd -xvf ../"${1}" 2>/dev/null || zstd -dc ../"${1}" | tar xvf - ;;
		*.lzma)           unlzma ../"${1}" ;;
		*.bz2)            bunzip2 ../"${1}" ;;
		*.rar)            unrar x -ad ../"${1}" 2>/dev/null || 7z x ../"${1}" ;;
		*.gz)             gunzip ../"${1}" ;;
		*.zip)            unzip ../"${1}" ;;
		*.Z)              uncompress ../"${1}" ;;
		*.7z)             7z x ../"${1}" ;;
		*.xz)             unxz ../"${1}" ;;
		*.zst)            zstd -d ../"${1}" ;;
		*.exe)            cabextract ../"${1}" ;;
		*)                echo "extract: '${1}' - unknown archive method" >&2; return 1 ;;
	esac
}

function ac() {
	if [ -z "${1}" ]; then
		echo "Usage: ac <format> <source>  (e.g. ac tar.gz myfolder)" >&2
		echo "   or: ac <files...> <archive.ext>  (with ouch)" >&2
		return 1
	fi

	if command -v ouch &>/dev/null; then
		if [ $# -eq 2 ]; then
			case "${1#.}" in
				tar.bz2|tbz2|tbz|tar.gz|tgz|tar.xz|txz|tar.zst|tzst|tar|rar|zip|7z|gz|bz2|xz|zst|lzma)
					local ext="${1#.}"
					local target="${2%%/}"
					ouch compress "${target}" "${target}.${ext}"
					return $?
					;;
			esac
		fi
		ouch compress "$@"
		return $?
	fi

	case "${1}" in
		tar.bz2|.tar.bz2|tbz2|.tbz2|tbz|.tbz) tar cvjf "${2%%/}.tar.bz2" "${2%%/}/" ;;
		tar.gz|.tar.gz|tgz|.tgz)             tar cvzf "${2%%/}.tar.gz" "${2%%/}/" ;;
		tar.xz|.tar.xz|txz|.txz)             tar cvJf "${2%%/}.tar.xz" "${2%%/}/" ;;
		tar.zst|.tar.zst|tzst|.tzst)         tar --zstd -cvf "${2%%/}.tar.zst" "${2%%/}/" ;;
		tar.Z|.tar.Z)                        tar Zcvf "${2%%/}.tar.Z" "${2%%/}/" ;;
		tar|.tar)                            tar cvf "${2%%/}.tar" "${2%%/}/" ;;
		rar|.rar)                            rar a "${2%%/}.rar" "${2%%/}/" ;;
		zip|.zip)                            zip -r9 "${2%%/}.zip" "$2" ;;
		7z|.7z)                              7z a "${2%%/}.7z" "$2" ;;
		lzo|.lzo)                            lzop -v "$2" ;;
		gz|.gz)                              gzip -v "$2" ;;
		bz2|.bz2)                            bzip2 -v "$2" ;;
		xz|.xz)                              xz -v "$2" ;;
		zst|.zst)                            zstd -v "$2" ;;
		lzma|.lzma)                          lzma -v "$2" ;;
		*)                                   echo "Unknown archive format: ${1}" >&2; return 1 ;;
	esac
}

function ad() {
	if [ -z "${1}" ]; then
		echo "Usage: ad <archive> [archive2...]" >&2
		return 1
	fi

	if command -v ouch &>/dev/null; then
		ouch decompress --here "$@"
		return $?
	fi

	for filename in "${@}"; do
		if [ -f "${filename}" ]; then
			case "${filename}" in
				*.tar.bz2|*.tbz2|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar) tar xvf "${filename}" ;;
				*.tar.zst|*.tzst) tar --zstd -xvf "${filename}" 2>/dev/null || zstd -dc "${filename}" | tar xvf - ;;
				*.lzma)           unlzma "${filename}"      ;;
				*.bz2)            bunzip2 "${filename}"     ;;
				*.rar)            unrar x -ad "${filename}" 2>/dev/null || 7z x "${filename}" ;;
				*.gz)             gunzip "${filename}"      ;;
				*.zip)            unzip "${filename}"       ;;
				*.Z)              uncompress "${filename}"  ;;
				*.7z)             7z x "${filename}"        ;;
				*.xz)             unxz "${filename}"        ;;
				*.zst)            zstd -d "${filename}"     ;;
				*.exe)            cabextract "${filename}"  ;;
				*)                echo "extract: '${filename}' - unknown archive method" >&2 ;;
			esac
		else
			echo "${filename} - file does not exist" >&2
		fi
	done
}

function al() {
	if [ -z "${1}" ]; then
		echo "Usage: al <archive> [archive2...]" >&2
		return 1
	fi

	if command -v ouch &>/dev/null; then
		ouch list --tree "$@"
		return $?
	fi

	case "${1}" in
		*.tar.bz2|*.tbz2|*.tbz|*.tar.gz|*.tar.Z|*.tar.xz|*.tar|*.tgz) tar -tf "${1}" ;;
		*.tar.zst|*.tzst)        tar --zstd -tf "${1}" 2>/dev/null || zstd -dc "${1}" | tar -tf - ;;
		*.gz)                    gzip -l "${1}" ;;
		*.rar)                   rar vb "${1}" 2>/dev/null || 7z l "${1}" ;;
		*.zip)                   unzip -l "${1}" ;;
		*.7z)                    7z l "${1}" ;;
		*.lzo)                   lzop -l "${1}" ;;
		*.xz|*.txz|*.lzma|*.tlz) xz -l "${1}" ;;
		*.zst)                   zstd -l "${1}" ;;
		*)                       echo "al: '${1}' - unknown archive method" >&2; return 1 ;;
	esac
}

