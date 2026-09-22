#!/usr/bin/env fish
#
# vim: ts=4 sw=4 et ft=fish
#
# Opt-in startup profiler (NREDF_PROFILE_STARTUP=1, toggled via `reload -p`).
# Fish has no EPOCHREALTIME-equivalent high-resolution clock builtin, so this
# reuses the same whole-second-resolution fallback bash/zsh accept on a
# pre-5.0 bash without EPOCHREALTIME (see nredf_profile_startup.bash).

function _nredf_now_us --description 'Microsecond-ish timestamp, best effort'
    set -l raw (date +%s%N 2>/dev/null)
    if string match -qr '^[0-9]{16,}$' -- "$raw"
        # date supports %N (GNU date, and modern macOS/BSD date): trim
        # seconds+nanoseconds down to seconds+microseconds (16 digits).
        string sub -l 16 -- "$raw"
        return 0
    end
    # %N unsupported (older BSD date): degrade to whole-second resolution.
    echo (date +%s)000000
end

function _nredf_step
end

function _nredf_profile_init --description 'Called once after functions are sourced'
    if test "$NREDF_PROFILE_STARTUP" = 1
        set -g _nredf_t0 (_nredf_now_us)
        set -g _nredf_t_last "$_nredf_t0"
        function _nredf_step --argument-names label
            set -l now (_nredf_now_us)
            set -l elapsed_us (math "$now - $_nredf_t_last")
            set -l elapsed_ms (math "$elapsed_us / 1000")
            printf "\033[2m  [+%4sms] %s\033[0m\n" "$elapsed_ms" "$label" >&2
            set -g _nredf_t_last "$now"
        end
    else
        function _nredf_step
        end
    end
end

function _nredf_profile_finish --description 'Called at the end of shell init'
    if test "$NREDF_PROFILE_STARTUP" = 1
        test -n "$_nredf_profile_finished"; and return 0
        set -g _nredf_profile_finished 1

        if test -n "$_nredf_t0"
            set -l now (_nredf_now_us)
            set -l total_us (math "$now - $_nredf_t0")
            set -l total_ms (math "$total_us / 1000")
            printf "\033[1;36m  [+%4sms] Total shell startup time\033[0m\n" "$total_ms" >&2
        end

        if test "$NREDF_PROFILE_STARTUP_ONESHOT" = 1
            set -e NREDF_PROFILE_STARTUP
            set -e NREDF_PROFILE_STARTUP_ONESHOT
        end

        function _nredf_step
        end
        set -e _nredf_t0
        set -e _nredf_t_last
    end
end
