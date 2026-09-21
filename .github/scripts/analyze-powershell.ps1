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
  (Get-ChildItem -Path 'home/Documents/PowerShell' -Recurse -Filter '*.ps1' | ForEach-Object FullName) |
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

if ($blocking.Count -gt 0) {
  $blocking | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize |
    Out-String -Width 200 | Write-Host
  Write-Host "::error::PSScriptAnalyzer: $($blocking.Count) blocking issue(s)"
  exit 1
}
Write-Host "PSScriptAnalyzer: no blocking issues across $($targets.Count) files"
