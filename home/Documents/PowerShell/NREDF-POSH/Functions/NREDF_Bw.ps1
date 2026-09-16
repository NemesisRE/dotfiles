# Bitwarden session management with OS keychain / biometric unlock
#
# Mirrors nredf_bw.bash for PowerShell on Windows, macOS, and Linux.
#
# Keychain backends
# - Windows : PasswordVault (Windows.Security.Credentials) — Windows Hello
# - macOS   : `security` (Keychain Services) — Touch ID
# - Linux   : kwallet-query (KDE) → secret-tool (GNOME) → $env:XDG_RUNTIME_DIR file
#
# Exported commands
# - bwu       Ensure BW_SESSION is set (keychain → fresh unlock), export it.
# - bwlock    Lock the vault, unset BW_SESSION, remove keychain entry.
#
# Internal helpers
# - NREDF_BwKeychainGet / Set / Del
# - NREDF_BwEnsureSession  (callable by other NREDF functions)

$script:_NREDF_BW_SERVICE = 'nredf.bw_session'
$script:_NREDF_BW_ACCOUNT = $env:USERNAME ?? $env:USER ?? (& id -un 2>$null)

# ---------------------------------------------------------------------------
# Internal: retrieve session token from the OS keychain
# Returns the token string, or $null on miss.
# ---------------------------------------------------------------------------
function NREDF_BwKeychainGet {
  if ($IsWindows) {
    try {
      $vault = [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime]::new()
      $cred = $vault.Retrieve($script:_NREDF_BW_SERVICE, $script:_NREDF_BW_ACCOUNT)
      $cred.RetrievePassword()
      return $cred.Password
    } catch {
      return $null
    }
  }

  if ($IsMacOS) {
    $token = & security find-generic-password `
      -s $script:_NREDF_BW_SERVICE `
      -a $script:_NREDF_BW_ACCOUNT `
      -w 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($token)) {
      return $token.Trim()
    }
    return $null
  }

  # Linux — try gdbus / kwallet-query first, then secret-tool, then fallback file
  if (Get-Command gdbus -ErrorAction SilentlyContinue) {
    $service = @('org.kde.kwalletd6', 'org.kde.kwalletd5') | Where-Object {
      $mod = "/modules/$($_ -replace '^.*\.','')"
      $out = & gdbus call --session --dest $_ --object-path $mod --method org.kde.KWallet.isEnabled 2>$null
      $out -match 'true'
    } | Select-Object -First 1

    if ($service) {
      $mod = "/modules/$($service -replace '^.*\.','')"
      $openRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.open kdewallet 0 'nredf' 2>$null
      $handle = ($openRes -replace '\D', '')
      if ($handle) {
        foreach ($folder in @('nredf', 'Passwords')) {
          $raw = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.readPassword [int64]$handle $folder $script:_NREDF_BW_SERVICE 'nredf' 2>$null
          if ($raw -match "\('([^']*)',\)") {
            $token = $Matches[1]
            if (-not [string]::IsNullOrEmpty($token)) { return $token.Trim() }
          }
        }
      }
    }
  }

  if (Get-Command kwallet-query -ErrorAction SilentlyContinue) {
    # Try nredf folder first, then fallback to standard Passwords folder
    $token = & kwallet-query --read-password $script:_NREDF_BW_SERVICE --folder nredf kdewallet 2>$null
    if (-not ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($token))) {
      $token = & kwallet-query --read-password $script:_NREDF_BW_SERVICE --folder Passwords kdewallet 2>$null
    }
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($token)) {
      return $token.Trim()
    }
  }

  if (Get-Command secret-tool -ErrorAction SilentlyContinue) {
    $token = & secret-tool lookup service $script:_NREDF_BW_SERVICE username $script:_NREDF_BW_ACCOUNT 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($token)) {
      return $token.Trim()
    }
  }

  # Fallback: XDG_RUNTIME_DIR file
  $runtimeDir = $env:XDG_RUNTIME_DIR ?? '/tmp'
  $fallbackFile = Join-Path $runtimeDir 'nredf_bw_session'
  if (Test-Path $fallbackFile) {
    return (Get-Content $fallbackFile -Raw).Trim()
  }

  return $null
}

# ---------------------------------------------------------------------------
# Internal: store session token in the OS keychain
# ---------------------------------------------------------------------------
function NREDF_BwKeychainSet {
  param([string]$Token)

  if ($IsWindows) {
    try {
      $vault = [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime]::new()
      # Remove existing entry to avoid duplicates
      try { $vault.Remove($vault.Retrieve($script:_NREDF_BW_SERVICE, $script:_NREDF_BW_ACCOUNT)) } catch {}
      $cred = [Windows.Security.Credentials.PasswordCredential]::new(
        $script:_NREDF_BW_SERVICE, $script:_NREDF_BW_ACCOUNT, $Token)
      $vault.Add($cred)
    } catch {
      Write-Warning "NREDF_BwKeychainSet: could not save to PasswordVault: $_"
    }
    return
  }

  if ($IsMacOS) {
    & security delete-generic-password `
      -s $script:_NREDF_BW_SERVICE `
      -a $script:_NREDF_BW_ACCOUNT 2>$null | Out-Null
    & security add-generic-password `
      -s $script:_NREDF_BW_SERVICE `
      -a $script:_NREDF_BW_ACCOUNT `
      -w $Token `
      -U 2>$null | Out-Null
    return
  }

  # Linux
  if (Get-Command gdbus -ErrorAction SilentlyContinue) {
    $service = @('org.kde.kwalletd6', 'org.kde.kwalletd5') | Where-Object {
      $mod = "/modules/$($_ -replace '^.*\.','')"
      $out = & gdbus call --session --dest $_ --object-path $mod --method org.kde.KWallet.isEnabled 2>$null
      $out -match 'true'
    } | Select-Object -First 1

    if ($service) {
      $mod = "/modules/$($service -replace '^.*\.','')"
      $openRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.open kdewallet 0 'nredf' 2>$null
      $handle = ($openRes -replace '\D', '')
      if ($handle) {
        $hasFolder = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.hasFolder [int64]$handle 'nredf' 2>$null
        if ($hasFolder -notmatch 'true') {
          & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.createFolder [int64]$handle 'nredf' 2>$null | Out-Null
        }
        $writeRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.writePassword [int64]$handle 'nredf' $script:_NREDF_BW_SERVICE $Token 'nredf' 2>$null
        if ($writeRes -match '\(0,\)') { return }

        $writeRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.writePassword [int64]$handle 'Passwords' $script:_NREDF_BW_SERVICE $Token 'nredf' 2>$null
        if ($writeRes -match '\(0,\)') { return }
      }
    }
  }

  if (Get-Command kwallet-query -ErrorAction SilentlyContinue) {
    $Token | & kwallet-query --write-password $script:_NREDF_BW_SERVICE --folder nredf kdewallet 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }

    # Fallback to standard Passwords folder
    $Token | & kwallet-query --write-password $script:_NREDF_BW_SERVICE --folder Passwords kdewallet 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
  }

  if (Get-Command secret-tool -ErrorAction SilentlyContinue) {
    $Token | & secret-tool store --label 'NREDF Bitwarden session' `
      service $script:_NREDF_BW_SERVICE `
      username $script:_NREDF_BW_ACCOUNT 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
  }

  # Fallback file
  $runtimeDir = $env:XDG_RUNTIME_DIR ?? '/tmp'
  $fallbackFile = Join-Path $runtimeDir 'nredf_bw_session'
  Set-Content -Path $fallbackFile -Value $Token -NoNewline
  if (-not $IsWindows) {
    & chmod 600 $fallbackFile 2>$null | Out-Null
  }
}

# ---------------------------------------------------------------------------
# Internal: remove session token from the OS keychain
# ---------------------------------------------------------------------------
function NREDF_BwKeychainDel {
  if ($IsWindows) {
    try {
      $vault = [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime]::new()
      try { $vault.Remove($vault.Retrieve($script:_NREDF_BW_SERVICE, $script:_NREDF_BW_ACCOUNT)) } catch {}
    } catch {}
    return
  }

  if ($IsMacOS) {
    & security delete-generic-password `
      -s $script:_NREDF_BW_SERVICE `
      -a $script:_NREDF_BW_ACCOUNT 2>$null | Out-Null
    return
  }

  # Linux
  if (Get-Command gdbus -ErrorAction SilentlyContinue) {
    $service = @('org.kde.kwalletd6', 'org.kde.kwalletd5') | Where-Object {
      $mod = "/modules/$($_ -replace '^.*\.','')"
      $out = & gdbus call --session --dest $_ --object-path $mod --method org.kde.KWallet.isEnabled 2>$null
      $out -match 'true'
    } | Select-Object -First 1

    if ($service) {
      $mod = "/modules/$($service -replace '^.*\.','')"
      $openRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.open kdewallet 0 'nredf' 2>$null
      $handle = ($openRes -replace '\D', '')
      if ($handle) {
        & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.removeEntry [int64]$handle 'nredf' $script:_NREDF_BW_SERVICE 'nredf' 2>$null | Out-Null
        & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.removeEntry [int64]$handle 'Passwords' $script:_NREDF_BW_SERVICE 'nredf' 2>$null | Out-Null
      }
    }
  }

  if (Get-Command kwallet-query -ErrorAction SilentlyContinue) {
    & kwallet-query --delete-entry $script:_NREDF_BW_SERVICE --folder nredf kdewallet 2>$null | Out-Null
    & kwallet-query --delete-entry $script:_NREDF_BW_SERVICE --folder Passwords kdewallet 2>$null | Out-Null
  }
  if (Get-Command secret-tool -ErrorAction SilentlyContinue) {
    & secret-tool clear service $script:_NREDF_BW_SERVICE username $script:_NREDF_BW_ACCOUNT 2>$null | Out-Null
  }
  $runtimeDir = $env:XDG_RUNTIME_DIR ?? '/tmp'
  Remove-Item (Join-Path $runtimeDir 'nredf_bw_session') -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Internal: perform a fresh bw login/unlock and persist the session
# ---------------------------------------------------------------------------
function NREDF_BwDoUnlock {
  if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Error 'Bitwarden CLI (bw) is not installed. Run: aqua install'
    return $false
  }

  $loginCheck = & bw login --check 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'Bitwarden: not logged in — running bw login' -ForegroundColor Yellow
    $session = & bw login --raw
  } else {
    Write-Host 'Bitwarden: vault locked — running bw unlock' -ForegroundColor Yellow
    $session = & bw unlock --raw
  }

  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($session)) {
    Write-Error 'Bitwarden: unlock returned an empty session token'
    return $false
  }

  NREDF_BwKeychainSet -Token $session
  $env:BW_SESSION = $session
  return $true
}

# ---------------------------------------------------------------------------
# Public: NREDF_BwEnsureSession
# Ensures $env:BW_SESSION is set and valid. Returns $true/$false.
# ---------------------------------------------------------------------------
function NREDF_BwEnsureSession {
  if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Error 'Bitwarden CLI (bw) is not installed. Run: aqua install'
    return $false
  }

  # 1. Validate existing env session
  if (-not [string]::IsNullOrEmpty($env:BW_SESSION)) {
    & bw unlock --check 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }
    $env:BW_SESSION = $null
  }

  # 2. Try keychain
  $cached = NREDF_BwKeychainGet
  if (-not [string]::IsNullOrEmpty($cached)) {
    $env:BW_SESSION = $cached
    & bw unlock --check 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }
    # Stale — clean up and re-unlock
    $env:BW_SESSION = $null
    NREDF_BwKeychainDel
  }

  # 3. Fresh unlock
  return NREDF_BwDoUnlock
}

# ---------------------------------------------------------------------------
# Public: bwu — Bitwarden Unlock
# ---------------------------------------------------------------------------
function bwu {
  <#
  .SYNOPSIS
      Unlock the Bitwarden vault and export BW_SESSION (via OS keychain / biometrics).
  #>
  if (NREDF_BwEnsureSession) {
    $green = if ($PSStyle) { $PSStyle.Foreground.Green } else { "`e[1;32m" }
    $reset = if ($PSStyle) { $PSStyle.Reset } else { "`e[0m" }
    Write-Host "${green}✔ Bitwarden vault unlocked${reset}"
  } else {
    $red = if ($PSStyle) { $PSStyle.Foreground.BrightRed } else { "`e[1;31m" }
    $reset = if ($PSStyle) { $PSStyle.Reset } else { "`e[0m" }
    Write-Host "${red}✘ Failed to unlock Bitwarden vault${reset}"
    return 1
  }
}

# ---------------------------------------------------------------------------
# Public: bwlock — lock the vault and wipe the keychain entry
# ---------------------------------------------------------------------------
function bwlock {
  <#
  .SYNOPSIS
      Lock the Bitwarden vault, unset BW_SESSION, and remove the keychain entry.
  #>
  NREDF_BwKeychainDel

  if (-not [string]::IsNullOrEmpty($env:BW_SESSION)) {
    & bw lock 2>$null | Out-Null
    $env:BW_SESSION = $null
  }

  $yellow = if ($PSStyle) { $PSStyle.Foreground.Yellow } else { "`e[1;33m" }
  $reset = if ($PSStyle) { $PSStyle.Reset } else { "`e[0m" }
  Write-Host "${yellow}⚿ Bitwarden vault locked and session cleared${reset}"
}

# ---------------------------------------------------------------------------
# Public: chezmoi wrapper
# Pre-loads BW_SESSION from the keychain so chezmoi template functions like
# {{ bitwarden "item" "..." }} never prompt for the master password.
# Only activates when bw is available and not in CI / bootstrap context.
#
# NOTE: stderr is intentionally NOT suppressed — bw unlock writes its
# "? Master password:" prompt to stderr and must be visible to the user.
# ---------------------------------------------------------------------------
function chezmoi {
  <#
  .SYNOPSIS
      Wrapper around chezmoi that pre-loads BW_SESSION from the OS keychain.
  #>
  if ((Get-Command bw -ErrorAction SilentlyContinue) -and
      $env:NREDF_NO_BOOTSTRAP -ne '1' -and
      $env:CI -ne 'true') {
    NREDF_BwEnsureSession | Out-Null
  }
  & (Get-Command chezmoi -CommandType Application -ErrorAction Stop) @args
}
