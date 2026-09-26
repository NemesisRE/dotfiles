# Initialize startup profiling (activated by NREDF_PROFILE_STARTUP=1 via `reload -p`)
if ($ENV:NREDF_PROFILE_STARTUP -eq '1') {
  $global:_nredf_sw = [System.Diagnostics.Stopwatch]::StartNew()
  $global:_nredf_last_ms = [long]0
  function global:NREDF_Step ([string]$label) {
    $now = $global:_nredf_sw.ElapsedMilliseconds
    $elapsed = $now - $global:_nredf_last_ms
    $global:_nredf_last_ms = $now
    $dim = if ($PSStyle) { $PSStyle.Dim } else { "$([char]27)[2m" }
    $reset = if ($PSStyle) { $PSStyle.Reset } else { "$([char]27)[0m" }
    Write-Host ("${dim}  [+{0,4}ms] {1}${reset}" -f $elapsed, $label)
  }
} else {
  function global:NREDF_Step ([string]$label) {}
}

if ([string]::IsNullOrEmpty($ENV:NREDF_PATH)) {
  $ENV:NREDF_PATH = if ($PSScriptRoot) { $PSScriptRoot } else { Join-Path $HOME '.local/share/nredf/shell/pwsh' }
}

. (Join-Path $ENV:NREDF_PATH 'Sources.ps1')

# Restore Bitwarden session from keychain if available (silent, non-blocking)
if (Test-Path function:\NREDF_BwRestoreSession) {
  NREDF_BwRestoreSession
  NREDF_Step "NREDF_BwRestoreSession"
}

# A `pwsh -Command '...'` / `pwsh -File ...` invocation loads this profile too — only
# -NoProfile skips it — even though it will not drop into an interactive prompt
# afterwards. Mirrors bash's `[ -z "$PS1" ] && return` / fish's `status is-interactive`:
# skip the prompt-theme, completion and tool-init setup below (all Write-Host output or
# otherwise pointless for a one-shot command) for that case, while still keeping the
# BW_SESSION keychain restore above, which every consumer (including a one-shot
# `chezmoi apply`) still needs. `-NoExit` alongside `-Command`/`-File` means the shell
# stays interactive afterwards (VS Code / Windows Terminal launch pwsh this way), so
# that combination is intentionally excluded.
#
# Known limitation: this matches exact flag spellings, not every unambiguous
# abbreviation pwsh's own parameter binder accepts (e.g. `-Comm`), and it scans the
# whole argv rather than only the args pwsh itself consumes, so a script/command
# argument that happens to equal one of these tokens (e.g. `-File deploy.ps1 -NoExit`
# where `-NoExit` is deploy.ps1's own parameter) can be misread. Low practical risk
# for how this profile is actually invoked; not worth the complexity of replicating
# pwsh's full parameter-abbreviation and positional-argument rules here.
$nredfCliArgs = [Environment]::GetCommandLineArgs() | ForEach-Object { $_.ToLowerInvariant() }
$nredfHasNoExit = $nredfCliArgs -contains '-noexit'
$nredfHasBatchArg = [bool]($nredfCliArgs | Where-Object { $_ -in '-c', '-command', '-file', '-f', '-encodedcommand', '-ec' })
if (($nredfCliArgs -contains '-noninteractive') -or ($nredfHasBatchArg -and -not $nredfHasNoExit)) {
  # A batch invocation can inherit NREDF_PROFILE_STARTUP_ONESHOT=1 from a parent
  # interactive shell that just ran `reload -p` (e.g. a tool spawns `pwsh -Command`
  # before the new interactive shell it was meant for actually starts). Clear the
  # oneshot flag here too, silently, so it can't leak into further children — but
  # skip the Write-Host'd total line, since this isn't the profiled session.
  if ($ENV:NREDF_PROFILE_STARTUP_ONESHOT -eq '1') {
    $ENV:NREDF_PROFILE_STARTUP = $null
    $ENV:NREDF_PROFILE_STARTUP_ONESHOT = $null
  }
  return
}

