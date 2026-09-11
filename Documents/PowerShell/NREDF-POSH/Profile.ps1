if ([string]::IsNullOrEmpty($ENV:NREDF_PATH)) {
  $ENV:PROFILE_PATH = (Get-Item $PROFILE).Directory
  $ENV:NREDF_PATH = Join-Path $ENV:PROFILE_PATH 'NREDF-POSH'
}

. (Join-Path $ENV:NREDF_PATH 'Sources.ps1')

# Set Oh-My-Posh Theme to match bash and zsh profiles
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
  $ompConfig = $null
  if (-not [string]::IsNullOrEmpty($ENV:POSH_THEME_FILE) -and (Test-Path $ENV:POSH_THEME_FILE)) {
    $ompConfig = $ENV:POSH_THEME_FILE
  } elseif (Test-Path "$HOME/.config/oh-my-posh/config.json") {
    $ompConfig = "$HOME/.config/oh-my-posh/config.json"
  } elseif (-not [string]::IsNullOrEmpty($ENV:XDG_CONFIG_HOME) -and (Test-Path "$ENV:XDG_CONFIG_HOME/oh-my-posh/config.json")) {
    $ompConfig = "$ENV:XDG_CONFIG_HOME/oh-my-posh/config.json"
  } elseif (-not [string]::IsNullOrEmpty($ENV:POSH_THEMES_PATH)) {
    $defaultTheme = if ([string]::IsNullOrEmpty($ENV:POSH_THEME_FILE)) { 'powerlevel10k_rainbow.omp.json' } else { $ENV:POSH_THEME_FILE }
    $candidate = Join-Path $ENV:POSH_THEMES_PATH $defaultTheme
    if (Test-Path $candidate) { $ompConfig = $candidate }
  }

  if ($ompConfig) {
    (& oh-my-posh init pwsh --config "$ompConfig" | Out-String) | Invoke-Expression
  } else {
    (& oh-my-posh init pwsh | Out-String) | Invoke-Expression
  }

  # Upgrade check (Windows only - WindowsPrincipal is not supported on non-Windows)
  if ($IsWindows) {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
      # Upgrade oh-my-posh
      #oh-my-posh upgrade --force
    }
  }
}

if ($Env:TERM_PROGRAM -ne 'vscode') {
  NREDF_InstallModules ${MODULES}
  NREDF_UpdateModule
  NREDF_ImportModules ${MODULES}

  # PSFzf settings (configured after module import)
  if (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) {
    if (Get-Command atuin -ErrorAction SilentlyContinue) {
      Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
    } else {
      Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
  }
}

# Atuin shell history integration (matches bash & zsh, bound to both Ctrl+r and UpArrow)
if (Get-Command atuin -ErrorAction SilentlyContinue) {
  (& atuin init powershell | Out-String) | Invoke-Expression
  if (Get-Command Enable-AtuinSearchKeys -ErrorAction SilentlyContinue) {
    Enable-AtuinSearchKeys -CtrlR $true -UpArrow $true
  }
}
