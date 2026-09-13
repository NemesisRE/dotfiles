#!/usr/bin/env bash
set -euo pipefail

printf "\n== Chezmoi Machine Configuration ==\n"
printf "Prompting for machine configuration (Git identity, SSH agent, multiplexer, etc.)...\n\n"

if command -v chezmoi &>/dev/null; then
  chezmoi init --prompt
  chezmoi apply
else
  printf "Error: chezmoi binary not found in PATH.\n" >&2
  exit 1
fi

printf "\nDone. Settings updated and applied.\n"
