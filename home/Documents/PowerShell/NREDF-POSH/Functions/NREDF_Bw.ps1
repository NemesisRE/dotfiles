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
# - bwu                    Ensure BW_SESSION is set (keychain → fresh unlock), export it.
# - bwlock                 Lock the vault, unset BW_SESSION, remove keychain entry.
# - NREDF_BwRestoreSession Restores BW_SESSION from keychain if available (startup).
#
# Internal helpers
# - NREDF_BwKeychainGet / Set / Del
# - NREDF_BwEnsureSession  (callable by other NREDF functions)

$script:_NREDF_BW_SERVICE = 'nredf.bw_session'
$script:_NREDF_BW_ACCOUNT = $env:USERNAME ?? $env:USER ?? (& id -un 2>$null)
$script:_NREDF_BW_MARKER = Join-Path ($env:XDG_RUNTIME_DIR ?? [System.IO.Path]::GetTempPath()) "nredf_bw_$($script:_NREDF_BW_ACCOUNT).active"

# ---------------------------------------------------------------------------
# Internal: retrieve session token from the OS keychain
# Returns the token string, or $null on miss.
# ---------------------------------------------------------------------------
function NREDF_BwKeychainGet {
  if ($IsWindows) {
    foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session', 'BW_SESSION')) {
      try {
        $vault = [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime]::new()
        $cred = $vault.Retrieve($key, $script:_NREDF_BW_ACCOUNT)
        $cred.RetrievePassword()
        if (-not [string]::IsNullOrEmpty($cred.Password)) { return $cred.Password }
      } catch {}
    }
    return $null
  }

  if ($IsMacOS) {
    foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session', 'BW_SESSION')) {
      $token = & security find-generic-password `
        -s $key `
        -a $script:_NREDF_BW_ACCOUNT `
        -w 2>$null
      if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($token)) {
        return $token.Trim()
      }
    }
    return $null
  }

  # Linux — try gdbus / kwallet-query first, then secret-tool, then fallback file
  if (Get-Command gdbus -ErrorAction SilentlyContinue) {
    $service = @('org.kde.kwalletd6', 'org.kde.kwalletd5', 'org.kde.kwalletd') | Where-Object {
      $mod = "/modules/$($_ -replace '^.*\.','')"
      $out = & gdbus call --session --dest $_ --object-path $mod --method org.kde.KWallet.isEnabled 2>$null
      $out -match 'true'
    } | Select-Object -First 1

    if (-not $service) {
      $service = @('org.kde.kwalletd6', 'org.kde.kwalletd5', 'org.kde.kwalletd') | Where-Object {
        $mod = "/modules/$($_ -replace '^.*\.','')"
        $null -ne (& gdbus call --session --dest $_ --object-path $mod --method org.freedesktop.DBus.Peer.Ping 2>$null)
      } | Select-Object -First 1
    }

    if ($service) {
      $mod = "/modules/$($service -replace '^.*\.','')"
      $wallets = [System.Collections.Generic.List[string]]::new()
      $wallets.Add('kdewallet')
      foreach ($m in @('networkWallet', 'localWallet')) {
        $wRes = & gdbus call --session --dest $service --object-path $mod --method "org.kde.KWallet.$m" 2>$null
        if ($wRes -match "'([^']+)'" -and -not [string]::IsNullOrEmpty($Matches[1])) {
          if (-not $wallets.Contains($Matches[1])) { $wallets.Add($Matches[1]) }
        }
      }

      foreach ($w in $wallets) {
        $openRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.open $w 0 'nredf' 2>$null
        if ($openRes -match '\((?:[a-zA-Z0-9]+\s+)?(-?\d+)') {
          $handle = [int64]$Matches[1]
          if ($handle -ge 0) {
            $folders = [System.Collections.Generic.List[string]]::new()
            $folders.Add('Passwords')
            $folders.Add('nredf')
            $fRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.folderList $handle 2>$null
            if ($fRes -match "\[([^\]]*)\]") {
              $Matches[1] -split ',' | ForEach-Object {
                $f = $_.Trim(" '`"")
                if (-not [string]::IsNullOrEmpty($f) -and -not $folders.Contains($f)) { $folders.Add($f) }
              }
            }

            foreach ($folder in $folders) {
              foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session', 'BW_SESSION', 'bitwarden', 'Bitwarden', 'bw')) {
                $raw = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.readPassword $handle $folder $key 'nredf' 2>$null
                if ($raw -match "'([^']+)'") {
                  $token = $Matches[1]
                  if (-not [string]::IsNullOrEmpty($token)) { return $token.Trim() }
                }
              }
            }
          }
        }
      }
    }
  }

  if (Get-Command kwallet-query -ErrorAction SilentlyContinue) {
    foreach ($folder in @('Passwords', 'nredf')) {
      foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session', 'BW_SESSION', 'bitwarden', 'Bitwarden', 'bw')) {
        $token = & kwallet-query --read-password $key --folder $folder kdewallet 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($token) -and $token -notmatch 'kann nicht gelesen werden|cannot be read') {
          return $token.Trim()
        }
      }
    }
  }

  if (Get-Command secret-tool -ErrorAction SilentlyContinue) {
    foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session', 'BW_SESSION', 'bitwarden', 'Bitwarden', 'bw')) {
      $token = & secret-tool lookup service $key username $script:_NREDF_BW_ACCOUNT 2>$null
      if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($token)) { return $token.Trim() }
      $token = & secret-tool lookup service $key 2>$null
      if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($token)) { return $token.Trim() }
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

  try { [System.IO.File]::WriteAllBytes($script:_NREDF_BW_MARKER, [byte[]]@()) } catch {}

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
    $service = @('org.kde.kwalletd6', 'org.kde.kwalletd5', 'org.kde.kwalletd') | Where-Object {
      $mod = "/modules/$($_ -replace '^.*\.','')"
      $out = & gdbus call --session --dest $_ --object-path $mod --method org.kde.KWallet.isEnabled 2>$null
      $out -match 'true'
    } | Select-Object -First 1

    if (-not $service) {
      $service = @('org.kde.kwalletd6', 'org.kde.kwalletd5', 'org.kde.kwalletd') | Where-Object {
        $mod = "/modules/$($_ -replace '^.*\.','')"
        $null -ne (& gdbus call --session --dest $_ --object-path $mod --method org.freedesktop.DBus.Peer.Ping 2>$null)
      } | Select-Object -First 1
    }

    if ($service) {
      $mod = "/modules/$($service -replace '^.*\.','')"
      $openRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.open kdewallet 0 'nredf' 2>$null
      $handle = ($openRes -replace '\D', '')
      if ($handle) {
        # Try Passwords folder first (standard KWallet), fallback to nredf
        $writeRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.writePassword [int64]$handle 'Passwords' $script:_NREDF_BW_SERVICE $Token 'nredf' 2>$null
        if ($writeRes -match '\(0,\)') { return }

        $hasFolder = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.hasFolder [int64]$handle 'nredf' 2>$null
        if ($hasFolder -notmatch 'true') {
          & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.createFolder [int64]$handle 'nredf' 2>$null | Out-Null
        }
        $writeRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.writePassword [int64]$handle 'nredf' $script:_NREDF_BW_SERVICE $Token 'nredf' 2>$null
        if ($writeRes -match '\(0,\)') { return }
      }
    }
  }

  if (Get-Command kwallet-query -ErrorAction SilentlyContinue) {
    $Token | & kwallet-query --write-password $script:_NREDF_BW_SERVICE --folder Passwords kdewallet 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }

    $Token | & kwallet-query --write-password $script:_NREDF_BW_SERVICE --folder nredf kdewallet 2>$null | Out-Null
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
  try { if ([System.IO.File]::Exists($script:_NREDF_BW_MARKER)) { [System.IO.File]::Delete($script:_NREDF_BW_MARKER) } } catch {}

  if ($IsWindows) {
    foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session', 'BW_SESSION')) {
      try {
        $vault = [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime]::new()
        try { $vault.Remove($vault.Retrieve($key, $script:_NREDF_BW_ACCOUNT)) } catch {}
      } catch {}
    }
    return
  }

  if ($IsMacOS) {
    foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session', 'BW_SESSION')) {
      & security delete-generic-password `
        -s $key `
        -a $script:_NREDF_BW_ACCOUNT 2>$null | Out-Null
    }
    return
  }

  # Linux
  if (Get-Command gdbus -ErrorAction SilentlyContinue) {
    $service = @('org.kde.kwalletd6', 'org.kde.kwalletd5', 'org.kde.kwalletd') | Where-Object {
      $mod = "/modules/$($_ -replace '^.*\.','')"
      $out = & gdbus call --session --dest $_ --object-path $mod --method org.kde.KWallet.isEnabled 2>$null
      $out -match 'true'
    } | Select-Object -First 1

    if (-not $service) {
      $service = @('org.kde.kwalletd6', 'org.kde.kwalletd5', 'org.kde.kwalletd') | Where-Object {
        $mod = "/modules/$($_ -replace '^.*\.','')"
        $null -ne (& gdbus call --session --dest $_ --object-path $mod --method org.freedesktop.DBus.Peer.Ping 2>$null)
      } | Select-Object -First 1
    }

    if ($service) {
      $mod = "/modules/$($service -replace '^.*\.','')"
      $openRes = & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.open kdewallet 0 'nredf' 2>$null
      $handle = ($openRes -replace '\D', '')
      if ($handle) {
        foreach ($folder in @('Passwords', 'nredf')) {
          foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session', 'BW_SESSION')) {
            & gdbus call --session --dest $service --object-path $mod --method org.kde.KWallet.removeEntry [int64]$handle $folder $key 'nredf' 2>$null | Out-Null
          }
        }
      }
    }
  }

  if (Get-Command kwallet-query -ErrorAction SilentlyContinue) {
    foreach ($folder in @('Passwords', 'nredf')) {
      foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session', 'BW_SESSION')) {
        & kwallet-query --delete-entry $key --folder $folder kdewallet 2>$null | Out-Null
      }
    }
  }
  if (Get-Command secret-tool -ErrorAction SilentlyContinue) {
    foreach ($key in @($script:_NREDF_BW_SERVICE, 'bw_session')) {
      & secret-tool clear service $key username $script:_NREDF_BW_ACCOUNT 2>$null | Out-Null
    }
  }
  $runtimeDir = $env:XDG_RUNTIME_DIR ?? '/tmp'
  Remove-Item (Join-Path $runtimeDir 'nredf_bw_session') -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Internal: detect whether any Bitwarden secret is actually used in config
