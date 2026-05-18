#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

declare -A NREDF_CONFIGS
source "${NREDF_DOT_PATH:-${XDG_DATA_HOME:-${HOME}/.local/share}/nredf}/shell/common/config/default_config.bash"
if [[ -e "${NREDF_CONFIG}/config.bash" ]]; then
  source "${NREDF_CONFIG}/config.bash"
fi
echo -n "" > "${NREDF_CONFIG}/config.bash"
for CONFIG in "${!NREDF_CONFIGS[@]}"; do
  CONFIG_KEY="${CONFIG}"
  CONFIG_VALUE="${NREDF_CONFIGS[${CONFIG}]}"
  # Emit both key styles for zsh compatibility: some code reads NREDF_CONFIGS[KEY],
  # older code may still use NREDF_CONFIGS["KEY"].
  echo "NREDF_CONFIGS[$CONFIG_KEY]=\"$CONFIG_VALUE\"" >> "${NREDF_CONFIG}/config.bash"
  echo "NREDF_CONFIGS[\"$CONFIG_KEY\"]=\"$CONFIG_VALUE\"" >> "${NREDF_CONFIG}/config.bash"
done
sort -o "${NREDF_CONFIG}/config.bash"{,}