# Set Oh-My-Posh Theme to match bash and zsh profiles
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
  $ompConfig = $null
  if (-not [string]::IsNullOrEmpty($ENV:POSH_THEME_FILE) -and (Test-Path $ENV:POSH_THEME_FILE)) {
    $ompConfig = $ENV:POSH_THEME_FILE
  } elseif (Test-Path "$HOME/.config/oh-my-posh/config.json") {
    $ompConfig = "$HOME/.config/oh-my-posh/config.json"
  } elseif (-not [string]::IsNullOrEmpty($ENV:XDG_CONFIG_HOME) -and (Test-Path "$ENV:XDG_CONFIG_HOME/oh-my-posh/config.json")) {
    $ompConfig = "$ENV:XDG_CONFIG_HOME/oh-my-posh/config.json"
  }

  $ompInitFile = Join-Path $ENV:NREDF_INITCACHE 'omp.pwsh.ps1'
  $ompSnippet = if (Test-Path function:\NREDF_RefreshCachedShellSnippet) {
    NREDF_RefreshCachedShellSnippet -CacheKey 'omp_init_pwsh' -CacheFile $ompInitFile -Generator {
      $raw = if ($ompConfig) {
        & oh-my-posh init pwsh --config "$ompConfig" 2>$null | Out-String
      } else {
        & oh-my-posh init pwsh 2>$null | Out-String
      }
      $raw -replace '\$env:POSH_SESSION_ID\s*=\s*"[^"]+";?\s*', ''
    }
  } else { $null }

  if ($ompSnippet) {
    $env:POSH_SESSION_ID = [System.Guid]::NewGuid().ToString()
    if ($ompConfig) { $env:POSH_CONFIG = $ompConfig }
    . $ompSnippet
  } elseif ($ompConfig) {
    (& oh-my-posh init pwsh --config "$ompConfig" | Out-String) | Invoke-Expression
  } else {
    (& oh-my-posh init pwsh | Out-String) | Invoke-Expression
  }
  NREDF_Step "oh-my-posh init"
}

# Optional local module importing (only runs if custom modules are defined in $PROFILE_PATH\Modules.ps1)
if ($Env:TERM_PROGRAM -ne 'vscode' -and $MODULES -and $MODULES.Count -gt 0) {
  NREDF_InstallModules ${MODULES}
  NREDF_UpdateModule
  NREDF_ImportModules ${MODULES}
  NREDF_Step "PowerShell modules"
}

# Atuin shell history integration (matches bash & zsh, bound to both Ctrl+r and UpArrow)
if (Get-Command atuin -ErrorAction SilentlyContinue) {
  if (-not (Get-Module -Name Atuin -ErrorAction SilentlyContinue)) {
    $atuinInitFile = Join-Path $ENV:NREDF_INITCACHE 'atuin.pwsh.ps1'
    $atuinSnippet = if (Test-Path function:\NREDF_RefreshCachedShellSnippet) {
      NREDF_RefreshCachedShellSnippet -CacheKey 'atuin_init_pwsh' -CacheFile $atuinInitFile -Generator {
        & atuin init powershell 2>$null | Out-String
      }
    } else { $null }

    if ($atuinSnippet) {
      . $atuinSnippet
    } else {
      (& atuin init powershell | Out-String) | Invoke-Expression
    }
  }
  if (Test-Path function:\Enable-AtuinSearchKeys) {
    Enable-AtuinSearchKeys -CtrlR $true -UpArrow $true
  }
  NREDF_Step "Atuin init"
}

# Zoxide directory navigation integration (cross-platform, replace cd, keep z/zi aliases)
# Must run after oh-my-posh so that zoxide's prompt hook wraps the final prompt function
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  try {
    Remove-Variable __zoxide_hooked -Scope Global -ErrorAction SilentlyContinue
    $zoxideInitFile = Join-Path $ENV:NREDF_INITCACHE 'zoxide.pwsh.ps1'
    $zoxideSnippet = if (Test-Path function:\NREDF_RefreshCachedShellSnippet) {
      NREDF_RefreshCachedShellSnippet -CacheKey 'zoxide_init_pwsh' -CacheFile $zoxideInitFile -Generator {
        & zoxide init powershell --cmd cd 2>$null | Out-String
      }
    } else { $null }

    if ($zoxideSnippet) {
      . $zoxideSnippet
    } else {
      $zoxideInit = (& zoxide init powershell --cmd cd 2>$null | Out-String)
      if (-not [string]::IsNullOrWhiteSpace($zoxideInit)) {
        Invoke-Expression $zoxideInit
      }
    }
    Set-Alias -Name z -Value cd -Option AllScope -Scope Global -Force -ErrorAction SilentlyContinue
    Set-Alias -Name zi -Value cdi -Option AllScope -Scope Global -Force -ErrorAction SilentlyContinue
  } catch {}
  NREDF_Step "zoxide init"
}

