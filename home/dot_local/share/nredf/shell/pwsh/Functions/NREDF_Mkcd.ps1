# mkdir -p the given directory and cd into it in one step.
function mkcd {
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Path
  )
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
  Set-Location -Path $Path
}
