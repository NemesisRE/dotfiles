# Compute file hashes - useful for checking successful downloads
function md5 { Get-FileHash -Algorithm MD5 $args }
function sha1 { Get-FileHash -Algorithm SHA1 $args }
function sha256 { Get-FileHash -Algorithm SHA256 $args }

# From https://github.com/Pscx/Pscx
function sudo() { Invoke-Elevated @args }

# Reload profile and run synchronizations
function reload {
  <#
  .SYNOPSIS
      Reload PowerShell profile and run dotfiles / tool synchronizations.
  .DESCRIPTION
      Runs chezmoi apply -R, aqua install -a -l, updates tools, and reloads $PROFILE.
      Mirrors the reload command in bash/zsh.
  .PARAMETER Full
      Full refresh: clear caches, run all updates, and reload.
  .PARAMETER Cache
      Delete 'Last Run Cache'.
  .PARAMETER Downloads
      Delete downloaded aqua packages.
  .PARAMETER Help
      Show usage help.
  #>
  param (
    [Alias('f')]
    [switch]$Full,
    [Alias('s')]
    [switch]$Sync,
    [Alias('c', 'l')]
    [switch]$Cache,
    [Alias('d')]
    [switch]$Downloads,
    [Alias('h')]
    [switch]$Help
  )

  if ($Help) {
    Write-Host @"
NREDF Reload (PowerShell)

Usage: reload [options]

Options:
  -c, -Cache, -l    Delete 'Last Run Cache'
  -d, -Downloads    Delete aqua packages cache
  -f, -Full         Full refresh: clear caches + run chezmoi & aqua updates
  -s, -Sync         Force run chezmoi & aqua sync without clearing cache
  -h, -Help         Show this help
"@
    return
  }

  if ($Cache -or $Full) {
    if (-not [string]::IsNullOrEmpty($ENV:NREDF_LRCACHE) -and (Test-Path -Path $ENV:NREDF_LRCACHE)) {
      Write-Host "==> Clearing last-run cache..." -ForegroundColor Cyan
      $cacheItems = Join-Path $ENV:NREDF_LRCACHE '*'
      Remove-Item -Path $cacheItems -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  if ($Downloads) {
    $aquaPkgs = $null
    if (-not [string]::IsNullOrEmpty($ENV:AQUA_ROOT_DIR)) {
      $aquaPkgs = Join-Path $ENV:AQUA_ROOT_DIR 'pkgs'
    } elseif ($IsWindows -and -not [string]::IsNullOrEmpty($ENV:LOCALAPPDATA)) {
      $winPkgs = Join-Path $ENV:LOCALAPPDATA 'aquaproj-aqua\pkgs'
      if (Test-Path $winPkgs) {
        $aquaPkgs = $winPkgs
      }
    }

    if (-not $aquaPkgs) {
      $dataHome = if (-not [string]::IsNullOrEmpty($ENV:XDG_DATA_HOME)) {
        $ENV:XDG_DATA_HOME
      } else {
        Join-Path $HOME (if ($IsWindows) { '.local\share' } else { '.local/share' })
      }
      $fallbackPkgs = Join-Path (Join-Path $dataHome 'aquaproj-aqua') 'pkgs'
      if (Test-Path $fallbackPkgs) {
        $aquaPkgs = $fallbackPkgs
      }
    }

    if ($aquaPkgs -and (Test-Path $aquaPkgs)) {
      Write-Host "==> Removing aqua packages..." -ForegroundColor Cyan
      Remove-Item -Path $aquaPkgs -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  # Only force daily sync if -Full or -Sync is explicitly specified
  if ($Full -or $Sync) {
    if (Get-Command NREDF_DailySync -ErrorAction SilentlyContinue) {
      NREDF_DailySync -Force
    }
  }

  Write-Host "==> Reloading PowerShell profile..." -ForegroundColor Green
  & ${PROFILE}
}
