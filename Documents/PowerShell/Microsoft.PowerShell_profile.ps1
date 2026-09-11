# Load NRE Dotfiles
$ENV:PROFILE_PATH = (Get-Item $PROFILE).Directory
$ENV:NREDF_PATH = Join-Path $ENV:PROFILE_PATH 'NREDF-POSH'
. (Join-Path $ENV:NREDF_PATH 'Profile.ps1')

# PowerToys CommandNotFound module (Windows only)
if ($IsWindows) {
  if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
  }
}
