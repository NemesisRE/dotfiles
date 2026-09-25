# chezmoi-managed pwsh function file.
# -----------------------------------------------------------------------------
# SSH wrapper with Bitwarden / 1Password TOTP and sshpass
#
# Port of common/functions/nredf_ssh.bash (also nredf_ssh.fish/.nu) — see that
# file for the full design writeup and SSH config example
# (SetEnv TOTP_ITEMID=<id>).
#
# Overview
# - `nredf_ssh` is a drop-in replacement for `ssh` that supplies a
#   Time-based One-Time Password (TOTP) via sshpass when the destination (or
#   its first ProxyJump hop) is configured with `SetEnv TOTP_ITEMID=<id>`.
# - Falls back to plain ssh whenever no TOTP_ITEMID is found, whenever the
#   configured provider (bw/op) is unavailable, or — pwsh-specific — when
#   `sshpass` itself isn't installed (the common case on Windows: sshpass has
#   no first-party Windows build), with a stderr note rather than a hard
#   failure.
#
# Requirements
# - ssh, sshpass (optional; TOTP auto-fill is simply skipped without it)
# - Bitwarden CLI (`bw`) or 1Password CLI (`op`) if TOTP is used
#
# Exit codes
# - Mirrors the exit code of the underlying ssh/sshpass invocation via
#   $LASTEXITCODE; nothing is written to the success/output stream so
#   `nredf_ssh host` never prints a stray trailing value.
# -----------------------------------------------------------------------------

# Finds the destination in an ssh argument list, and the `-F` config file (if
# any). Mirrors ssh's own getopt: option clusters (-4vA) are skipped, and so
# is the value of every option letter that takes one, attached (-p2222) or
# separate (-p 2222). A `--` ends option parsing. The first non-option is the
# destination, returned as given (`ssh -G` parses [user@]host and ssh://
# URIs itself, and needs the user@ part to evaluate `Match user` blocks
# correctly — never strip it here).
function NREDF_SshDestination {
  param([string[]]$Arguments)

  $dest = ''
  $cfgFile = ''
  $want = ''
  $endOpts = $false
  # Option letters that take a value (ssh's own getopt string, minus the
  # ones that never appear attached-or-separate the way ssh itself parses
  # them): B b c D E e F I i J L l m O o p P Q R S W w.
  $valueOptChars = 'BbcDEeFIiJLlmOoPpQRSWw'

  foreach ($arg in $Arguments) {
    if ($want) {
      if ($want -eq 'F') { $cfgFile = $arg }
      $want = ''
      continue
    }
    if (-not $endOpts -and $arg -eq '--') {
      $endOpts = $true
      continue
    }
    if (-not $endOpts -and $arg.Length -ge 2 -and $arg[0] -eq '-') {
      for ($i = 1; $i -lt $arg.Length; $i++) {
        $c = $arg[$i]
        if ($valueOptChars.IndexOf([string]$c) -ge 0) {
          if ($i + 1 -lt $arg.Length) {
            if ($c -eq 'F') { $cfgFile = $arg.Substring($i + 1) }
          } else {
            $want = [string]$c
          }
          break
        }
      }
      continue
    }
    $dest = $arg
    break
  }

  if ([string]::IsNullOrEmpty($dest)) { return $null }

  [PSCustomObject]@{
    CfgFile     = $cfgFile
    Destination = $dest
  }
}

# Extracts TOTP_ITEMID from `ssh -G` output.
function NREDF_SshParseTotp {
  param([string]$Config)

  if ([string]::IsNullOrEmpty($Config)) { return '' }

  foreach ($line in ($Config -split "`n")) {
    $fields = $line.Trim() -split '\s+'
    if ($fields.Count -lt 1) { continue }
    if ($fields[0].ToLowerInvariant() -eq 'setenv') {
      for ($i = 1; $i -lt $fields.Count; $i++) {
        $kv = $fields[$i] -split '=', 2
        if ($kv.Count -eq 2 -and $kv[0] -eq 'TOTP_ITEMID') {
          return $kv[1]
        }
      }
    }
  }
  return ''
}

# Unlocks Bitwarden (via NREDF_BwEnsureSession, so BW_SESSION is restored
# from the OS keychain / persisted there — see NREDF_Bw.ps1) and returns a
# TOTP code for the given item.
function NREDF_SshpassBitwardenTotp {
  param([string]$ItemId)

  if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Error 'Bitwarden CLI (bw) is not installed. Run: aqua install'
    return ''
  }

  if (-not (NREDF_BwEnsureSession -Force)) {
    Write-Error 'Bitwarden: failed to unlock vault'
    return ''
  }

  # Only this bw invocation's output is captured — the unlock above ran
  # directly in this scope (not inside a subshell), so its BW_SESSION
  # persists for the next nredf_ssh call.
  $totp = (& bw get totp $ItemId --raw)
  if ($LASTEXITCODE -ne 0) { return '' }
  return $totp.Trim()
}

function NREDF_SshpassOnePasswordTotp {
  param([string]$ItemId)

  if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
    Write-Error '1Password CLI (op) is not installed. Run: aqua install'
    return ''
  }

  $totp = (& op item get $ItemId --otp 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($totp)) {
    Write-Error "Failed to retrieve TOTP from 1Password for item: $ItemId"
    return ''
  }
  return $totp.Trim()
}

