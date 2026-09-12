#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

function _nredf_init_paths() {
  export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
  export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
  export XDG_BIN_HOME="${XDG_BIN_HOME:-${HOME}/.local/bin}"
  export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
  export XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
  export NREDF_CONFIG="${NREDF_CONFIG:-${XDG_CONFIG_HOME}/nredf}"
  export NREDF_LRCACHE="${NREDF_LRCACHE:-${XDG_CACHE_HOME}/nredf/LRCache}"
  export NREDF_LKCACHE="${NREDF_LKCACHE:-${XDG_CACHE_HOME}/nredf/LKCache}"
  export NREDF_COMMON_RC_LOCAL="${NREDF_COMMON_RC_LOCAL:-${HOME}/.config/shell}"

  if [[ -n "${NREDF_SHELL_NAME}" ]]; then
    export NREDF_RC_LOCAL="${HOME}/.config/${NREDF_SHELL_NAME}"
  fi

  if [[ -n "${NREDF_DOT_PATH}" && -n "${NREDF_SHELL_NAME}" ]]; then
    export NREDF_RC_PATH="${NREDF_DOT_PATH}/shell/${NREDF_SHELL_NAME}"
  fi

  local NREDF_PATH=""
  for NREDF_PATH in \
    "${NREDF_RC_LOCAL}" \
    "${NREDF_COMMON_RC_LOCAL}" \
    "${XDG_CONFIG_HOME}" \
    "${XDG_BIN_HOME}" \
    "${XDG_CACHE_HOME}" \
    "${NREDF_CONFIG}" \
    "${NREDF_LRCACHE}" \
    "${NREDF_LKCACHE}" \
    "${XDG_DATA_HOME}" \
    "${XDG_STATE_HOME}"; do
    [[ -n "${NREDF_PATH}" && ! -d "${NREDF_PATH}" ]] && mkdir -p "${NREDF_PATH}"
  done

  for NREDF_PATH in \
    "${XDG_CONFIG_HOME}/completion" \
    "${XDG_CONFIG_HOME}/completion/bash" \
    "${XDG_CONFIG_HOME}/completion/zsh" \
    "${NREDF_CONFIG}/shell" \
    "${NREDF_CONFIG}/shell/bash" \
    "${NREDF_CONFIG}/shell/zsh" \
    "${NREDF_CONFIG}/shell/common" \
    "${NREDF_CONFIG}/shell/common/functions" \
    "${NREDF_CONFIG}/shell/${NREDF_SHELL_NAME}" \
    "${NREDF_CONFIG}/shell/${NREDF_SHELL_NAME}/functions"; do
    [[ -n "${NREDF_PATH}" && ! -d "${NREDF_PATH}" ]] && mkdir -p "${NREDF_PATH}"
  done
}
