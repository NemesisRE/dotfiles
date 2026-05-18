Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted

${SCRIPT_PATH} = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "${SCRIPT_PATH}\Defaults.ps1"
. "${SCRIPT_PATH}\Aliases.ps1"
. "${SCRIPT_PATH}\Profile_Functions.ps1"
. "${SCRIPT_PATH}\Kubectl_Completion.ps1"
. "${SCRIPT_PATH}\Modules.ps1"

if (Test-Path "${SCRIPT_PATH}\Local_Modules.ps1") {
  . "${SCRIPT_PATH}\Local_Modules.ps1"
}

# Update and Load Modules or install if necessary
LoadModules ${MODULES}

# Set Powershell Theme
if (Get-Command oh-my-posh -errorAction SilentlyContinue) {
  oh-my-posh init pwsh --config "${ENV:POSH_THEMES_PATH}\powerlevel10k_rainbow.omp.json" | Invoke-Expression
}

# Set PSReadLine options
Set-PSReadLineOption -PredictionSource History

# Set Keyhandlers
#Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
if ( ${isWindows} ) {
  Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-GuiCompletion }
} elseif ( ${isLinux} ) {
  Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion -CaseInsensitive }
}
Set-PSReadLineKeyHandler -Key Ctrl+d -Function ViExit
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Alt+d -Function ShellKillWord
Set-PSReadLineKeyHandler -Key Alt+Backspace -Function ShellBackwardKillWord
Set-PSReadLineKeyHandler -Key Alt+q -ScriptBlock { SaveInHistory }

# Produce UTF-8 by default
# https://news.ycombinator.com/item?id=12991690
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# https://technet.microsoft.com/en-us/magazine/hh241048.aspx
$MaximumHistoryCount = 10000;

# PSFzf settings
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Register Completions
Register-PSKubeContextComplete
