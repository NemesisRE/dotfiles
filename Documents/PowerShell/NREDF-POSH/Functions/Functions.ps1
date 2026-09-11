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
    if (Test-Path -Path $ENV:NREDF_LRCACHE) {
      Write-Host "==> Clearing last-run cache..." -ForegroundColor Cyan
      Remove-Item -Path "$ENV:NREDF_LRCACHE\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  if ($Downloads -or $Full) {
    $aquaPkgs = Join-Path $ENV:LOCALAPPDATA "aquaproj-aqua\pkgs"
    if (-not (Test-Path $aquaPkgs)) {
      $aquaPkgs = Join-Path $HOME ".local\share\aquaproj-aqua\pkgs"
    }
    if (Test-Path $aquaPkgs) {
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
