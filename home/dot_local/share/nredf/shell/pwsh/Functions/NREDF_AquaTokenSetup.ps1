# chezmoi-managed pwsh function file.
# -----------------------------------------------------------------------------
# Aqua GitHub token setup wizard
#
# Port of common/functions/nredf_aqua.bash's nredf_aqua_token_setup (also
# nredf_aqua.fish/.nu) — see that file for the full design writeup. Shares
# the same state/marker file bash/fish/nu use:
# ${NREDF_CONFIG:-$XDG_CONFIG_HOME/nredf}/aqua.env, which Defaults.ps1 already
# reads at startup (NREDF_ReadDotenv). Written in plain POSIX
# `[export] KEY='value'` syntax, never PowerShell syntax, because bash/zsh
# `source` this file directly.
#
# Public
# - nredf_aqua_token_setup [--set|--keyring|--env|--skip|--reset|--status]
# - NREDF_EnsureAquaGithubToken   Startup prompt (called from Profile.ps1),
#                                 interactive-only, with a timeout. Never
#                                 records "no" for an unanswered prompt.
# -----------------------------------------------------------------------------

$script:_NREDF_AQUA_KEYRING_PROBED = $null

# True when a real interactive console is attached to both stdin and stdout
# — the pwsh equivalent of bash's `[[ -r /dev/tty && -w /dev/tty ]]`. Used to
# make sure nothing here ever blocks or prompts in a non-interactive /
# `-NonInteractive` / piped session.
function NREDF_AquaHasInteractiveConsole {
  try {
    return (-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected)
  } catch {
    return $false
  }
}

# Reads one line from the console with a timeout, without PowerShell's own
# Read-Host (which has no timeout parameter). Returns
# @{ Value = <string-or-$null>; TimedOut = <bool> }. A timeout discards
# whatever was typed so far — matching bash's `read -t`, which does not set
# its output variable at all when the timeout fires mid-line. With -Mask,
# nothing is echoed (bash's `read -s`); otherwise typed characters echo
# normally, since ReadKey(-Intercept) doesn't echo on its own.
function NREDF_AquaReadLineWithTimeout {
  param(
    [int]$TimeoutSeconds = 30,
    [switch]$Mask
  )

  if (-not (NREDF_AquaHasInteractiveConsole)) {
    return [PSCustomObject]@{ Value = $null; TimedOut = $true }
  }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $sb = [System.Text.StringBuilder]::new()

  try {
    while ($true) {
      if ($sw.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
        Write-Host ''
        return [PSCustomObject]@{ Value = $null; TimedOut = $true }
      }
      if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Enter) {
          Write-Host ''
          return [PSCustomObject]@{ Value = $sb.ToString(); TimedOut = $false }
        } elseif ($key.Key -eq [ConsoleKey]::Backspace) {
          if ($sb.Length -gt 0) {
            [void]$sb.Remove($sb.Length - 1, 1)
            if (-not $Mask) { Write-Host "`b `b" -NoNewline }
          }
        } elseif ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
          [void]$sb.Append($key.KeyChar)
          if (-not $Mask) { Write-Host $key.KeyChar -NoNewline }
        }
      } else {
        Start-Sleep -Milliseconds 50
      }
    }
  } catch {
    Write-Host ''
    return [PSCustomObject]@{ Value = $null; TimedOut = $true }
  }
}

# Returns 0 = yes, 1 = no, 2 = unanswered (no usable console, or timed out).
# "Unanswered" must never be conflated with "no": callers record "no" as a
# permanent opt-out, which is wrong when nobody was there to be asked.
function NREDF_AquaPromptYesNo {
  param([string]$Prompt)

  if (-not (NREDF_AquaHasInteractiveConsole)) { return 2 }

  $timeoutSeconds = 30
  $parsedTimeout = 0
  if ($env:NREDF_PROMPT_TIMEOUT -and [int]::TryParse($env:NREDF_PROMPT_TIMEOUT, [ref]$parsedTimeout)) {
    $timeoutSeconds = $parsedTimeout
  }

  while ($true) {
    Write-Host -NoNewline "$Prompt [y/N]: "
    $result = NREDF_AquaReadLineWithTimeout -TimeoutSeconds $timeoutSeconds
    if ($result.TimedOut) { return 2 }
    switch -Regex ($result.Value) {
      '^(y|Y|yes|YES)$' { return 0 }
      '^(n|N|no|NO|)$' { return 1 }
      default { Write-Host 'Please answer yes or no.' }
    }
  }
}

