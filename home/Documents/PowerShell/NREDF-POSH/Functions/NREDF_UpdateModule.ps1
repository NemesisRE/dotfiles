function NREDF_UpdateModule {
  param (
    [Parameter(Mandatory = $false)]
    [string] $MODULE
  )

  $bold = if ($PSStyle) { $PSStyle.Bold } else { "$([char]27)[1m" }
  $reset = if ($PSStyle) { $PSStyle.Reset } else { "$([char]27)[0m" }

  if ([string]::IsNullOrEmpty($MODULE)) {
    [string] $CurrentFunction = (Get-PSCallStack)[0].FunctionName
    if (-not (NREDF_LastRun -CurrentFunction $CurrentFunction)) {
      Write-Host "${bold}Updating PowerShell modules${reset}"
      Update-Module
      if ($?) {
        [Void] (NREDF_LastRun -CurrentFunction $CurrentFunction -Success $true)
      }
    }
  } else {
    [string] $CurrentFunctionModule = (Get-PSCallStack)[0].FunctionName + '_' + ${MODULE}
    if (Get-InstalledModule ${MODULE} -ErrorAction silentlycontinue) {
      if (-not (NREDF_LastRun -CurrentFunction $CurrentFunctionModule)) {
        Write-Host "${bold}Updating module ${MODULE}${reset}"
        Update-Module -Name ${MODULE}
        if ($?) {
          [Void] (NREDF_LastRun -CurrentFunction $CurrentFunctionModule -Success $true)
        }
      }
    }
  }
}
