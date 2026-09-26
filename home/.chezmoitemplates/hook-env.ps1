# ── NREDF hook environment (home/.chezmoitemplates/hook-env.ps1) ─────────────
# The Windows-side equivalent of the non-Windows hooks' own PATH/AQUA_* setup
# (see e.g. run_onchange_after_aqua.sh.tmpl), pulled into the Windows hooks with
# includeTemplate. batch/09-posix-hooks introduces a shared
# .chezmoitemplates/hook-env.sh for that side with the same job; this file mirrors
# its reasoning in PowerShell rather than being included by it (chezmoi templates
# don't cross the bash/PowerShell language boundary), so the two can drift — keep
# them in sync by hand if one changes.
#
# chezmoi can run from a process that never loaded the NREDF profile (the first
# apply, bootstrap.ps1, the NREDF-DailySync scheduled task). There, aqua's bin dir
# is not on PATH, winget installs made earlier in the same apply are invisible, and
# aqua's proxy links cannot find their config. A run_onchange_ hook that then skips
# its tool silently is still recorded as done, and does not retry until its input
# changes. This is computed at run time on purpose: chezmoi's `scriptEnv` is baked
# into chezmoi.toml at `chezmoi init` and would freeze that shell's PATH.

# Call NREDF_HookEnv again after installing something mid-hook.
function NREDF_HookEnv {
    # Machine + User PATH picks up anything winget installed since chezmoi started;
    # the process's own entries stay first so nothing already resolved moves.
    $hookPath = [System.Collections.Generic.List[string]]::new()
    $hookSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($hookEntry in @(
            (Join-Path $HOME '.local\bin')
            (Join-Path $env:LOCALAPPDATA 'aquaproj-aqua\bin')
            (Join-Path $HOME '.local\share\aquaproj-aqua\bin')
        ) + ($env:PATH -split ';') +
        ([System.Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';') +
        ([System.Environment]::GetEnvironmentVariable('Path', 'User') -split ';')) {
        if ($hookEntry -and $hookSeen.Add($hookEntry.TrimEnd('\'))) {
            $hookPath.Add($hookEntry)
        }
    }
    $env:PATH = $hookPath -join ';'

    # Same resolution as the aqua block in pwsh/Defaults.ps1.
    $hookAquaDir = Join-Path $(if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }) 'aquaproj-aqua'
    if (Test-Path -LiteralPath (Join-Path $hookAquaDir 'aqua.yaml')) {
        $env:AQUA_CONFIG = Join-Path $hookAquaDir 'aqua.yaml'
        $env:AQUA_GLOBAL_CONFIG = $env:AQUA_CONFIG
        if (Test-Path -LiteralPath (Join-Path $hookAquaDir 'machine.yaml')) {
            $env:AQUA_GLOBAL_CONFIG = "$($env:AQUA_CONFIG);$(Join-Path $hookAquaDir 'machine.yaml')"
        }
    }
    if (Test-Path -LiteralPath (Join-Path $hookAquaDir 'aqua-policy.yaml')) {
        $env:AQUA_POLICY_CONFIG = Join-Path $hookAquaDir 'aqua-policy.yaml'
    }
}
NREDF_HookEnv
# ── end NREDF hook environment ───────────────────────────────────────────────
