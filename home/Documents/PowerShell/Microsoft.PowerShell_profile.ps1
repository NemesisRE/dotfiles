# Load NRE Dotfiles
if ($global:_NREDF_LOADED -and -not $global:_NREDF_RELOAD) { return }
$global:_NREDF_LOADED = $true

$ENV:NREDF_PATH = Join-Path $HOME '.local/share/nredf/shell/pwsh'
if (Test-Path (Join-Path $ENV:NREDF_PATH 'Profile.ps1')) {
  . (Join-Path $ENV:NREDF_PATH 'Profile.ps1')
}

# PowerToys CommandNotFound module (Windows only)
if ($IsWindows) {
  if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
  }
}
