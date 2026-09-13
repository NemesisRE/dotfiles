#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

# Initialize startup profiling. Called once after common functions are sourced.
# Activated by NREDF_PROFILE_STARTUP=1 (set via `reload -p`).
_nredf_now_us() {
  local t sec frac
  t="${EPOCHREALTIME:-}"
  if [[ -n "${t}" ]]; then
    sec="${t%.*}"
    frac="${t#*.}"
    while [[ ${#frac} -lt 6 ]]; do frac="${frac}0"; done
    frac="${frac:0:6}"
    printf "%s%s" "${sec}" "${frac}"
    return 0
  fi

  # Fallback for shells without EPOCHREALTIME (lower precision).
  printf "%s000000" "${EPOCHSECONDS:-$(date +%s)}"
}

_nredf_step() { :; }

# Initialize startup profiling. Called once after common functions are sourced.
# Activated by NREDF_PROFILE_STARTUP=1 (set via `reload -p`).
function _nredf_profile_init() {
  if [[ "${NREDF_PROFILE_STARTUP:-0}" == "1" ]]; then
    _nredf_t0="$(_nredf_now_us)"
    _nredf_t_last="${_nredf_t0}"
    _nredf_step() {
      local label="$1" now elapsed_us elapsed_ms
      now="$(_nredf_now_us)"
      elapsed_us=$((now - _nredf_t_last))
      elapsed_ms=$((elapsed_us / 1000))
      printf "\033[2m  [+%4sms] %s\033[0m\n" "${elapsed_ms}" "${label}" >&2
      _nredf_t_last="${now}"
    }
  else
    _nredf_step() { :; }
  fi
}

# Finish startup profiling. Called at the end of shell initialization.
# Activated by NREDF_PROFILE_STARTUP=1.
# If NREDF_PROFILE_STARTUP_ONESHOT=1, automatically unsets profiling env vars.
function _nredf_profile_finish() {
  if [[ "${NREDF_PROFILE_STARTUP:-0}" == "1" ]]; then
    [[ -n "${_nredf_profile_finished:-}" ]] && return 0
    _nredf_profile_finished=1

    if [[ -n "${_nredf_t0:-}" ]]; then
      local now total_us total_ms
      now="$(_nredf_now_us)"
      total_us=$((now - _nredf_t0))
      total_ms=$((total_us / 1000))
      printf "\033[1;36m  [+%4sms] Total shell startup time\033[0m\n" "${total_ms}" >&2
    fi

    if [[ "${NREDF_PROFILE_STARTUP_ONESHOT:-0}" == "1" ]]; then
      unset NREDF_PROFILE_STARTUP
      unset NREDF_PROFILE_STARTUP_ONESHOT
    fi

    if [[ -n "${ZSH_VERSION:-}" ]] && (( ${+functions[add-zsh-hook]} )); then
      add-zsh-hook -d zshexit _nredf_profile_finish 2>/dev/null || true
    fi

    _nredf_step() { :; }
    unset _nredf_t0 _nredf_t_last
  fi
}
