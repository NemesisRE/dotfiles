$PSDefaultParameterValues['*:Encoding'] = 'utf8'
$PSDefaultParameterValues['Format-*:AutoSize'] = $true
$PSDefaultParameterValues['Format-*:Wrap'] = $true

$MaximumHistoryCount = 10000

$pathSep = [System.IO.Path]::PathSeparator

if ($isWindows) {
  $ENV:NREDF_CACHE = "$ENV:LOCALAPPDATA\nredf"
  $ENV:NREDF_LRCACHE = "$ENV:NREDF_CACHE\LRCache"
  $YAZI_FILE_ONE = "C:\Program Files\Git\usr\bin\file.exe"

  $extraPaths = @(
    "$HOME\.local\bin",
    "$HOME\.local\share\aquaproj-aqua\bin"
  )
  foreach ($p in $extraPaths) {
    if ((Test-Path $p) -and ($ENV:PATH -notlike "*$p*")) {
      $ENV:PATH = "$p$pathSep$ENV:PATH"
    }
  }

  if (Get-Command -Name python -ErrorAction SilentlyContinue) {
    $pythonScripts = "$ENV:LOCALAPPDATA\Packages\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\LocalCache\local-packages\Python313\Scripts"
    if (Test-Path $pythonScripts) {
      $ENV:PATH = "$ENV:PATH$pathSep$pythonScripts"
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
