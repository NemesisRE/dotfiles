function NREDF_InstallModules ($MODULES) {
  $missingModules = @()
  foreach ($MODULE in $MODULES) {
    if (-not (Get-Module -ListAvailable -Name $MODULE)) {
      $missingModules += $MODULE
    }
  }

  if ($missingModules.Count -gt 0) {
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    foreach ($MODULE in $missingModules) {
      Write-Host "Module $MODULE will be installed"
      Install-Module -Name $MODULE -Scope CurrentUser -Repository 'PSGallery'
    }
  }
}
