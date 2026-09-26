function NREDF_LastRun {
  param (
    [Parameter(Mandatory = $false)]
    [string] $CurrentFunction,
    [Parameter(Mandatory = $false)]
    [bool] $Success = $false,
    [Parameter(Mandatory = $false)]
    [long] $NextRun = (Get-Date).AddHours(12).ToFileTime(),
    [Parameter(Mandatory = $false)]
    [int] $IntervalSeconds = 43200
  )

  if ([string]::IsNullOrEmpty($CurrentFunction)) {
    if (Get-Command Get-PSCallStack -ErrorAction SilentlyContinue) {
      $CurrentFunction = (Get-PSCallStack)[1].FunctionName
    } else {
      Write-Error "Could not get current function, will skip last run"
      return $false
    }
  }

  if ([string]::IsNullOrEmpty($ENV:NREDF_LRCACHE)) {
    return $false
  }

  $LastRunFile = Join-Path -Path ${ENV:NREDF_LRCACHE} -ChildPath ("last_run_${CurrentFunction}.txt")

  if ($Success) {
    if (-not [System.IO.Directory]::Exists($ENV:NREDF_LRCACHE)) {
      [System.IO.Directory]::CreateDirectory($ENV:NREDF_LRCACHE) | Out-Null
    }
    [System.IO.File]::WriteAllText($LastRunFile, [string]$NextRun)
    return $true
  }

  if (-not [System.IO.File]::Exists($LastRunFile)) {
    return $false
  }

  # Fast path: check file modification time directly via .NET BCL
  $age = [DateTime]::UtcNow - [System.IO.File]::GetLastWriteTimeUtc($LastRunFile)
  if ($age.TotalSeconds -lt $IntervalSeconds) {
    return $true
  }

  # Backward compatibility fallback: check stored next run filetime
  try {
    $content = [System.IO.File]::ReadAllText($LastRunFile).Trim()
    $storedTime = 0L
    if (-not [string]::IsNullOrEmpty($content) -and [long]::TryParse($content, [ref]$storedTime)) {
      if ($storedTime -gt (Get-Date).ToFileTime()) {
        return $true
      }
    }
  } catch {}

  return $false
}
