# ── NREDF hook environment (home/.chezmoitemplates/hook-env.sh) ───────────────
# chezmoi can run from a shell that never loaded the NREDF framework (the very
# first apply, bootstrap.sh, a cron/launchd job), where aqua's bin dir is not on
# PATH and aqua's proxy links cannot find their config. A run_onchange_ hook that
# then silently skips its tool is still recorded as done, so it would not try
# again until its input changes. Compute this at run time on purpose: chezmoi's
# `scriptEnv` is baked into chezmoi.toml at `chezmoi init`, so it would freeze
# the PATH of whatever shell ran init and drop anything installed since.
for _nredf_hook_dir in \
  "${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/aquaproj-aqua}/bin" \
  "${HOME}/.local/bin"; do
  case ":${PATH}:" in
    *":${_nredf_hook_dir}:"*) ;;
    *) PATH="${_nredf_hook_dir}:${PATH}" ;;
  esac
done
unset _nredf_hook_dir
export PATH

# Same resolution as _nredf_set_aqua_env in the shell framework.
_nredf_hook_aqua_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/aquaproj-aqua"
if [[ -f "${_nredf_hook_aqua_dir}/aqua.yaml" ]]; then
  export AQUA_CONFIG="${_nredf_hook_aqua_dir}/aqua.yaml"
  export AQUA_GLOBAL_CONFIG="${_nredf_hook_aqua_dir}/aqua.yaml"
  if [[ -f "${_nredf_hook_aqua_dir}/machine.yaml" ]]; then
    export AQUA_GLOBAL_CONFIG="${AQUA_GLOBAL_CONFIG}:${_nredf_hook_aqua_dir}/machine.yaml"
  fi
fi
if [[ -f "${_nredf_hook_aqua_dir}/aqua-policy.yaml" ]]; then
  export AQUA_POLICY_CONFIG="${_nredf_hook_aqua_dir}/aqua-policy.yaml"
fi
unset _nredf_hook_aqua_dir
# ── end NREDF hook environment ────────────────────────────────────────────────
