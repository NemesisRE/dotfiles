# Load NRE Dotfiles
if ($global:_NREDF_LOADED -and -not $global:_NREDF_RELOAD) { return }
$global:_NREDF_LOADED = $true

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PROFILE }
$ENV:PROFILE_PATH = $scriptDir
if (-not (Test-Path (Join-Path $ENV:PROFILE_PATH 'NREDF-POSH'))) {
  $altProfilePath = Join-Path (Join-Path $HOME 'Documents') 'PowerShell'
  if (Test-Path (Join-Path $altProfilePath 'NREDF-POSH')) {
    $ENV:PROFILE_PATH = $altProfilePath
  }
}
$ENV:NREDF_PATH = Join-Path $ENV:PROFILE_PATH 'NREDF-POSH'
. (Join-Path $ENV:NREDF_PATH 'Profile.ps1')

# PowerToys CommandNotFound module (Windows only)
if ($IsWindows) {
  if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
  }
}