# aqua requires the D-Bus secret service (org.freedesktop.secrets) on
# Linux/Unix. macOS and Windows always have their own native keychain.
function NREDF_AquaKeyringProbe {
  $bus = $env:DBUS_SESSION_BUS_ADDRESS
  if (-not $bus) {
    $runtimeDir = $env:XDG_RUNTIME_DIR
    if (-not $runtimeDir) {
      $uid = (& id -u 2>$null)
      $runtimeDir = "/run/user/$uid"
    }
    $sock = Join-Path $runtimeDir 'bus'
    if (Test-Path $sock) {
      $bus = "unix:path=$sock"
    } else {
      return $false
    }
  }

  $savedBus = $env:DBUS_SESSION_BUS_ADDRESS
  try {
    $env:DBUS_SESSION_BUS_ADDRESS = $bus

    if (Get-Command gdbus -ErrorAction SilentlyContinue) {
      & gdbus call --session --dest org.freedesktop.secrets --object-path /org/freedesktop/secrets --method org.freedesktop.DBus.Peer.Ping 1>$null 2>$null
      return ($LASTEXITCODE -eq 0)
    }
    if (Get-Command busctl -ErrorAction SilentlyContinue) {
      & busctl --user call org.freedesktop.secrets /org/freedesktop/secrets org.freedesktop.DBus.Peer Ping 1>$null 2>$null
      return ($LASTEXITCODE -eq 0)
    }
    if (Get-Command dbus-send -ErrorAction SilentlyContinue) {
      & dbus-send --session --dest=org.freedesktop.secrets --type=method_call --print-reply /org/freedesktop/secrets org.freedesktop.DBus.Peer.Ping 1>$null 2>$null
      return ($LASTEXITCODE -eq 0)
    }
    return $false
  } finally {
    $env:DBUS_SESSION_BUS_ADDRESS = $savedBus
  }
}

# Cached for this session (an explicit nredf_aqua_token_setup command always
# re-probes — see NREDF_AquaTokenSetupCore). $IsMacOS/$IsWindows already
# capture exactly what bash/fish's own WINDIR/COMSPEC-without-WSL heuristic
# is working around, so no extra WSL check is needed here: a real WSL pwsh
# process reports $IsWindows = $false (it's a genuine Linux binary).
function NREDF_AquaKeyringAvailable {
  if ($IsMacOS -or $IsWindows) { return $true }

  if ($null -eq $script:_NREDF_AQUA_KEYRING_PROBED) {
    $script:_NREDF_AQUA_KEYRING_PROBED = NREDF_AquaKeyringProbe
  }
  return $script:_NREDF_AQUA_KEYRING_PROBED
}

function NREDF_AquaAuthConfigFile {
  $configDir = $env:NREDF_CONFIG
  if (-not $configDir) {
    $xdgConfig = $env:XDG_CONFIG_HOME
    if (-not $xdgConfig) { $xdgConfig = Join-Path $HOME '.config' }
    $configDir = Join-Path $xdgConfig 'nredf'
  }
  return (Join-Path $configDir 'aqua.env')
}

# POSIX single-quoting, so a value pwsh writes stays sourceable by bash/zsh
# (which `source` this file directly) and parseable by fish/nu's own
# dedicated dotenv readers.
function NREDF_AquaPosixQuote {
  param([string]$Value)
  return ("'" + ($Value -replace "'", "'\''") + "'")
}