# Carapace multi-shell multi-command completion integration (cross-platform, cached for fast startup)
if (Get-Command carapace -ErrorAction SilentlyContinue) {
  $carapaceInitFile = Join-Path $ENV:NREDF_INITCACHE 'carapace.pwsh.ps1'
  $carapaceSnippet = if (Test-Path function:\NREDF_RefreshCachedShellSnippet) {
    NREDF_RefreshCachedShellSnippet -CacheKey 'carapace_init_pwsh' -CacheFile $carapaceInitFile -Generator {
      & carapace _carapace powershell 2>$null | Out-String
    }
  } else { $null }

  if ($carapaceSnippet) {
    . $carapaceSnippet
  } else {
    $carapaceInit = (& carapace _carapace powershell 2>$null | Out-String)
    if (-not [string]::IsNullOrWhiteSpace($carapaceInit)) {
      Invoke-Expression $carapaceInit
    }
  }
  NREDF_Step "carapace completions"
}

# Mise runtime environment manager (cross-platform, cached for fast startup)
if (Get-Command mise -ErrorAction SilentlyContinue) {
  $miseInitFile = Join-Path $ENV:NREDF_INITCACHE 'mise.pwsh.ps1'
  $miseSnippet = if (Test-Path function:\NREDF_RefreshCachedShellSnippet) {
    NREDF_RefreshCachedShellSnippet -CacheKey 'mise_init_pwsh' -CacheFile $miseInitFile -Generator {
      & mise activate pwsh 2>$null | Out-String
    }
  } else { $null }

  if ($miseSnippet) {
    . $miseSnippet
  } else {
    $miseInit = (& mise activate pwsh 2>$null | Out-String)
    if (-not [string]::IsNullOrWhiteSpace($miseInit)) {
      Invoke-Expression $miseInit
    }
  }
  NREDF_Step "mise activate"
}

# Inshellisense compatibility (re-wrap prompt and disable colliding predictions when ISTERM is set)
if ($env:ISTERM) {
  if (Test-Path function:Global:__IS-Escape-Value) {
    $Global:__IsOriginalPrompt = $function:Prompt
    function Global:Prompt() {
      $Result = "$([char]0x1b)]6973;PS`a"
      $OriginalPrompt = $Global:__IsOriginalPrompt.Invoke()
      $Result += $OriginalPrompt
      $Result += "$([char]0x1b)]6973;PE`a"
      $Result += if ($pwd.Provider.Name -eq 'FileSystem') { "$([char]0x1b)]6973;CWD;$(Global:__IS-Escape-Value $pwd.ProviderPath)`a" }
      return $Result
    }
  }
  if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
    Set-PSReadLineOption -PredictionSource None -ErrorAction SilentlyContinue
  }
  NREDF_Step "inshellisense init"
}

# Aqua GitHub-token setup prompt and zellij auto-attach over SSH/WSL — mirror
# _nredf_ensure_aqua_github_token / _nredf_remote_multiplexer, called at the
# same point (end of startup) in common/rc.tmpl. Both functions gate on an
# interactive console themselves, so this block is always safe to run,
# including from a non-interactive/-NonInteractive or piped session.
if (Test-Path function:\NREDF_EnsureAquaGithubToken) {
  NREDF_EnsureAquaGithubToken
  NREDF_Step "NREDF_EnsureAquaGithubToken"
}
if (Test-Path function:\NREDF_RemoteMultiplexer) {
  NREDF_RemoteMultiplexer
  NREDF_Step "NREDF_RemoteMultiplexer"
}


# End of startup profiling
if ($ENV:NREDF_PROFILE_STARTUP -eq '1') {
  $total = $global:_nredf_sw.ElapsedMilliseconds
  $cyan = if ($PSStyle) { $PSStyle.Foreground.Cyan } else { "$([char]27)[36m" }
  $reset = if ($PSStyle) { $PSStyle.Reset } else { "$([char]27)[0m" }
  Write-Host ("${cyan}  [+{0,4}ms] Total PowerShell profile startup time${reset}" -f $total)
  if ($ENV:NREDF_PROFILE_STARTUP_ONESHOT -eq '1') {
    $ENV:NREDF_PROFILE_STARTUP = $null
    $ENV:NREDF_PROFILE_STARTUP_ONESHOT = $null
  }
  Remove-Variable _nredf_sw, _nredf_last_ms -Scope Global -ErrorAction SilentlyContinue
}
