# fzf-powered pickers, ported to all five shells with identical names and
# behavior. Each is a thin, non-interactive-safe wrapper: it only touches
# fzf's TUI when actually invoked interactively, so none of it runs at
# shell startup.

# Open $EDITOR (or $env:EDITOR) at a given line number, using the right
# syntax per editor.
function NREDF_FzfOpenAtLine {
  param(
    [Parameter(Mandatory = $true)] [string] $File,
    [Parameter(Mandatory = $true)] [string] $Line
  )
  $editorPath = if ($env:EDITOR) { $env:EDITOR } else { 'vi' }
  $editorName = Split-Path -Leaf $editorPath
  if ($editorName -in 'hx', 'helix') {
    & $editorPath "${File}:${Line}"
  } else {
    & $editorPath "+$Line" -- $File
  }
}

# fif <pattern>: ripgrep for a pattern, fzf to pick a match with a bat
# preview centered on the matching line, then open $EDITOR at that line.
function fif {
  param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Pattern)
  if (-not (Get-Command rg -ErrorAction SilentlyContinue) -or -not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Error 'commands "rg" and "fzf" must both exist on system'
    return
  }
  if (-not $Pattern) {
    Write-Error 'Usage: fif <pattern>'
    return
  }

  $match = & rg -n --with-filename --no-heading --color=always @Pattern |
    & fzf --ansi --delimiter=: `
      --preview 'bat --style=numbers --color=always --highlight-line={2} -- {1}' `
      --preview-window '+{2}-/2'
  if (-not $match) { return }

  $parts = $match -split ':', 3
  NREDF_FzfOpenAtLine -File $parts[0] -Line $parts[1]
}

# fe [query]: fd for files, fzf (bat preview) to pick one, open in $EDITOR.
# $query pre-fills fzf's own search box (fzf --query), it is not an fd pattern.
function fe {
  param([Parameter(Position = 0)] [string] $Query = '')
  if (-not (Get-Command fd -ErrorAction SilentlyContinue) -or -not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Error 'commands "fd" and "fzf" must both exist on system'
    return
  }

  $file = & fd --type file --hidden --follow --exclude .git |
    & fzf --ansi --query=$Query --preview 'bat --style=numbers --color=always -- {}'
  if (-not $file) { return }

  $editorPath = if ($env:EDITOR) { $env:EDITOR } else { 'vi' }
  & $editorPath -- $file
}

# fbr: list local + remote git branches, fzf to pick one, git switch to it
# (stripping the "remotes/origin/" prefix so a remote branch checks out as
# the equivalent local branch instead of a detached HEAD).
function fbr {
  if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Error 'commands "git" and "fzf" must both exist on system'
    return
  }
  & git rev-parse --is-inside-work-tree *>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Error 'fatal: not a git repository'
    return
  }

  # `git branch --all` prefixes every line with a fixed 2-char marker: "* "
  # (current), "+ " (checked out in another worktree) or "  " (neither).
  $branch = & git branch --all | Where-Object { $_ -notmatch '->' } | & fzf --tac
  if (-not $branch) { return }
  $branch = $branch.Substring(2)
  $branch = $branch -replace '^remotes/origin/', ''
  & git switch $branch
}

# flog: browse git log --oneline --graph, previewing the selected commit
# with `git show --color | delta` (falls back to plain `git show` if delta
# is missing).
function flog {
  if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Error 'commands "git" and "fzf" must both exist on system'
    return
  }
  & git rev-parse --is-inside-work-tree *>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Error 'fatal: not a git repository'
    return
  }

  $pager = if (Get-Command delta -ErrorAction SilentlyContinue) { 'delta' } else { 'cat' }
  $preview = "git show --color=always (echo {} | Select-String -Pattern '[0-9a-f]{7,40}').Matches[0].Value | $pager"

  & git log --oneline --graph --color=always --all |
    & fzf --ansi --no-sort --reverse --tiebreak=index --preview $preview | Out-Null
}

# fkill [signal]: procs (or Get-Process if procs is missing) -> fzf -m ->
# Stop-Process. Signal is accepted for cross-shell parity but PowerShell has
# no per-signal Stop-Process, so anything other than the default just forces
# the same termination Stop-Process always does.
function fkill {
  param([Parameter(Position = 0)] [string] $Signal = '9')
  if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Error 'command "fzf" does not exist on system'
    return
  }

  if (Get-Command procs -ErrorAction SilentlyContinue) {
    $lines = & procs --no-header 2>$null
  } else {
    $lines = Get-Process | ForEach-Object { '{0} {1}' -f $_.Id, $_.ProcessName }
  }
  $picked = $lines | & fzf -m --header="kill -$Signal"
  if (-not $picked) { return }

  $pids = @($picked) | ForEach-Object { ($_ -split '\s+')[0] }
  Stop-Process -Id $pids -Force
}