function NREDF_WriteAquaAuthConfig {
  param(
    [Parameter(Mandatory = $true)][string]$Mode,
    [string]$Token = ''
  )

  if ([string]::IsNullOrEmpty($Mode)) {
    Write-Error 'missing aqua auth mode'
    return $false
  }

  $authFile = NREDF_AquaAuthConfigFile
  $authDir = Split-Path -Parent $authFile
  if (-not (Test-Path $authDir)) {
    New-Item -ItemType Directory -Path $authDir -Force | Out-Null
  }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('# Local aqua GitHub auth preferences')
  $lines.Add("NREDF_AQUA_GITHUB_TOKEN_SETUP=$(NREDF_AquaPosixQuote $Mode)")
  if ($Mode -eq 'keyring') {
    $lines.Add("AQUA_KEYRING_ENABLED=$(NREDF_AquaPosixQuote 'true')")
  } elseif ($Mode -eq 'env' -and $Token) {
    $lines.Add("export AQUA_GITHUB_TOKEN=$(NREDF_AquaPosixQuote $Token)")
    $lines.Add("export GITHUB_TOKEN=$(NREDF_AquaPosixQuote $Token)")
  }

  # The file can hold a GitHub token: write to a temp file in the same
  # directory first and restrict it before it's ever visible at the real
  # path, then move it into place, rather than chmod-ing after the token is
  # already on disk under the final name.
  $tmpFile = Join-Path $authDir ("aqua.env." + [System.IO.Path]::GetRandomFileName())
  try {
    [System.IO.File]::WriteAllText($tmpFile, (($lines -join "`n") + "`n"))
    if (-not $IsWindows) {
      & chmod 600 $tmpFile 2>$null | Out-Null
    }
    Move-Item -Path $tmpFile -Destination $authFile -Force
  } catch {
    Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
    Write-Error "Failed to write $authFile"
    return $false
  }

  if (-not $IsWindows) {
    & chmod 600 $authFile 2>$null | Out-Null
  } else {
    # Best-effort ACL restriction on Windows — mirrors the intent of 0600
    # (owner-only) even though there's no direct chmod equivalent.
    try {
      & icacls $authFile /inheritance:r /grant:r "$($env:USERNAME):(R,W)" 2>$null | Out-Null
    } catch {}
  }
  return $true
}

function NREDF_ClearAquaAuthConfig {
  $authFile = NREDF_AquaAuthConfigFile
  Remove-Item -Path $authFile -Force -ErrorAction SilentlyContinue
  Remove-Item Env:\AQUA_KEYRING_ENABLED -ErrorAction SilentlyContinue
  Remove-Item Env:\NREDF_AQUA_GITHUB_TOKEN_SETUP -ErrorAction SilentlyContinue
  Remove-Item Env:\AQUA_GITHUB_TOKEN -ErrorAction SilentlyContinue
  Remove-Item Env:\GITHUB_TOKEN -ErrorAction SilentlyContinue
}

