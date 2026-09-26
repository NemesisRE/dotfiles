function NREDF_DailySync {
  <#
  .SYNOPSIS
      Daily background sync for chezmoi dotfiles, aqua tools, and package maintenance.
  .DESCRIPTION
      Throttled to run once every 24 hours (or immediately if -Force is passed).
      Mirrors the daily automated checks executed in bash/zsh dotfiles rc.
  #>
  param (
    [switch]$Force
  )

  # Do not run if invoked inside a chezmoi script execution
  if ($ENV:CHEZMOI) {
    return
  }

  # Check throttle (24h) unless -Force is specified
  if (-not $Force) {
    if (NREDF_LastRun -CurrentFunction 'NREDF_DailySync') {
      return
    }
  }

  # Mark next run 24h ahead immediately to prevent concurrent shells from overlapping
  [Void] (NREDF_LastRun -CurrentFunction 'NREDF_DailySync' -Success $true -NextRun ((Get-Date).AddHours(24).ToFileTime()))

  $bold = if ($PSStyle) { $PSStyle.Bold } else { "$([char]27)[1m" }
  $yellow = if ($PSStyle) { $PSStyle.Foreground.Yellow } else { "$([char]27)[1;33m" }
  $reset = if ($PSStyle) { $PSStyle.Reset } else { "$([char]27)[0m" }

  # ── Chezmoi Dotfiles Sync ──────────────────────────────────────────────────
  if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
    $chezmoiBin = Get-Command chezmoi -CommandType Application -ErrorAction SilentlyContinue

    # Check for chezmoi binary upgrades
    if ($chezmoiBin) {
      try {
        & $chezmoiBin upgrade 2>$null
      } catch {}
    }

    # Check for git updates in chezmoi source directory if git is available
    $chezmoiSrc = if ($chezmoiBin) { & $chezmoiBin source-path 2>$null } else { $null }
    if ($chezmoiSrc -and (Test-Path $chezmoiSrc) -and (Get-Command git -ErrorAction SilentlyContinue)) {
      try {
        git -C $chezmoiSrc fetch --quiet 2>$null
        $local = (git -C $chezmoiSrc rev-parse '@' 2>$null)
        $remote = (git -C $chezmoiSrc rev-parse '@{u}' 2>$null)
        if ($remote -and ($local -ne $remote)) {
          Write-Host "${bold}Pulling dotfiles${reset}"
          git -C $chezmoiSrc pull --ff-only --quiet 2>$null
        }
      } catch {}
    }

    # The scheduled task runs with -NoProfile and no terminal, so restore
    # BW_SESSION from the keychain the way the profile does, then skip the
    # apply up front when Bitwarden is in use but locked: its template call
    # would otherwise fail and abort the apply half-way.
    # Only the get-*.tmpl helpers read a vault, and only for a `bitwarden:`/`bw:`
    # reference in these three secrets, so look at those (like the POSIX
    # script) rather than at the [bitwarden] section, which the personal
    # profile writes even when no secret uses it.
    $usesBitwarden = $false
    $chezmoiConfig = Join-Path (Join-Path ($ENV:XDG_CONFIG_HOME ?? (Join-Path $HOME '.config')) 'chezmoi') 'chezmoi.toml'
    if (Test-Path -LiteralPath $chezmoiConfig) {
      $usesBitwarden = [bool](Select-String -LiteralPath $chezmoiConfig -Quiet `
          -Pattern '^\s*(aqua_github_token|git_signing_key|mcp_servers)\s*=\s*["''](bitwarden|bw):')
    }
    $vaultLocked = $false
    if ($usesBitwarden -and (Get-Command bw -CommandType Application -ErrorAction SilentlyContinue)) {
      if (Get-Command NREDF_BwRestoreSession -ErrorAction SilentlyContinue) {
        NREDF_BwRestoreSession
      }
      $bwStatus = ($null | & bw status 2>$null | Out-String)
      if ($bwStatus -notmatch '"status":\s*"unlocked"') {
        $vaultLocked = $true
        Write-Host "${yellow}ℹ chezmoi apply skipped: Bitwarden vault is locked (run bwu, then reload -f)${reset}"
      }
    }

    if (-not $vaultLocked) {
      Write-Host "${bold}Syncing dotfiles and externals${reset}"
      try {
        # Run non-interactively (--no-tty) with null stdin so startup dotfile
        # sync never hangs if a password safe (Bitwarden, KeePassXC, 1Password)
        # requires master password authentication.
        $syncErr = ($null | & chezmoi apply --refresh-externals --force --no-tty 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) {
          if ($syncErr -match '(locked|unlock|password|session|authentication|unauthorized)') {
            Write-Host "${yellow}ℹ chezmoi apply skipped: password safe is locked (unlock to sync dotfiles)${reset}"
          } else {
            Write-Warning "chezmoi apply failed: $syncErr"
          }
        }
      } catch {
        Write-Warning "chezmoi apply failed: $_"
      }
    }
    NREDF_Step "chezmoi dotfiles sync"
  }

  # ── Aqua Tools Sync ────────────────────────────────────────────────────────
  if (Get-Command aqua -ErrorAction SilentlyContinue) {
    try {
      if ($ENV:NREDF_PROFILE_STARTUP -or $ENV:NREDF_VERBOSE) {
        Write-Host "${bold}Updating aqua${reset}"
      }
      aqua update-aqua 2>$null
    } catch {}

    try {
      aqua install -a -l 2>$null
    } catch {
      Write-Warning "aqua install failed: $_"
    }

    try {
      if ($ENV:NREDF_PROFILE_STARTUP -or $ENV:NREDF_VERBOSE) {
        Write-Host "${bold}Vacuuming aqua packages${reset}"
      }
      aqua vacuum -d 30 2>$null
    } catch {}
    NREDF_Step "aqua tools sync"
  }

  # ── TLDR Pages Sync ────────────────────────────────────────────────────────
  if (Get-Command tldr -ErrorAction SilentlyContinue) {
    try {
      tldr --update 2>$null
    } catch {}
    NREDF_Step "tldr pages sync"
  }

  # ── oh-my-posh Session Cache Prune ─────────────────────────────────────────
  # Every shell mints a new POSH_SESSION_ID, so <shell>.<id>.omp.cache files
  # pile up forever. The shared omp.cache and init.* scripts are kept. The
  # scheduled task runs -NoProfile, so XDG_CACHE_HOME may be unset there.
  $ompCacheDirs = @(
    if ($ENV:XDG_CACHE_HOME) { Join-Path $ENV:XDG_CACHE_HOME 'oh-my-posh' }
    if ($IsWindows -and $ENV:LOCALAPPDATA) { Join-Path $ENV:LOCALAPPDATA 'oh-my-posh' }
    Join-Path (Join-Path $HOME '.cache') 'oh-my-posh'
  ) | Select-Object -Unique
  $ompCutoff = (Get-Date).AddDays(-7)
  foreach ($ompCacheDir in $ompCacheDirs) {
    if (Test-Path -LiteralPath $ompCacheDir -PathType Container) {
      Get-ChildItem -LiteralPath $ompCacheDir -Filter '*.omp.cache' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*.omp.cache' -and $_.LastWriteTime -lt $ompCutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    }
  }
  NREDF_Step "oh-my-posh cache prune"
}
