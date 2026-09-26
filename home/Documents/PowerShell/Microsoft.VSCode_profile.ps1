# Load NRE Dotfiles
$ENV:NREDF_PATH = Join-Path $HOME '.local/share/nredf/shell/pwsh'
if (Test-Path (Join-Path $ENV:NREDF_PATH 'Profile.ps1')) {
  . "$ENV:NREDF_PATH\Profile.ps1"
}