# Core logic, returning bash's own convention (0 success, 1 failure,
# 2 unanswered) as an int — used both by the public nredf_aqua_token_setup
# (which discards the value, so a bare interactive call never prints a
# stray 0/1/2) and by NREDF_EnsureAquaGithubToken, which needs to branch on
# it.
function NREDF_AquaTokenSetupCore {
  param([string]$Action = '--set')

  # An explicit command always re-probes the keyring (it may have appeared
  # or disappeared since this session cached the earlier probe).
  $script:_NREDF_AQUA_KEYRING_PROBED = $null

  switch ($Action) {
    '--keyring' {
      if (-not (Get-Command aqua -ErrorAction SilentlyContinue)) {
        Write-Error 'aqua is not installed.'
        return 1
      }
      if (-not (NREDF_AquaKeyringAvailable)) {
        Write-Error 'System keyring is not available on this system.'
        Write-Error "Use 'nredf_aqua_token_setup --env' to store the token in local aqua.env instead."
        return 1
      }
      & aqua token set
      if ($LASTEXITCODE -ne 0) { return 1 }
      [void](NREDF_WriteAquaAuthConfig -Mode 'keyring')
      $env:AQUA_KEYRING_ENABLED = 'true'
      $env:NREDF_AQUA_GITHUB_TOKEN_SETUP = 'keyring'
      Write-Host "Stored aqua's GitHub token in the system keyring."
      return 0
    }
    '--env' {
      $timeoutSeconds = 30
      $parsedTimeout = 0
      if ($env:NREDF_PROMPT_TIMEOUT -and [int]::TryParse($env:NREDF_PROMPT_TIMEOUT, [ref]$parsedTimeout)) {
        $timeoutSeconds = $parsedTimeout
      }

      Write-Host -NoNewline 'Enter a GitHub access token: '
      $read = NREDF_AquaReadLineWithTimeout -TimeoutSeconds $timeoutSeconds -Mask
      if ($read.TimedOut) {
        Write-Error 'No token entered (timed out or no input); nothing recorded.'
        return 2
      }
      $token = $read.Value

      if ([string]::IsNullOrEmpty($token)) {
        Write-Error 'Error: Token cannot be empty.'
        return 1
      }

      [void](NREDF_WriteAquaAuthConfig -Mode 'env' -Token $token)
      $env:AQUA_GITHUB_TOKEN = $token
      $env:GITHUB_TOKEN = $token
      $env:NREDF_AQUA_GITHUB_TOKEN_SETUP = 'env'
      Remove-Item Env:\AQUA_KEYRING_ENABLED -ErrorAction SilentlyContinue
      $authFile = NREDF_AquaAuthConfigFile
      Write-Host "Stored aqua's GitHub token in $authFile (mode 0600)."
      return 0
    }
    '--set' {
      if (NREDF_AquaKeyringAvailable) {
        $result = NREDF_AquaTokenSetupCore -Action '--keyring'
        if ($result -eq 0) { return 0 }
        Write-Host 'Keyring setup failed. Falling back to file-based token storage...'
      }
      return (NREDF_AquaTokenSetupCore -Action '--env')
    }
    '--skip' {
      [void](NREDF_WriteAquaAuthConfig -Mode 'skip')
      Remove-Item Env:\AQUA_KEYRING_ENABLED -ErrorAction SilentlyContinue
      $env:NREDF_AQUA_GITHUB_TOKEN_SETUP = 'skip'
      Write-Host 'Skipping aqua GitHub token setup for now.'
      return 0
    }
    '--reset' {
      NREDF_ClearAquaAuthConfig
      Write-Host 'Reset aqua GitHub token preference.'
      return 0
    }
    '--status' {
      $authFile = NREDF_AquaAuthConfigFile
      Write-Host '=== aqua GitHub Token Status ==='
      if ($env:AQUA_GITHUB_TOKEN) {
        Write-Host "AQUA_GITHUB_TOKEN: set (length: $($env:AQUA_GITHUB_TOKEN.Length))"
      } else {
        Write-Host 'AQUA_GITHUB_TOKEN: unset'
      }
      if ($env:GITHUB_TOKEN) {
        Write-Host "GITHUB_TOKEN:      set (length: $($env:GITHUB_TOKEN.Length))"
      } else {
        Write-Host 'GITHUB_TOKEN:      unset'
      }
      $keyringState = if ($env:AQUA_KEYRING_ENABLED) { $env:AQUA_KEYRING_ENABLED } else { 'unset' }
      Write-Host "AQUA_KEYRING_ENABLED: $keyringState"
      $setupState = if ($env:NREDF_AQUA_GITHUB_TOKEN_SETUP) { $env:NREDF_AQUA_GITHUB_TOKEN_SETUP } else { 'unset' }
      Write-Host "Setup state:          $setupState"
      $existsNote = if (Test-Path $authFile) { '[exists]' } else { '[missing]' }
      Write-Host "Auth config file:     $authFile $existsNote"
      if (NREDF_AquaKeyringAvailable) {
        Write-Host 'System keyring:       available'
      } else {
        Write-Host 'System keyring:       unavailable (headless / WSL / no secret service)'
      }
      return 0
    }
    default {
      Write-Error 'Usage: nredf_aqua_token_setup [--set|--keyring|--env|--skip|--reset|--status]'
      return 1
    }
  }
}

