#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh
# shellcheck disable=SC2016,SC2155,SC2086

# _nredf_tool_fzf: install fzf (legacy — aqua now manages the binary)
function _nredf_tool_fzf() {
  _nredf_get_sys_info

  if [[ -n ${1} ]]; then
    FORCE_INSTALL=true
  fi

  if [[ ${NREDF_OS} == windows ]]; then
    local FILEEXT="zip"
  fi

  local GHUSER="junegunn"
  local GHREPO="fzf"
  local BINARY="fzf"
  local TAGVERSION="${1:-$(_nredf_github_latest_release "${GHUSER}" "${GHREPO}")}"
  local VERSION="${TAGVERSION#v}"
  local FILENAME="${BINARY}-${VERSION}-$(_nredf_asset_os uname-lower)_${NREDF_ARCH}.${FILEEXT:-tar.gz}"
  local VERSION_CMD="${XDG_BIN_HOME}/${BINARY} --version | awk '{print \$1}'"
  local DOWNLOAD_CMD="_nredf_github_download_latest \"${GHUSER}\" \"${GHREPO}\" \"${FILENAME}\" \"${TAGVERSION}\""
  local EXTRACT_CMD='
    command tar -xzf "${NREDF_DOWNLOADS}/${FILENAME}" -C "${XDG_BIN_HOME}/"

    [[ ! -d ${HOME}/.config/fzf ]] && /bin/mkdir "${HOME}/.config/fzf"
    for FZF_FILE in completion.bash completion.zsh key-bindings.bash key-bindings.zsh key-bindings.fish; do
      command curl ${NREDF_CURL_GITHUB_AUTH} -Lfso "${HOME}/.config/fzf/${FZF_FILE}" "https://raw.githubusercontent.com/${GHUSER}/${GHREPO}/master/shell/${FZF_FILE}"
    done
  '
  _nredf_install_tool "${BINARY}" "${TAGVERSION}" "${VERSION}" "${VERSION_CMD}" "${DOWNLOAD_CMD}" "${EXTRACT_CMD}" "${FORCE_INSTALL}"
}

# Source fzf keybindings/completions and nredf fzf customizations
function _nredf_tool_fzf_source() {
  if command -v fzf &>/dev/null; then
    if [[ "${NREDF_SHELL_NAME}" =~ ^(bash|zsh)$ ]]; then
      # Prefer modern fzf init (fzf >= 0.48 supports --zsh / --bash)
      if fzf --version 2>/dev/null | awk '{split($1,v,"."); exit !(v[1]>0 || v[2]>=48)}'; then
        eval "$(fzf "--${NREDF_SHELL_NAME}")"
      else
        [[ -f "${HOME}/.config/fzf/completion.${NREDF_SHELL_NAME}" ]] && source "${HOME}/.config/fzf/completion.${NREDF_SHELL_NAME}"
        [[ -f "${HOME}/.config/fzf/key-bindings.${NREDF_SHELL_NAME}" ]] && source "${HOME}/.config/fzf/key-bindings.${NREDF_SHELL_NAME}"
      fi
    fi

    # nredf fzf customizations (ssh completions, etc.)
    [[ -f "${NREDF_DOT_PATH}/shell/common/fzf" ]] && source "${NREDF_DOT_PATH}/shell/common/fzf"
  fi
}
