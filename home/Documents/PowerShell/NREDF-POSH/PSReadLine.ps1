# Set Keyhandlers
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key 'Shift+Tab' -Function TabCompletePrevious

# Native fzf integrations (cross-platform, zero PowerShell module overhead)
if (Get-Command fzf -ErrorAction SilentlyContinue) {
  Set-PSReadLineKeyHandler -Chord 'Ctrl+Spacebar' -BriefDescription 'FzfTabCompletion' -Description 'Fuzzy tab completion with descriptions' -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $cursor, $null)
    $matches = $completion.CompletionMatches

    if ($matches.Count -eq 0) {
      [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
      return
    }

    if ($matches.Count -eq 1) {
      $selectedText = $matches[0].CompletionText
      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($completion.ReplacementIndex)
      if ($completion.ReplacementLength -gt 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Delete($completion.ReplacementIndex, $completion.ReplacementLength)
      }
      [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selectedText)
      return
    }

    $lines = foreach ($m in $matches) {
      $display = $m.ListItemText
      $tooltip = if ($m.ToolTip) { $m.ToolTip.Trim() } else { '' }
      if ($tooltip -and $tooltip -ne $m.ListItemText.Trim() -and $m.ListItemText -notmatch [regex]::Escape($tooltip)) {
        $display = "$display  ($tooltip)"
      }
      "$($m.CompletionText)`t$display"
    }

    $origOpts = $env:FZF_DEFAULT_OPTS
    try {
      $env:FZF_DEFAULT_OPTS = if ($origOpts) { "$origOpts --reverse --height=40% --ansi" } else { "--reverse --height=40% --ansi" }
      $selected = $lines | fzf --delimiter="`t" --with-nth=2 --bind="tab:down,btab:up"
      if ($selected) {
        $selectedText = ($selected -split "`t")[0]
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($completion.ReplacementIndex)
        if ($completion.ReplacementLength -gt 0) {
          [Microsoft.PowerShell.PSConsoleReadLine]::Delete($completion.ReplacementIndex, $completion.ReplacementLength)
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selectedText)
      }
    } finally {
      $env:FZF_DEFAULT_OPTS = $origOpts
      [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
  }

  Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -BriefDescription 'FzfFileSearch' -Description 'Fuzzy search files in current directory and insert at cursor' -ScriptBlock {
    $origOpts = $env:FZF_DEFAULT_OPTS
    try {
      if ($env:FZF_CTRL_T_OPTS) {
        $env:FZF_DEFAULT_OPTS = if ($origOpts) { "$origOpts $env:FZF_CTRL_T_OPTS" } else { $env:FZF_CTRL_T_OPTS }
      }
      $cmd = if ($env:FZF_CTRL_T_COMMAND) {
        $env:FZF_CTRL_T_COMMAND
      } elseif (Get-Command fd -ErrorAction SilentlyContinue) {
        'fd --hidden --exclude .git'
      } else {
        $null
      }

      $selected = if ($cmd) {
        Invoke-Expression $cmd | fzf -m
      } else {
        fzf -m
      }

      if ($selected) {
        $quoted = $selected | ForEach-Object {
          if ($_ -match '\s') { "'$_'" } else { $_ }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($quoted -join ' '))
      }
    } finally {
      $env:FZF_DEFAULT_OPTS = $origOpts
      [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
  }

  $altCScript = {
    $origOpts = $env:FZF_DEFAULT_OPTS
    try {
      if ($env:FZF_ALT_C_OPTS) {
        $env:FZF_DEFAULT_OPTS = if ($origOpts) { "$origOpts $env:FZF_ALT_C_OPTS" } else { $env:FZF_ALT_C_OPTS }
      }
      $cmd = if ($env:FZF_ALT_C_COMMAND) {
        $env:FZF_ALT_C_COMMAND
      } elseif (Get-Command fd -ErrorAction SilentlyContinue) {
        'fd --type d --hidden --exclude .git'
      } else {
        $null
      }

      $selected = if ($cmd) {
        Invoke-Expression $cmd | fzf +m
      } else {
        fzf +m
      }

      if ($selected -and (Test-Path -LiteralPath $selected)) {
        Set-Location -LiteralPath $selected
      }
    } finally {
      $env:FZF_DEFAULT_OPTS = $origOpts
      [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
  }

  Set-PSReadLineKeyHandler -Chord 'Alt+c' -BriefDescription 'FzfChangeDirectory' -Description 'Fuzzy search directories and cd into selection' -ScriptBlock $altCScript
  if ($IsMacOS) {
    Set-PSReadLineKeyHandler -Chord 'ç' -BriefDescription 'FzfChangeDirectoryMac' -ScriptBlock $altCScript -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord '©' -BriefDescription 'FzfChangeDirectoryMac' -ScriptBlock $altCScript -ErrorAction SilentlyContinue
  }
}

Set-PSReadLineKeyHandler -Key Ctrl+d -Function ViExit
if (-not (Get-Command atuin -ErrorAction SilentlyContinue)) {
  Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
}
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Alt+d -Function ShellKillWord
Set-PSReadLineKeyHandler -Key Alt+Backspace -Function ShellBackwardKillWord
Set-PSReadLineKeyHandler -Key Alt+q -ScriptBlock { NREDF_SaveInHistory }

# Set PSReadLine options
try {
  Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction SilentlyContinue
} catch {}
try {
  Set-PSReadLineOption -CompletionQueryItems 1000 -ErrorAction SilentlyContinue
} catch {}

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