function NREDF_SshpassTotp {
  param([string[]]$Arguments)

  if (-not $Arguments -or $Arguments.Count -eq 0) {
    Write-Error 'Usage: nredf_ssh [ssh_options...] <destination> [command...]'
    return
  }

  $parsed = NREDF_SshDestination -Arguments $Arguments
  # No destination (e.g. `nredf_ssh -V`): nothing to look up.
  if (-not $parsed) {
    & ssh @Arguments
    return
  }

  $gOpts = @()
  if ($parsed.CfgFile) { $gOpts = @('-F', $parsed.CfgFile) }

  $hostCfg = (& ssh @gOpts -G $parsed.Destination 2>$null | Out-String)
  if ($LASTEXITCODE -ne 0) {
    & ssh @Arguments
    return
  }

  $totpItemId = ''
  $proxyjump = ''
  foreach ($line in ($hostCfg -split "`n")) {
    $fields = $line.Trim() -split '\s+'
    if ($fields.Count -ge 2 -and $fields[0].ToLowerInvariant() -eq 'proxyjump' -and $fields[1] -ne 'none') {
      $proxyjump = $fields[1]
      break
    }
  }

  if ($proxyjump) {
    # First hop of a (possibly comma-separated) ProxyJump chain, minus any
    # user@ prefix or :port suffix — only the first hop is inspected, same
    # as bash.
    $pjFirst = ($proxyjump -split ',')[0]
    $pjFirst = $pjFirst -replace '^[^@]*@', ''
    $pjFirst = $pjFirst -replace ':.*', ''
    if ($pjFirst) {
      $pjCfg = (& ssh @gOpts -G $pjFirst 2>$null | Out-String)
      if ($LASTEXITCODE -eq 0) {
        $totpItemId = NREDF_SshParseTotp -Config $pjCfg
      }
    }
  }

  if (-not $totpItemId) {
    $totpItemId = NREDF_SshParseTotp -Config $hostCfg
  }

  if (-not $totpItemId) {
    & ssh @Arguments
    return
  }

  $totpProvider = $env:NREDF_SHELL_SSH_TOTP_PROVIDER
  if (-not $totpProvider) { $totpProvider = '' }
  $totpProvider = $totpProvider -replace '^#', ''

  if (-not $totpProvider) {
    if (Get-Command bw -ErrorAction SilentlyContinue) {
      $totpProvider = 'bitwarden'
    } elseif (Get-Command op -ErrorAction SilentlyContinue) {
      $totpProvider = '1password'
    }
  }

  $itemTotp = ''
  switch ($totpProvider) {
    'bitwarden' { $itemTotp = NREDF_SshpassBitwardenTotp -ItemId $totpItemId }
    { $_ -in @('1password', 'onepassword', 'op') } { $itemTotp = NREDF_SshpassOnePasswordTotp -ItemId $totpItemId }
  }

  if (-not $itemTotp) {
    & ssh @Arguments
    return
  }

  # sshpass has no first-party Windows build — fall back to plain ssh with a
  # stderr note instead of failing outright (TOTP just won't be auto-filled).
  if (-not (Get-Command sshpass -ErrorAction SilentlyContinue)) {
    Write-Warning 'sshpass is not installed (no build for this platform?); falling back to plain ssh — TOTP will not be auto-filled.'
    & ssh @Arguments
    return
  }

  # Temporarily clear SSH_ASKPASS/DISPLAY for this invocation only, so a GUI
  # password prompt doesn't interfere with sshpass, which needs to handle
  # password input directly via stdin/the controlling terminal. Restored
  # afterwards rather than left cleared for the rest of the session.
  $savedAskpass = $env:SSH_ASKPASS
  $savedAskpassRequire = $env:SSH_ASKPASS_REQUIRE
  $savedDisplay = $env:DISPLAY
  try {
    $env:SSH_ASKPASS = ''
    $env:SSH_ASKPASS_REQUIRE = ''
    $env:DISPLAY = ''
    & sshpass -p $itemTotp ssh @Arguments
  } finally {
    $env:SSH_ASKPASS = $savedAskpass
    $env:SSH_ASKPASS_REQUIRE = $savedAskpassRequire
    $env:DISPLAY = $savedDisplay
  }
}

function nredf_ssh {
  <#
  .SYNOPSIS
      SSH wrapper with Bitwarden / 1Password TOTP and sshpass.
  .DESCRIPTION
      Mirrors nredf_ssh.bash/.fish/.nu for PowerShell. Looks up a
      SetEnv TOTP_ITEMID=<id> via `ssh -G` (including the first ProxyJump
      hop) and supplies the TOTP code via sshpass. Falls back to plain ssh
      when there's no TOTP configuration, the configured provider (bw/op)
      isn't available, or sshpass itself isn't installed.
  .EXAMPLE
      nredf_ssh myhost
  .EXAMPLE
      nredf_ssh -p 2222 -i ~/.ssh/id_ed25519 user@target uptime
  #>
  NREDF_SshpassTotp -Arguments $args
}
