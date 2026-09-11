
if (Get-Module -ListAvailable -Name PSKubeContext -ErrorAction SilentlyContinue) {
  Register-PSKubeContextComplete
}
