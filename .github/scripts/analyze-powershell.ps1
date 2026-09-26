#!/usr/bin/env pwsh
<#
.SYNOPSIS
  PSScriptAnalyzer gate for the repo's PowerShell, shared by CI and check.sh.

.DESCRIPTION
  Gated rules are correctness issues the tree is already clean of, so a regression
  fails the build. Everything else at Warning severity is printed as an advisory
  backlog. Ratchet the list by moving rules from the backlog into $gated once fixed.
  What remains in the backlog is deliberate or a judgement call: Write-Host (interactive
  output), empty catch blocks (best-effort steps that must never break startup),
  Invoke-Expression (cached tool-init snippets), global variables (shared profile state)
  and BOM (bootstrap.ps1 is piped through iex, where a BOM breaks it).

  Run from the repository root.
#>
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
  Write-Error 'PSScriptAnalyzer is not installed (Install-Module PSScriptAnalyzer -Scope CurrentUser)'
}

$targets = @('bootstrap.ps1') +
  (Get-ChildItem -Path 'home/Documents/PowerShell', 'home/dot_local/share/nredf/shell/pwsh' -Recurse -Filter '*.ps1' | ForEach-Object FullName) |
  Where-Object { Test-Path $_ }

$gated = @(
  'PSAvoidAssignmentToAutomaticVariable'
  'PSPossibleIncorrectComparisonWithNull'
  'PSPossibleIncorrectUsageOfAssignmentOperator'
  'PSPossibleIncorrectUsageOfRedirectionOperator'
  'PSAvoidUsingPlainTextForPassword'
  'PSAvoidUsingConvertToSecureStringWithPlainText'
  'PSAvoidUsingUsernameAndPasswordParams'
  'PSAvoidUsingComputerNameHardcoded'
  'PSUsePSCredentialType'
  'PSUseApprovedVerbs'
  'PSAvoidDefaultValueSwitchParameter'
  'PSReservedCmdletChar'
  'PSReservedParams'
  'PSMissingModuleManifestField'
  'PSAvoidUsingBrokenHashAlgorithms'
  'PSUseDeclaredVarsMoreThanAssignments'
  'PSReviewUnusedParameter'
  'PSUseShouldProcessForStateChangingFunctions'
)

$blocking = @($targets | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -IncludeRule $gated })
$blocking += @($targets | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Severity Error })

$advisory = @($targets | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Severity Warning -ExcludeRule $gated })
if ($advisory.Count -gt 0) {
  Write-Host "Advisory (not blocking) - $($advisory.Count) issue(s):"
  $advisory | Group-Object RuleName | Sort-Object Count -Descending |
    Format-Table Count, Name -AutoSize | Out-String -Width 120 | Write-Host
}

# PSUseCompatibleSyntax isn't in the default ruleset — it needs -Settings to say
# which version(s) to check against — so it's driven separately from $gated.
# bootstrap.ps1 is fetched and run (`iex`) before chezmoi exists, by whatever
# PowerShell the machine has: home/.chezmoi.toml.tmpl documents that Windows
# PowerShell 5.1 fails outright on `?.` and `ConvertFrom-Json -AsHashtable`, so a
# 5.1 syntax regression there is blocking. Everything else in $targets (the
# canonical pwsh/ tree and the PS7 Documents/PowerShell profile) is dot-sourced
# under PS7 normally, but the same canonical tree is also reached from
# Documents/WindowsPowerShell's 5.1 stub — report-only there: it's worth knowing
# about, but PS7-only syntax is an accepted, intentional trade-off outside of
# bootstrap.ps1, not a regression to block on.
$compatSettings = @{
  Rules = @{
    PSUseCompatibleSyntax = @{
      Enable         = $true
      TargetVersions = @('5.1')
    }
  }
}
$bootstrapCompat = @(Invoke-ScriptAnalyzer -Path 'bootstrap.ps1' -Settings $compatSettings -IncludeRule PSUseCompatibleSyntax)
$blocking += $bootstrapCompat

$otherTargets = @($targets | Where-Object { $_ -ne 'bootstrap.ps1' })
$compatAdvisory = @($otherTargets | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Settings $compatSettings -IncludeRule PSUseCompatibleSyntax })
if ($compatAdvisory.Count -gt 0) {
  Write-Host "Advisory (not blocking) - PSUseCompatibleSyntax(5.1), outside bootstrap.ps1 - $($compatAdvisory.Count) issue(s):"
  $compatAdvisory | Format-Table RuleName, ScriptName, Line, Message -AutoSize | Out-String -Width 200 | Write-Host
}

if ($blocking.Count -gt 0) {
  $blocking | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize |
    Out-String -Width 200 | Write-Host
  Write-Host "::error::PSScriptAnalyzer: $($blocking.Count) blocking issue(s)"
  exit 1
}
Write-Host "PSScriptAnalyzer: no blocking issues across $($targets.Count) files"
