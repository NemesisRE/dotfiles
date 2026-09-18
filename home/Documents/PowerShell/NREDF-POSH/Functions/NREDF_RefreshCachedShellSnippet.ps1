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
    [scriptblock]$Generator,

    [Parameter(Mandatory = $false)]
    [int]$MaxAgeHours = 24
  )

  $needsRefresh = $true
  if ([System.IO.File]::Exists($CacheFile)) {
    $fileInfo = [System.IO.FileInfo]::new($CacheFile)
    if ($fileInfo.Length -gt 0) {
      $age = [DateTime]::UtcNow - $fileInfo.LastWriteTimeUtc
      if ($age.TotalHours -lt $MaxAgeHours) {
        $needsRefresh = $false
      }
    }
  }

  if ($needsRefresh) {
    $cacheDir = [System.IO.Path]::GetDirectoryName($CacheFile)
    if (-not [string]::IsNullOrEmpty($cacheDir) -and -not [System.IO.Directory]::Exists($cacheDir)) {
      [System.IO.Directory]::CreateDirectory($cacheDir) | Out-Null
    }
    try {
      $content = (& $Generator | Out-String)
      if (-not [string]::IsNullOrWhiteSpace($content)) {
        [System.IO.File]::WriteAllText($CacheFile, $content)
      }
    } catch {
      Write-Warning "Failed to generate cached snippet for ${CacheKey}: $_"
    }
  }

  if ([System.IO.File]::Exists($CacheFile)) {
    return $CacheFile
  }
  return $null
}