# Returns $true if Bitwarden is configured in chezmoi.toml or chezmoidata, $false otherwise.
# ---------------------------------------------------------------------------
function NREDF_BwSecretConfigured {
  $configDir = Join-Path ($env:XDG_CONFIG_HOME ?? (Join-Path $HOME '.config')) 'chezmoi'
  $candidatePaths = @(
    (Join-Path $configDir 'chezmoi.toml'),
    (Join-Path $configDir 'chezmoi.yaml'),
    (Join-Path $configDir 'chezmoi.json'),
    (Join-Path $HOME '.config/chezmoi/chezmoi.toml'),
    (Join-Path $HOME '.config/chezmoi/chezmoi.yaml'),
    (Join-Path $HOME '.chezmoi.toml'),
    (Join-Path $HOME '.chezmoi.yaml')
  ) | Select-Object -Unique

  foreach ($path in $candidatePaths) {
    if (Test-Path $path) {
      $content = Get-Content $path -Raw
      if ($content -match '(?m)^\s*\[(data\.)?bitwarden\]') { return $true }
      if ($content -match '["''\s](?:bitwarden|bw):') { return $true }
      if ($content -match '\{\{\s*(\(\s*)?bitwarden\s') { return $true }
    }
  }

  $sourceDir = $env:NREDF_DOT_PATH ?? (Join-Path $HOME '.local/share/chezmoi')
  $secretsDir = Join-Path $sourceDir 'home/.chezmoidata'
  if (Test-Path $secretsDir) {
    $matched = Get-ChildItem -Path $secretsDir -Filter '*.yaml' -ErrorAction SilentlyContinue |
      Select-String -Pattern '["'']?(?:bitwarden|bw):' -SimpleMatch:$false
    if ($matched) { return $true }
  }

  $singleData = Join-Path $sourceDir 'home/.chezmoidata.yaml'
  if (Test-Path $singleData) {
    if ((Get-Content $singleData -Raw) -match '["'']?(?:bitwarden|bw):') { return $true }
  }

  return $false
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
# Public: NREDF_BwRestoreSession
# Restores $env:BW_SESSION from the OS keychain if not already set.
# Fast and non-blocking: never prompts, suitable for shell startup.
# ---------------------------------------------------------------------------
function NREDF_BwRestoreSession {
  <#
  .SYNOPSIS
      Restores $env:BW_SESSION from the OS keychain if not already set.
      Fast and non-blocking: never prompts, suitable for shell startup.
  #>
  if (-not [string]::IsNullOrEmpty($env:BW_SESSION)) { return }

  $cached = NREDF_BwKeychainGet
  if (-not [string]::IsNullOrEmpty($cached)) {
    $env:BW_SESSION = $cached
    try { [System.IO.File]::WriteAllBytes($script:_NREDF_BW_MARKER, [byte[]]@()) } catch {}
  }
}

# ---------------------------------------------------------------------------
# Public: NREDF_BwEnsureSession
# Ensures $env:BW_SESSION is set and valid. Returns $true/$false.
# If not forced, only prompts/unlocks if a Bitwarden secret is configured.
# ---------------------------------------------------------------------------
function NREDF_BwEnsureSession {
  [CmdletBinding()]
  param([switch]$Force)

  if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Error 'Bitwarden CLI (bw) is not installed. Run: aqua install'
    return $false
  }

  # 1. Validate existing env session
  if (-not [string]::IsNullOrEmpty($env:BW_SESSION)) {
    & bw unlock --check 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      NREDF_BwKeychainSet -Token $env:BW_SESSION
      return $true
    }
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

  # 3. Only do a fresh unlock if explicitly forced (e.g. bwu) or if a Bitwarden secret is configured
  if (-not $Force -and -not (NREDF_BwSecretConfigured)) {
    return $true
  }

  # 4. Fresh unlock
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
  # 1. If BW_SESSION is already set and valid in current shell, sync and return
  if (-not [string]::IsNullOrEmpty($env:BW_SESSION)) {
    & bw unlock --check 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      NREDF_BwKeychainSet -Token $env:BW_SESSION
      $green = if ($PSStyle) { $PSStyle.Foreground.Green } else { "`e[1;32m" }
      $reset = if ($PSStyle) { $PSStyle.Reset } else { "`e[0m" }
      Write-Host "${green}✔ Bitwarden vault already unlocked (keychain synchronized)${reset}"
      return
    }
  }

  # 2. Check keychain first — if valid, restore without prompting
  $cached = NREDF_BwKeychainGet
  if (-not [string]::IsNullOrEmpty($cached)) {
    $env:BW_SESSION = $cached
    & bw unlock --check 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      NREDF_BwKeychainSet -Token $env:BW_SESSION
      $green = if ($PSStyle) { $PSStyle.Foreground.Green } else { "`e[1;32m" }
      $reset = if ($PSStyle) { $PSStyle.Reset } else { "`e[0m" }
      Write-Host "${green}✔ Bitwarden vault unlocked from keychain${reset}"
      return
    }
    $env:BW_SESSION = $null
    NREDF_BwKeychainDel
  }

  # 3. Vault is locked — prompt for unlock and persist
  if (NREDF_BwEnsureSession -Force) {
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

