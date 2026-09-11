# Load NRE Dotfiles
$ENV:PROFILE_PATH = (Get-Item $PROFILE).Directory
if (-not (Test-Path (Join-Path $ENV:PROFILE_PATH 'NREDF-POSH'))) {
  $altProfilePath = Join-Path $HOME 'Documents\PowerShell'
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
