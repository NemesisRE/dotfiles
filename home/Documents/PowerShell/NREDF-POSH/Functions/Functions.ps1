# Compute file hashes - useful for checking successful downloads
function md5 { Get-FileHash -Algorithm MD5 $args }
function sha1 { Get-FileHash -Algorithm SHA1 $args }
function sha256 { Get-FileHash -Algorithm SHA256 $args }

function sudo {
  <#
  .SYNOPSIS
      Run a command with elevated administrator privileges.
  #>
  if (Get-Command sudo.exe -ErrorAction SilentlyContinue) {
    & (Get-Command -CommandType Application sudo.exe) @args
  } elseif (Get-Command gsudo -ErrorAction SilentlyContinue) {
    & gsudo @args
  } elseif ($IsWindows) {
    $argString = $args -join ' '
    Start-Process powershell -Verb RunAs -ArgumentList "-NoExit -Command $argString"
  } else {
    & sudo @args
  }
}


# Reload profile and run synchronizations
function reload {
  <#
  .SYNOPSIS
      Reload PowerShell profile and run dotfiles / tool synchronizations.
  .DESCRIPTION
      Mirrors the reload command in bash/zsh.
  .PARAMETER Cache
      Delete 'Last Run Cache'.
  .PARAMETER Downloads
      Delete aqua pkgs (archives + binaries, keeps bin/ symlinks).
  .PARAMETER Full
      Full refresh: clear caches + chezmoi/aqua.
  .PARAMETER LastRun
      Delete only 'Last Run Cache'.
  .PARAMETER StartupProfile
      Enable startup profiling (with timestamps for each step).
  .PARAMETER Shell
      Reload with a different shell (e.g., zsh, bash, pwsh, powershell, cmd).
  .PARAMETER Help
      Show usage help.
  #>
  param (
    [Alias('c')]
    [switch]$Cache,
    [Alias('d')]
    [switch]$Downloads,
    [Alias('f')]
    [switch]$Full,
    [Alias('l')]
    [switch]$LastRun,
    [Alias('p', 'Profile')]
    [switch]$StartupProfile,
    [Alias('s')]
    [ArgumentCompleter({
      param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      $candidates = if ($IsWindows) {
        @('pwsh', 'powershell', 'cmd', 'bash', 'nu')
      } else {
        @('zsh', 'bash', 'pwsh', 'fish', 'nu')
      }
      $candidates | Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string]$Shell,
    [Alias('h')]
    [switch]$Help
  )

  if ($Help) {
    Write-Host @"
NREDF Reload

Usage: reload [options]

Options:
-c, [--cache]               # Delete 'Last Run Cache'
-d, [--downloads]           # Delete aqua pkgs (archives + binaries, keeps bin/ symlinks)
-f, [--full]                # Full refresh: clear caches + chezmoi/aqua
-l, [--last-run]            # Delete only 'Last Run Cache'
-p, [--profile]             # Enable startup profiling (with timestamps for each step)
-s SHELL, [--shell SHELL]   # Reload with a different shell
-h, [--help]                # Show this help

"@
    return
  }

  $bold = if ($PSStyle) { $PSStyle.Bold } else { "$([char]27)[1m" }
  $reset = if ($PSStyle) { $PSStyle.Reset } else { "$([char]27)[0m" }

  if ($Cache -or $LastRun -or $Full) {
    if (-not [string]::IsNullOrEmpty($ENV:NREDF_LRCACHE) -and (Test-Path -Path $ENV:NREDF_LRCACHE)) {
      Remove-Item -Path $ENV:NREDF_LRCACHE -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  if ($Downloads) {
    $aquaPkgs = $null
    if (-not [string]::IsNullOrEmpty($ENV:AQUA_ROOT_DIR)) {
      $aquaPkgs = Join-Path $ENV:AQUA_ROOT_DIR 'pkgs'
    } elseif ($IsWindows -and -not [string]::IsNullOrEmpty($ENV:LOCALAPPDATA)) {
      $winPkgs = Join-Path $ENV:LOCALAPPDATA 'aquaproj-aqua\pkgs'
      if (Test-Path $winPkgs) {
        $aquaPkgs = $winPkgs
      }
    }

    if (-not $aquaPkgs) {
      $dataHome = if (-not [string]::IsNullOrEmpty($ENV:XDG_DATA_HOME)) {
        $ENV:XDG_DATA_HOME
      } else {
        Join-Path $HOME (if ($IsWindows) { '.local\share' } else { '.local/share' })
      }
      $fallbackPkgs = Join-Path (Join-Path $dataHome 'aquaproj-aqua') 'pkgs'
      if (Test-Path $fallbackPkgs) {
        $aquaPkgs = $fallbackPkgs
      }
    }

    if ($aquaPkgs -and (Test-Path $aquaPkgs)) {
      Write-Host "${bold}Removing aqua packages${reset}"
      Remove-Item -Path $aquaPkgs -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  if ($Full) {
    Write-Host "${bold}Starting full reload${reset}"
    # LRCACHE is cleared above — chezmoi/aqua run automatically via normal shell init
  }

  if ($StartupProfile) {
    $ENV:NREDF_PROFILE_STARTUP = '1'
  }

  if ($Shell) {
    $targetCmd = Get-Command -Name $Shell -ErrorAction SilentlyContinue
    if (-not $targetCmd) {
      $red = if ($PSStyle) { $PSStyle.Foreground.BrightRed } else { "$([char]27)[1;31m" }
      Write-Host "${red}✘ Command not found ($Shell)${reset}"
      return
    }

    $targetPath = if ($targetCmd.Source) { $targetCmd.Source } elseif ($targetCmd.Path) { $targetCmd.Path } else { $Shell }
    $shellArgs = @()
    if ($Shell -match '^(pwsh|powershell)(\.exe)?$') {
      $shellArgs += '-NoLogo'
    }

    if ((Get-Command Switch-Process -ErrorAction SilentlyContinue) -and -not [Console]::IsInputRedirected) {
      Switch-Process -WithCommand (@($targetPath) + $shellArgs)
    } else {
      & $targetPath @shellArgs
      exit
    }
    return
  }

  if ((Get-Command Switch-Process -ErrorAction SilentlyContinue) -and -not [Console]::IsInputRedirected) {
    $pwsh = if ([System.Environment]::ProcessPath) { [System.Environment]::ProcessPath } else { (Get-Process -Id $PID).Path }
    Switch-Process -WithCommand $pwsh, '-NoLogo'
  } else {
    . $global:PROFILE
  }
}