function nredf_aqua_token_setup {
  <#
  .SYNOPSIS
      Configure how aqua authenticates to GitHub (keyring, local env file,
      or skip).
  .DESCRIPTION
      Mirrors nredf_aqua_token_setup from nredf_aqua.bash/.fish/.nu.
  .PARAMETER Action
      One of --set (default), --keyring, --env, --skip, --reset, --status.
  #>
  param(
    [Parameter(Position = 0)]
    [string]$Action = '--set'
  )
  [void](NREDF_AquaTokenSetupCore -Action $Action)
}

# Startup prompt — mirrors _nredf_ensure_aqua_github_token. Interactive-only
# (bails out immediately without recording anything when there's no usable
# console), and every prompt it drives is timed, so a pane nobody is
# watching (a restored multiplexer pane, an IDE-spawned terminal) can never
# block a shell startup, and never gets its silence recorded as "no".
function NREDF_EnsureAquaGithubToken {
  if (-not (NREDF_AquaHasInteractiveConsole)) { return }
  if (-not (Get-Command aqua -ErrorAction SilentlyContinue)) { return }
  if ($env:AQUA_GITHUB_TOKEN -or $env:GITHUB_TOKEN) { return }

  $setupState = $env:NREDF_AQUA_GITHUB_TOKEN_SETUP

  if ($env:AQUA_KEYRING_ENABLED -eq 'true' -or $setupState -eq 'keyring') {
    if (NREDF_AquaKeyringAvailable) {
      $env:AQUA_KEYRING_ENABLED = 'true'
      return
    }
    Remove-Item Env:\AQUA_KEYRING_ENABLED -ErrorAction SilentlyContinue
  }

  $authFile = NREDF_AquaAuthConfigFile
  if (-not $setupState -and (Test-Path $authFile)) {
    NREDF_ReadDotenv $authFile
    $setupState = $env:NREDF_AQUA_GITHUB_TOKEN_SETUP
  }

  if ($env:AQUA_GITHUB_TOKEN -or $env:GITHUB_TOKEN) { return }

  if ($env:AQUA_KEYRING_ENABLED -eq 'true' -or $setupState -eq 'keyring') {
    if (NREDF_AquaKeyringAvailable) {
      $env:AQUA_KEYRING_ENABLED = 'true'
      return
    }
    Remove-Item Env:\AQUA_KEYRING_ENABLED -ErrorAction SilentlyContinue
  }

  if ($setupState -eq 'skip') { return }

  if (NREDF_AquaKeyringAvailable) {
    $answer = NREDF_AquaPromptYesNo -Prompt 'No GitHub token configured for aqua. Store one in the system keyring now?'
    switch ($answer) {
      0 { }
      1 {
        [void](NREDF_AquaTokenSetupCore -Action '--skip')
        Write-Host "Run 'nredf_aqua_token_setup' later to configure aqua's GitHub token."
        return
      }
      default { return } # unanswered: ask again in a later shell
    }

    if ((NREDF_AquaTokenSetupCore -Action '--keyring') -ne 0) {
      $answer2 = NREDF_AquaPromptYesNo -Prompt "Keyring setup failed. Store token in $authFile (mode 0600) instead?"
      switch ($answer2) {
        0 { [void](NREDF_AquaTokenSetupCore -Action '--env') }
        1 {
          [void](NREDF_AquaTokenSetupCore -Action '--skip')
          Write-Host 'Skipping aqua GitHub token setup for now.'
        }
        default { } # unanswered: ask again in a later shell
      }
    }
  } else {
    Write-Host 'No GitHub token configured for aqua (system keyring unavailable on this system).' -ForegroundColor Yellow
    $answer = NREDF_AquaPromptYesNo -Prompt "Store token in $authFile (mode 0600) now?"
    switch ($answer) {
      0 { [void](NREDF_AquaTokenSetupCore -Action '--env') }
      1 {
        [void](NREDF_AquaTokenSetupCore -Action '--skip')
        Write-Host "Skipping aqua GitHub token setup for now. Run 'nredf_aqua_token_setup' later to configure."
      }
      default { } # unanswered: ask again in a later shell
    }
  }
}
