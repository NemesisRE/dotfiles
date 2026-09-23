function NREDF_InstallModules ($MODULES) {
  $missingModules = @()
  foreach ($MODULE in $MODULES) {
    if (-not (Get-Module -ListAvailable -Name $MODULE)) {
      $missingModules += $MODULE
    }
  }

  if ($missingModules.Count -gt 0) {
    $bold = if ($PSStyle) { $PSStyle.Bold } else { "$([char]27)[1m" }
    $reset = if ($PSStyle) { $PSStyle.Reset } else { "$([char]27)[0m" }
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    foreach ($MODULE in $missingModules) {
      Write-Host "${bold}Installing module ${MODULE}${reset}"
      Install-Module -Name $MODULE -Scope CurrentUser -Repository 'PSGallery'
    }
  }
}
