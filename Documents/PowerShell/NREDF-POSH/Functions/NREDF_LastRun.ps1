function NREDF_LastRun {
  param (
    [Parameter(Mandatory = $false)]
    [string] $CurrentFunction,
    [Parameter(Mandatory = $false)]
    [bool] $Success = $false,
    [Parameter(Mandatory = $false)]
    [long] $NextRun = (Get-Date).AddHours(12).ToFileTime()
  )

  if ([string]::IsNullOrEmpty($CurrentFunction)) {
    if (Get-Command Get-PSCallStack -ErrorAction SilentlyContinue) {
      # Get caller function name (limited to PowerShell v5.1)
      $CurrentFunction = (Get-PSCallStack)[1].FunctionName
    } elseif (Get-Module | Where-Object { $_.Name -eq 'PSReadLine' }) {
      $CurrentFunction = (Get-PSReadLineHistory -Count 1).PreviousInputObject.Split(' ')[-2]
    } else {
      Write-Error "Could not get current function, will skip last run"
      return $false
    }
  }

  # Create last run cache directory if it doesn't exist
  if (-not (Test-Path -Path ${ENV:NREDF_LRCACHE})) {
    New-Item -Path ${ENV:NREDF_LRCACHE} -ItemType Directory -Force
  }

  # Define last run file path
  $LastRunFile = Join-Path -Path ${ENV:NREDF_LRCACHE} -ChildPath ("last_run_${CurrentFunction}.txt")

  # Get Last Run Time (default 0 if file doesn't exist)
  [long] $LastRun = Get-Content -Path $LastRunFile -ErrorAction SilentlyContinue

  if ($LastRun -eq '') {
    $LastRun = 0
  }

  # Check for previous run
  if ($LastRun -gt (Get-Date).ToFileTime()) {
    return $true
  } elseif ($Success) {
    Set-Content -Path $LastRunFile -Value $NextRun
    return $true
  } else {
    return $false
  }
}
