# Benchmark interactive startup time of every installed shell with hyperfine.
# Same idiom as the bash/zsh/fish/nu versions: `<shell> -i -c exit` forces
# PS1/config loading, then exits immediately instead of waiting on a prompt.
function NREDF_BenchStartup {
  param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $HyperfineArgs)

  if (-not (Get-Command hyperfine -ErrorAction SilentlyContinue)) {
    Write-Error 'command "hyperfine" does not exist on system'
    return
  }

  $shellCmds = @()
  foreach ($sh in 'bash', 'zsh', 'fish', 'nu', 'pwsh') {
    if (-not (Get-Command $sh -ErrorAction SilentlyContinue)) { continue }
    if ($sh -eq 'pwsh') {
      $shellCmds += '-n', 'pwsh', 'pwsh -NoLogo -Command exit'
    } else {
      $shellCmds += '-n', $sh, "$sh -i -c exit"
    }
  }

  if ($shellCmds.Count -eq 0) {
    Write-Error 'none of bash/zsh/fish/nu/pwsh found on PATH'
    return
  }

  # -w 3: warm caches before timing. -N: run each command directly, without
  # an extra shell wrapper. Extra args (e.g. -- --runs 1) let callers override
  # either for a quick smoke test.
  & hyperfine -w 3 -N @HyperfineArgs @shellCmds
}
