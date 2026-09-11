function NREDF_SaveInHistory {
  $LINE = $null
  $CURSOR = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]${LINE}, [ref]${CURSOR})
  [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory(${LINE})
  [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
}
