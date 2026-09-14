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
  $ENV:PROFILE_PATH = (Get-Item $PROFILE).Directory
  $ENV:NREDF_PATH = Join-Path $ENV:PROFILE_PATH 'NREDF-POSH'
}

. (Join-Path $ENV:NREDF_PATH 'Sources.ps1')

# Set Oh-My-Posh Theme to match bash and zsh profiles
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
  $ompConfig = $null
  if (-not [string]::IsNullOrEmpty($ENV:POSH_THEME_FILE) -and (Test-Path $ENV:POSH_THEME_FILE)) {
    $ompConfig = $ENV:POSH_THEME_FILE
  } elseif (Test-Path "$HOME/.config/oh-my-posh/config.json") {
    $ompConfig = "$HOME/.config/oh-my-posh/config.json"
  } elseif (-not [string]::IsNullOrEmpty($ENV:XDG_CONFIG_HOME) -and (Test-Path "$ENV:XDG_CONFIG_HOME/oh-my-posh/config.json")) {
    $ompConfig = "$ENV:XDG_CONFIG_HOME/oh-my-posh/config.json"
  } elseif (-not [string]::IsNullOrEmpty($ENV:POSH_THEMES_PATH)) {
    $defaultTheme = if ([string]::IsNullOrEmpty($ENV:POSH_THEME_FILE)) { 'powerlevel10k_rainbow.omp.json' } else { $ENV:POSH_THEME_FILE }
    $candidate = Join-Path $ENV:POSH_THEMES_PATH $defaultTheme
    if (Test-Path $candidate) { $ompConfig = $candidate }
  }

  $ompInitFile = Join-Path $ENV:NREDF_INITCACHE 'omp.pwsh.ps1'
  $ompSnippet = if (Get-Command NREDF_RefreshCachedShellSnippet -ErrorAction SilentlyContinue) {
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

  # Upgrade check (Windows only - WindowsPrincipal is not supported on non-Windows)
  if ($IsWindows) {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
      # Upgrade oh-my-posh
      #oh-my-posh upgrade --force
    }
  }
}

# Daily automated sync for dotfiles and aqua tools (throttled to once per 24h)
if (-not $ENV:CHEZMOI -and (Get-Command NREDF_DailySync -ErrorAction SilentlyContinue)) {
  NREDF_DailySync
  NREDF_Step "NREDF_DailySync"
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
    $atuinSnippet = if (Get-Command NREDF_RefreshCachedShellSnippet -ErrorAction SilentlyContinue) {
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
  if (Get-Command Enable-AtuinSearchKeys -ErrorAction SilentlyContinue) {
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
    $zoxideSnippet = if (Get-Command NREDF_RefreshCachedShellSnippet -ErrorAction SilentlyContinue) {
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
