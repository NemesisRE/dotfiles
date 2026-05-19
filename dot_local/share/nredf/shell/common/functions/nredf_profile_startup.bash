#!/usr/bin/env bash
#
# vim: ts=2 sw=2 et ff=unix ft=bash syntax=sh

# Initialize startup profiling. Called once after common functions are sourced.
# Activated by NREDF_PROFILE_STARTUP=1 (set via `reload -p`).
function _nredf_profile_init() {
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
