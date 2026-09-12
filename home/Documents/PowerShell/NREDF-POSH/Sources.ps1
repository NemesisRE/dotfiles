. "$ENV:NREDF_PATH\Defaults.ps1"
. "$ENV:NREDF_PATH\PSReadLine.ps1"
. "$ENV:NREDF_PATH\Aliases.ps1"
if (Test-Path "$ENV:PROFILE_PATH\Aliases.ps1") {
  . "$ENV:PROFILE_PATH\Aliases.ps1"
}
. "$ENV:NREDF_PATH\Modules.ps1"
if (Test-Path "$ENV:PROFILE_PATH\Modules.ps1") {
  . "$ENV:PROFILE_PATH\Modules.ps1"
}
Get-ChildItem -Path "$ENV:NREDF_PATH\Functions" -Filter '*.ps1' | ForEach-Object {
  . $_.FullName
}
if (Test-Path "$ENV:PROFILE_PATH\Functions") {
  Get-ChildItem -Path "$ENV:PROFILE_PATH\Functions" -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
  }
}
Get-ChildItem -Path "$ENV:NREDF_PATH\Completions" -Filter '*.ps1' | ForEach-Object {
  . $_.FullName
}
if (Test-Path "$ENV:PROFILE_PATH\Completions") {
  Get-ChildItem -Path "$ENV:PROFILE_PATH\Completions" -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
  }
}
