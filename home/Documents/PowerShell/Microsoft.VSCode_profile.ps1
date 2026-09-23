# Load NRE Dotfiles
$nredfShellPwsh = Join-Path $HOME '.local/share/nredf/shell/pwsh'
if (Test-Path (Join-Path $nredfShellPwsh 'Profile.ps1')) {
  $ENV:NREDF_PATH = $nredfShellPwsh
} else {
  $ENV:PROFILE_PATH = (Get-Item $PROFILE).Directory
  $ENV:NREDF_PATH = "$ENV:PROFILE_PATH\NREDF-POSH"
}
if (Test-Path (Join-Path $ENV:NREDF_PATH 'Profile.ps1')) {
  . "$ENV:NREDF_PATH\Profile.ps1"
}

