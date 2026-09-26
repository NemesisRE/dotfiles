. "$ENV:NREDF_PATH\Defaults.ps1"
NREDF_Step "Defaults.ps1"
. "$ENV:NREDF_PATH\PSReadLine.ps1"
NREDF_Step "PSReadLine.ps1"

# ~/.config/pwsh/ — same cross-platform local-override directory bash/zsh/
# fish/nu get (~/.config/<shell>/), via XDG_CONFIG_HOME which Defaults.ps1
# already sets on every OS including Windows. Deliberately not $PROFILE's
# directory: that's Documents\PowerShell\ on Windows but ~/.config/powershell/
# on Linux/macOS, so it wouldn't give PowerShell the same one-location
# consistency the other shells already have.
$nredfPwshDir = Join-Path $ENV:XDG_CONFIG_HOME 'pwsh'

. "$ENV:NREDF_PATH\Aliases.ps1"
$nredfLocalAliases = Join-Path $nredfPwshDir 'aliases.ps1'
if (Test-Path $nredfLocalAliases) {
  . $nredfLocalAliases
}
NREDF_Step "Aliases.ps1"

. "$ENV:NREDF_PATH\Modules.ps1"
$nredfLocalModules = Join-Path $nredfPwshDir 'modules.ps1'
if (Test-Path $nredfLocalModules) {
  . $nredfLocalModules
}
NREDF_Step "Modules.ps1"

# The function bundle (and the per-file fallback below, which dot-sources the same
# files individually) requires PowerShell 7+: NREDF_Bw.ps1 uses the `??`
# null-coalescing operator, a parse error on Windows PowerShell 5.1. The
# Documents/WindowsPowerShell profile dot-sources this same Sources.ps1 (via the
# PowerShell 7 profile stub), so this has to be a runtime guard around the
# dot-source calls themselves — PowerShell only parses a dynamically dot-sourced
# file when the `.` actually executes, so skipping the call avoids the parse error.
if ($PSVersionTable.PSVersion.Major -ge 7) {
  $bundlePath = Join-Path $ENV:NREDF_PATH 'Functions.bundle.ps1'
  if (Test-Path -LiteralPath $bundlePath) {
    . $bundlePath
  } else {
    # Directory is always 'Functions' (capitalized) in this repo; no lowercase fallback needed.
    $functionsDir = Join-Path $ENV:NREDF_PATH 'Functions'
    Get-ChildItem -Path $functionsDir -Filter '*.ps1' | ForEach-Object {
      . $_.FullName
    }
  }
  $nredfLocalFunctions = Join-Path $nredfPwshDir 'functions'
  if (Test-Path $nredfLocalFunctions) {
    Get-ChildItem -Path $nredfLocalFunctions -Filter '*.ps1' | ForEach-Object {
      . $_.FullName
    }
  }
} elseif ([Environment]::UserInteractive) {
  Write-Warning "NREDF: function bundle needs PowerShell 7+, skipped on Windows PowerShell $($PSVersionTable.PSVersion) — see docs/windows.md."
}
NREDF_Step "Functions/*.ps1"
