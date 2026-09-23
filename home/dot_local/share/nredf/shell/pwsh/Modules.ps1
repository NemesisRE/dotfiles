# No external PowerShell Gallery modules required.
# All tooling (fzf, oh-my-posh, atuin, lsd, bat, zoxide, kubectx, kubens) is managed via Aqua and native PSReadLine handlers.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'MODULES', Justification = 'Dot-sourced; consumed by Profile.ps1')]
param()
$MODULES = @()
