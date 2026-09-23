# Load NRE Dotfiles
if ($global:_NREDF_LOADED -and -not $global:_NREDF_RELOAD) { return }
$global:_NREDF_LOADED = $true

$nredfShellPwsh = Join-Path $HOME '.local/share/nredf/shell/pwsh'
if (Test-Path (Join-Path $nredfShellPwsh 'Profile.ps1')) {
  $ENV:NREDF_PATH = $nredfShellPwsh
} else {
  $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PROFILE }
  $ENV:PROFILE_PATH = $scriptDir
  if (Test-Path (Join-Path $ENV:PROFILE_PATH 'NREDF-POSH')) {
    $ENV:NREDF_PATH = Join-Path $ENV:PROFILE_PATH 'NREDF-POSH'
  }
}

if ($ENV:NREDF_PATH -and (Test-Path (Join-Path $ENV:NREDF_PATH 'Profile.ps1'))) {
  . (Join-Path $ENV:NREDF_PATH 'Profile.ps1')
}

# PowerToys CommandNotFound module (Windows only)
if ($IsWindows) {
  if (Get-Module -ListAvailable -Name Microsoft.WinGet.CommandNotFound) {
    Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue
  }
}
