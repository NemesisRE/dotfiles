function NREDF_RefreshCachedShellSnippet {
  <#
  .SYNOPSIS
      Caches and returns shell initialization snippets for fast terminal startup.
  .DESCRIPTION
      Mirrors the _nredf_refresh_cached_shell_snippet architecture used in bash/zsh dotfiles.
      Evaluates the generator scriptblock only if the cached file is missing or older than 24 hours.
  .PARAMETER CacheKey
      Unique identifier for the snippet (used with NREDF_LastRun).
  .PARAMETER CacheFile
      Full path to the cached .ps1 file.
  .PARAMETER Generator
      Scriptblock that outputs the PowerShell code to be cached.
  #>
  param (
    [Parameter(Mandatory = $true)]
    [string]$CacheKey,

    [Parameter(Mandatory = $true)]
    [string]$CacheFile,

    [Parameter(Mandatory = $true)]
    [scriptblock]$Generator
  )

  $needsRefresh = $false
  if (-not (Test-Path -LiteralPath $CacheFile) -or ((Get-Item -LiteralPath $CacheFile).Length -eq 0)) {
    $needsRefresh = $true
  } elseif (-not (NREDF_LastRun -CurrentFunction $CacheKey)) {
    $needsRefresh = $true
  }

  if ($needsRefresh) {
    $cacheDir = Split-Path -Parent $CacheFile
    if (-not (Test-Path -LiteralPath $cacheDir)) {
      New-Item -ItemType Directory -Path $cacheDir -Force -ErrorAction SilentlyContinue | Out-Null
    }
    try {
      $content = (& $Generator | Out-String)
      if (-not [string]::IsNullOrWhiteSpace($content)) {
        Set-Content -LiteralPath $CacheFile -Value $content -Force -ErrorAction Stop
        [Void] (NREDF_LastRun -CurrentFunction $CacheKey -Success $true -NextRun ((Get-Date).AddHours(24).ToFileTime()))
      }
    } catch {
      Write-Warning "Failed to generate cached snippet for ${CacheKey}: $_"
    }
  }

  if (Test-Path -LiteralPath $CacheFile) {
    return $CacheFile
  }
  return $null
}

