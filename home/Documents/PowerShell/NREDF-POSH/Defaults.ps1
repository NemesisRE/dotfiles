$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$PSDefaultParameterValues['Format-*:AutoSize'] = $true
$PSDefaultParameterValues['Format-*:Wrap'] = $true

$MaximumHistoryCount = 10000

$pathSep = [System.IO.Path]::PathSeparator

if ($isWindows) {
  $ENV:NREDF_CACHE = "$ENV:LOCALAPPDATA\nredf"
  $ENV:NREDF_LRCACHE = "$ENV:NREDF_CACHE\LRCache"
  $YAZI_FILE_ONE = "C:\Program Files\Git\usr\bin\file.exe"

  if (-not $ENV:XDG_CONFIG_HOME) { $ENV:XDG_CONFIG_HOME = "$HOME\.config" }
  if (-not $ENV:XDG_DATA_HOME) { $ENV:XDG_DATA_HOME = "$HOME\.local\share" }

  $aquaLocalBin = Join-Path $ENV:LOCALAPPDATA "aquaproj-aqua\bin"
  $extraPaths = @(
    "$HOME\.local\bin",
    $aquaLocalBin,
    "$HOME\.local\share\aquaproj-aqua\bin"
  )
  foreach ($p in $extraPaths) {
    if ((Test-Path $p) -and ($ENV:PATH -notlike "*$p*")) {
      $ENV:PATH = "$p$pathSep$ENV:PATH"
    }
  }

  # Ensure k9s discovers chezmoi-managed plugins, skins, and configs on Windows
  $ENV:K9SCONFIG = "$HOME\.config\k9s"

  # Dynamically detect Python Scripts directory (Windows Store packages or user install)
  if (Get-Command -Name python -ErrorAction SilentlyContinue) {
    $pyAppPackages = Join-Path $ENV:LOCALAPPDATA 'Packages'
    if (Test-Path $pyAppPackages) {
      $pyPkgDirs = Get-ChildItem -Path $pyAppPackages -Filter 'PythonSoftwareFoundation.Python.*' -Directory -ErrorAction SilentlyContinue
      foreach ($pkg in $pyPkgDirs) {
        $scriptsGlob = Join-Path $pkg.FullName 'LocalCache\local-packages\*\Scripts'
        $resolvedScripts = Resolve-Path $scriptsGlob -ErrorAction SilentlyContinue
        if ($resolvedScripts) {
          foreach ($s in $resolvedScripts) {
            if ($ENV:PATH -notlike "*$($s.Path)*") {
              $ENV:PATH = "$($s.Path)$pathSep$ENV:PATH"
            }
          }
        }
      }
    }
    if ($ENV:APPDATA) {
      $userPyGlob = Join-Path $ENV:APPDATA 'Python\Python*\Scripts'
      $resolvedUserPy = Resolve-Path $userPyGlob -ErrorAction SilentlyContinue
      if ($resolvedUserPy) {
        foreach ($s in $resolvedUserPy) {
          if ($ENV:PATH -notlike "*$($s.Path)*") {
            $ENV:PATH = "$($s.Path)$pathSep$ENV:PATH"
          }
        }
      }
    }
  }
}


if ($isLinux -or $IsMacOS) {
  $ENV:XDG_BIN_HOME = "$HOME/.local/bin"
  $ENV:XDG_CONFIG_HOME = "$HOME/.config"
  $ENV:XDG_CACHE_HOME = "$HOME/.cache"
  $ENV:XDG_DATA_HOME = "$HOME/.local/share"
  $ENV:XDG_STATE_HOME = "$HOME/.local/state"
  $ENV:NREDF_CACHE = "$ENV:XDG_CACHE_HOME/nredf"
  $ENV:NREDF_LRCACHE = "$ENV:NREDF_CACHE/LRCache"

  $extraPaths = @(
    "$ENV:XDG_BIN_HOME",
    "$ENV:XDG_DATA_HOME/aquaproj-aqua/bin",
    "/opt/homebrew/bin",
    "/usr/local/bin"
  )
  foreach ($p in $extraPaths) {
    if ((Test-Path $p) -and ($ENV:PATH -notlike "*$p*")) {
      $ENV:PATH = "$p$pathSep$ENV:PATH"
    }
  }

  if ($isLinux) {
    $ENV:POSH_THEMES_PATH = "$ENV:XDG_CACHE_HOME/oh-my-posh/themes"
  }
  if ($IsMacOS) {
    if (Test-Path "/opt/homebrew/opt/oh-my-posh/themes") {
      $ENV:POSH_THEMES_PATH = "/opt/homebrew/opt/oh-my-posh/themes"
    } elseif (Test-Path "/usr/local/opt/oh-my-posh/themes") {
      $ENV:POSH_THEMES_PATH = "/usr/local/opt/oh-my-posh/themes"
    } else {
      $ENV:POSH_THEMES_PATH = "$ENV:XDG_CACHE_HOME/oh-my-posh/themes"
    }
  }
}

# Aqua environment configuration (cross-platform)
if (-not [string]::IsNullOrEmpty($ENV:XDG_CONFIG_HOME)) {
  $aquaConfigDir = Join-Path $ENV:XDG_CONFIG_HOME 'aquaproj-aqua'
  $aquaBaseConfig = Join-Path $aquaConfigDir 'aqua.yaml'
  $aquaPolicyConfig = Join-Path $aquaConfigDir 'aqua-policy.yaml'
  $aquaMachineConfig = Join-Path $aquaConfigDir 'machine.yaml'

  if (Test-Path $aquaBaseConfig) {
    $ENV:AQUA_CONFIG = $aquaBaseConfig
    $ENV:AQUA_GLOBAL_CONFIG = $aquaBaseConfig
    if (Test-Path $aquaMachineConfig) {
      $ENV:AQUA_GLOBAL_CONFIG = "$aquaBaseConfig$pathSep$aquaMachineConfig"
    }
  }
  if (Test-Path $aquaPolicyConfig) {
    $ENV:AQUA_POLICY_CONFIG = $aquaPolicyConfig
  }

  $nredfConfigDir = if ($ENV:NREDF_CONFIG) { $ENV:NREDF_CONFIG } else { Join-Path $ENV:XDG_CONFIG_HOME 'nredf' }
  $aquaAuthConfig = Join-Path $nredfConfigDir 'aqua.env'
  if (Test-Path $aquaAuthConfig) {
    Get-Content $aquaAuthConfig | ForEach-Object {
      $line = $_.Trim()
      if ($line -and -not $line.StartsWith('#') -and $line -match '^([^=]+)=(.*)$') {
        $varName = $matches[1].Trim()
        $varVal = $matches[2].Trim().Trim('"').Trim("'")
        [System.Environment]::SetEnvironmentVariable($varName, $varVal, [System.EnvironmentVariableTarget]::Process)
      }
    }
  }
}

# Zoxide directory navigation integration (cross-platform)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  try {
    $zoxideInit = (& zoxide init powershell 2>$null | Out-String)
    if (-not [string]::IsNullOrWhiteSpace($zoxideInit)) {
      Invoke-Expression $zoxideInit
    }
  } catch {}
}

