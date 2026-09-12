$MODULES = New-Object System.Collections.ArrayList

[Void]$MODULES.Add('posh-git')
[Void]$MODULES.Add('PSFzf')
if (${isWindows}) {
  [Void]$MODULES.Add('Recycle')
}
[Void]$MODULES.Add('Terminal-Icons')
# Here are some nice modules for your "$ENV:PROFILE_PATH\Modules.ps1"
#[Void]$MODULES.Add('Microsoft.PowerShell.SecretManagement')
#[Void]$MODULES.Add('Microsoft.PowerShell.SecretStore')
#[Void]$MODULES.Add('SecretManagement.KeePass')
#[Void]$MODULES.Add('PoShLog')

if ( ${isWindows} -and ($Env:TERM_PROGRAM -ne 'vscode')) {
  [Void]$MODULES.Add('GuiCompletion')
}

if (Get-Command kubectl -ErrorAction SilentlyContinue) {
  [Void]$MODULES.Add('PSKubeContext')
}
