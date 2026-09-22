# chezmoi-managed nu function file.
#
# Naming convention: nu commands here use kebab-case (nredf-init-paths, not
# _nredf_init_paths) to match nu's own ecosystem convention (`str replace`,
# `path exists`, ...) rather than fighting the language — see docs/shells.md.
# This file, and every file in this directory, is concatenated into one
# bundle (functions.bundle.tmpl) and `source`d as a single file, so plain
# `def`/`def --env` (no `export` needed) is all that's required for every
# command here to see every other one.

def --env nredf-init-paths [] {
    if ($env.XDG_CONFIG_HOME? | is-empty) {
        $env.XDG_CONFIG_HOME = ($env.HOME | path join ".config")
    }
    if ($env.XDG_CACHE_HOME? | is-empty) {
        $env.XDG_CACHE_HOME = ($env.HOME | path join ".cache")
    }
    if ($env.XDG_BIN_HOME? | is-empty) {
        $env.XDG_BIN_HOME = ($env.HOME | path join ".local" "bin")
    }
    if ($env.XDG_DATA_HOME? | is-empty) {
        $env.XDG_DATA_HOME = ($env.HOME | path join ".local" "share")
    }
    if ($env.XDG_STATE_HOME? | is-empty) {
        $env.XDG_STATE_HOME = ($env.HOME | path join ".local" "state")
    }
    if ($env.NREDF_CONFIG? | is-empty) {
        $env.NREDF_CONFIG = ($env.XDG_CONFIG_HOME | path join "nredf")
    }
    if ($env.NREDF_LRCACHE? | is-empty) {
        $env.NREDF_LRCACHE = ($env.XDG_CACHE_HOME | path join "nredf" "LRCache")
    }
    if ($env.NREDF_LKCACHE? | is-empty) {
        $env.NREDF_LKCACHE = ($env.XDG_CACHE_HOME | path join "nredf" "LKCache")
    }
    if ($env.NREDF_COMMON_RC_LOCAL? | is-empty) {
        $env.NREDF_COMMON_RC_LOCAL = ($env.HOME | path join ".config" "shell")
    }

    if not ($env.NREDF_SHELL_NAME? | default "" | is-empty) {
        $env.NREDF_RC_LOCAL = ($env.HOME | path join ".config" $env.NREDF_SHELL_NAME)
    }

    if (not ($env.NREDF_DOT_PATH? | default "" | is-empty)) and (not ($env.NREDF_SHELL_NAME? | default "" | is-empty)) {
        $env.NREDF_RC_PATH = ($env.NREDF_DOT_PATH | path join "shell" $env.NREDF_SHELL_NAME)
    }

    # Fast path: only ensure the directory tree once per shell session.
    if (($env._NREDF_PATHS_INITIALIZED? | default "0") == "1") and ($env.NREDF_LRCACHE | path exists) {
        return
    }
    $env._NREDF_PATHS_INITIALIZED = "1"

    for dir in [$env.NREDF_RC_LOCAL $env.NREDF_COMMON_RC_LOCAL $env.NREDF_CONFIG $env.NREDF_LRCACHE $env.NREDF_LKCACHE] {
        if (not ($dir | default "" | is-empty)) and (not ($dir | path exists)) {
            mkdir $dir
        }
    }
}
