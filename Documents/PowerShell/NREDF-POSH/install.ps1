$PROFILE_PATH = (Get-Item $PROFILE).Directory
Set-Location $PROFILE_PATH

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "Error: Could not find git, install git and try again."
  Exit
}
if (-not ((Get-Command fzf -ErrorAction SilentlyContinue) -or (Get-Command oh-my-posh -ErrorAction SilentlyContinue))) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install -s winget junegunn.fzf JanDeDobbeleer.OhMyPosh
  } elseif (Get-Command brew -ErrorAction SilentlyContinue) {
    brew install fzf oh-my-posh
  } else {
    Write-Error "Error: Could not install fzf and/or oh-my-posh"
    Exit
  }
} else {
  $null = Invoke-Expression "oh-my-posh font install firacode" -ErrorAction SilentlyContinue
}

if (-not ((Test-Path "$PROFILE_PATH\NREDF-POSH") -and (git -C "$PROFILE_PATH\NREDF-POSH" rev-parse --is-inside-work-tree 2>&1  $null))) {
  git clone 'https://github.com/NemesisRE/NREDF-POSH.git'
} else {
  git -C "$PROFILE_PATH\NREDF-POSH" pull --autostash
}

$NREDF_PROFILE_LINES = @(
  '# Load NRE Dotfiles',
  '$ENV:PROFILE_PATH = (Get-Item $PROFILE).Directory',
  '$ENV:NREDF_PATH = "$ENV:PROFILE_PATH\NREDF-POSH"',
  '. "$ENV:NREDF_PATH\Profile.ps1"'
)

$PROFILE_CONTENT = Get-Content $PROFILE -ErrorAction SilentlyContinue

$snippetFound = $false
foreach ($line in $NREDF_PROFILE_LINES) {
  if ($PROFILE_CONTENT -contains $line) {
    $snippetFound = $true
    break
  }
}

if (-not $snippetFound) {
  Set-Content -Path $PROFILE -Value $NREDF_PROFILE_LINES
  Add-Content -Path $PROFILE -Value $PROFILE_CONTENT
}

if ($isWindows) {
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  $CERT_FILE = (Get-ChildItem -Path $PROFILE_PATH\NREDF-POSH\NREDF-POSH.sst)
  $CERT_FILE | Import-Certificate -CertStoreLocation Cert:\CurrentUser\TrustedPublisher
}

& $PROFILE
