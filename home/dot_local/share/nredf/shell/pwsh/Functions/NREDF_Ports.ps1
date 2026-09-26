# List listening TCP ports. Windows gets the native Get-NetTCPConnection
# cmdlet; non-Windows pwsh (Linux/macOS) falls back to the same ss/lsof
# chain the bash/zsh/fish/nu versions use. This file only ever loads on
# PS >= 7 (see Sources.ps1's version gate), so $IsWindows is always defined.
function ports {
  if ($IsWindows) {
    Get-NetTCPConnection -State Listen |
      Select-Object LocalAddress, LocalPort, OwningProcess |
      Sort-Object LocalPort
  } elseif (Get-Command ss -ErrorAction SilentlyContinue) {
    & ss -tlnp 2>$null
    if ($LASTEXITCODE -ne 0) { & ss -tln }
  } elseif (Get-Command lsof -ErrorAction SilentlyContinue) {
    & lsof -nP -iTCP -sTCP:LISTEN
  } else {
    Write-Error 'none of "Get-NetTCPConnection", "ss" or "lsof" available'
  }
}
