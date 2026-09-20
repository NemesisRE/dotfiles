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
    $completionMatches = $completion.CompletionMatches

    if ($completionMatches.Count -eq 0) {
      [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
      return
    }

    if ($completionMatches.Count -eq 1) {
      $selectedText = $completionMatches[0].CompletionText
      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($completion.ReplacementIndex)
      if ($completion.ReplacementLength -gt 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Delete($completion.ReplacementIndex, $completion.ReplacementLength)
      }
      [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selectedText)
      return
    }

    $lines = foreach ($m in $completionMatches) {
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

  # Helper: invoke fzf via System.Diagnostics.Process so that --height works on Windows.
  # PowerShell pipelines (Invoke-Expression ... | fzf) prevent fzf from accessing the raw
  # console, which is required for partial-height rendering (PSFzf documents this same issue).
  function script:NREDF_InvokeFzf {
    param(
      [string[]]$FzfArgs,       # extra fzf CLI arguments
      [string]  $InputCommand,  # optional shell command whose stdout feeds fzf stdin
      [string]  $ExtraOpts      # extra FZF_DEFAULT_OPTS to append
    )
    $origOpts = $env:FZF_DEFAULT_OPTS
    try {
      if ($ExtraOpts) {
        $env:FZF_DEFAULT_OPTS = if ($origOpts) { "$origOpts $ExtraOpts" } else { $ExtraOpts }
      }

      $fzfExe = (Get-Command fzf -ErrorAction Stop).Source
      $process = [System.Diagnostics.Process]::new()
      $process.StartInfo.FileName = $fzfExe
      $process.StartInfo.Arguments = ($FzfArgs -join ' ')
      $process.StartInfo.UseShellExecute = $false
      $process.StartInfo.RedirectStandardOutput = $true
      $process.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
      if ($InputCommand) {
        $process.StartInfo.RedirectStandardInput = $true
      }
      if ($PWD.Provider.Name -eq 'FileSystem') {
        $process.StartInfo.WorkingDirectory = $PWD.ProviderPath
      }

      $stdOutId = "NREDF_FzfOut-$([System.Guid]::NewGuid())"
      $stdOutEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -SourceIdentifier $stdOutId

      $process.Start() | Out-Null
      $process.BeginOutputReadLine()

      if ($InputCommand) {
        $enc = [System.Text.UTF8Encoding]::new($false)
        $writer = [System.IO.StreamWriter]::new($process.StandardInput.BaseStream, $enc)
        try {
          Invoke-Expression $InputCommand | ForEach-Object {
            try { $writer.WriteLine($_) } catch {}
          }
        } finally {
          try { $writer.Flush(); $writer.Close() } catch {}
        }
      }

      $process.WaitForExit()

      $result = Get-Event -SourceIdentifier $stdOutId -ErrorAction SilentlyContinue |
        Where-Object { $null -ne $_.SourceEventArgs.Data } |
        Sort-Object TimeGenerated |
        ForEach-Object { $_.SourceEventArgs.Data }

      Get-Event -SourceIdentifier $stdOutId -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Event -EventIdentifier $_.EventIdentifier -ErrorAction SilentlyContinue }
      Unregister-Event -SourceIdentifier $stdOutId -ErrorAction SilentlyContinue
      if ($stdOutEvent) { Stop-Job $stdOutEvent -ErrorAction SilentlyContinue; Remove-Job $stdOutEvent -Force -ErrorAction SilentlyContinue }

      return $result
    } finally {
      $env:FZF_DEFAULT_OPTS = $origOpts
    }
  }

  Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -BriefDescription 'FzfFileSearch' -Description 'Fuzzy search files in current directory and insert at cursor' -ScriptBlock {
    try {
      $cmd = if ($env:FZF_CTRL_T_COMMAND) {
        $env:FZF_CTRL_T_COMMAND
      } elseif (Get-Command fd -ErrorAction SilentlyContinue) {
        'fd --hidden --exclude .git'
      } else {
        $null
      }

      $selected = NREDF_InvokeFzf `
        -FzfArgs @('--multi', '--height=40%', '--reverse') `
        -InputCommand $cmd `
        -ExtraOpts $env:FZF_CTRL_T_OPTS

      if ($selected) {
        $quoted = $selected | ForEach-Object {
          if ($_ -match '\s') { "'$_'" } else { $_ }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($quoted -join ' '))
      }
    } finally {
      [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
  }

  $altCScript = {
    try {
      $cmd = if ($env:FZF_ALT_C_COMMAND) {
        $env:FZF_ALT_C_COMMAND
      } elseif (Get-Command fd -ErrorAction SilentlyContinue) {
        'fd --type d --hidden --exclude .git'
      } else {
        $null
      }

      $selected = NREDF_InvokeFzf `
        -FzfArgs @('--no-multi', '--height=40%', '--reverse') `
        -InputCommand $cmd `
        -ExtraOpts $env:FZF_ALT_C_OPTS

      if ($selected -and (Test-Path -LiteralPath $selected)) {
        Set-Location -LiteralPath $selected
      }
    } finally {
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
