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
  $reset = if ($PSStyle) { $PSStyle.Reset } else { "$([char]27)[0m" }

  # ── Chezmoi Dotfiles Sync ──────────────────────────────────────────────────
  if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
    # Check for chezmoi binary upgrades
    try {
      chezmoi upgrade --quiet 2>$null
    } catch {}

    # Check for git updates in chezmoi source directory if git is available
    $chezmoiSrc = (chezmoi source-path 2>$null)
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

    try {
      chezmoi apply -R
    } catch {
      Write-Warning "chezmoi apply failed: $_"
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
}
