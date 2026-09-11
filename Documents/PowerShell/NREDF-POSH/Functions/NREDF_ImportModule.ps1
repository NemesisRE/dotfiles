<#
.SYNOPSIS
    Imports specified PowerShell modules if they are installed.
.DESCRIPTION
    This function checks if each module in the provided list is installed and imports it.
.PARAMETER MODULES
    An array of module names to import.
#>
function NREDF_ImportModules {
  param (
    [Parameter(Mandatory = $true)]
    [string[]] ${MODULES}
  )

  foreach (${MODULE} in ${MODULES}) {
    if (-not ( [string]::IsNullOrEmpty($MODULE))) {
      ${installedModule} = Get-Module -ListAvailable -Name ${MODULE} -ErrorAction SilentlyContinue
      if ($null -ne ${installedModule}) {
        Import-Module -Name ${MODULE} -Force -ErrorAction Stop
      }
    }
  }
}
