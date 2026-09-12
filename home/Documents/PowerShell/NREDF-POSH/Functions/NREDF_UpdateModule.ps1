function NREDF_UpdateModule {
  param (
    [Parameter(Mandatory = $false)]
    [string] $MODULE
  )

  if ([string]::IsNullOrEmpty($MODULE)) {
    [string] $CurrentFunction = (Get-PSCallStack)[0].FunctionName
    if (-not (NREDF_LastRun -CurrentFunction $CurrentFunction)) {
      Write-Host 'All modules will be updated'
      Update-Module
      if ($?) {
        [Void] (NREDF_LastRun -CurrentFunction $CurrentFunction -Success $true)
      }
    }
  } else {
    [string] $CurrentFunctionModule = (Get-PSCallStack)[0].FunctionName + '_' + ${MODULE}
    if (Get-InstalledModule ${MODULE} -ErrorAction silentlycontinue) {
      if (-not (NREDF_LastRun -CurrentFunction $CurrentFunctionModule)) {
        Write-Host "Module ${MODULE} will be updated"
        Update-Module -Name ${MODULE}
        if ($?) {
          [Void] (NREDF_LastRun -CurrentFunction $CurrentFunctionModule -Success $true)
        }
      }
    }
  }
}
