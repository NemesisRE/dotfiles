# Set Keyhandlers
#Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

if ($Env:TERM_PROGRAM -ne 'vscode') {
  if ( ${isWindows} ) {
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-GuiCompletion }
  } elseif ( ${isLinux} -or ${isMacOS} ) {
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock {
      if (Get-Command Invoke-FzfTabCompletion -ErrorAction SilentlyContinue) {
        Invoke-FzfTabCompletion -CaseInsensitive
      } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Complete()
      }
    }
  }

  Set-PSReadLineKeyHandler -Key Ctrl+d -Function ViExit
  Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
  Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
  Set-PSReadLineKeyHandler -Key Alt+d -Function ShellKillWord
  Set-PSReadLineKeyHandler -Key Alt+Backspace -Function ShellBackwardKillWord
  Set-PSReadLineKeyHandler -Key Alt+q -ScriptBlock { NREDF_SaveInHistory }

  # Set PSReadLine options
  Set-PSReadLineOption -PredictionSource HistoryAndPlugin

  Set-PSReadLineKeyHandler -Chord '"', "'" `
    -BriefDescription SmartInsertQuote `
    -LongDescription 'Insert paired quotes if not already on a quote' `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line.Length -gt $cursor -and $line[$cursor] -eq $key.KeyChar) {
      # Just move the cursor
      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    } else {
      # Insert matching quotes, move cursor to be in between the quotes
      [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)" * 2)
      [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
    }
  }
}
