function Remove-KnownHostEntry {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(ParameterSetName = 'ByHostname', Mandatory = $true)]
    [string]$Hostname,

    [Parameter(ParameterSetName = 'ByLineNumber', Mandatory = $true)]
    [int]$LineNumber
  )

  $userHome = if (-not [string]::IsNullOrEmpty($env:USERPROFILE)) { $env:USERPROFILE } else { $HOME }
  $knownHostsFile = Join-Path (Join-Path $userHome '.ssh') 'known_hosts'

  if (-not (Test-Path $knownHostsFile)) {
    Write-Warning "The file '$knownHostsFile' was not found."
    return $false
  }

  if ($PSBoundParameters.ContainsKey('Hostname')) {
    if (-not $PSCmdlet.ShouldProcess($knownHostsFile, "Remove entries for host '$Hostname'")) { return }
    if (Get-Command ssh-keygen -ErrorAction SilentlyContinue) {
      & ssh-keygen -R $Hostname -f $knownHostsFile 2>$null
      if ($LASTEXITCODE -eq 0) {
        Write-Host "Entry for host '$Hostname' successfully removed from '$knownHostsFile'."
        return $true
      }
    }

    $content = Get-Content $knownHostsFile
    $newContent = $content | Where-Object { $_ -notlike "*$Hostname*" }
    if ($content.Count -gt $newContent.Count) {
      $newContent | Set-Content $knownHostsFile
      Write-Host "Entry for host '$Hostname' successfully removed from '$knownHostsFile'."
      return $true
    }
  } elseif ($PSBoundParameters.ContainsKey('LineNumber')) {
    if (-not $PSCmdlet.ShouldProcess($knownHostsFile, "Remove line $LineNumber")) { return }
    $content = Get-Content $knownHostsFile
    $originalCount = $content.Count
    if ($LineNumber -lt 1 -or $LineNumber -gt $originalCount) {
      Write-Warning "Invalid line number '$LineNumber'. Line number must be between 1 and $originalCount."
      return $false
    }
    $lineNumberToDelete = $LineNumber - 1
    $deletedItem = "line '$LineNumber': $($content[$lineNumberToDelete])"
    $newContent = $content | Where-Object { $_.ReadCount -ne $LineNumber }
    if ($content.Count -gt $newContent.Count) {
      $newContent | Set-Content $knownHostsFile
      Write-Host "Entry for $deletedItem successfully removed from '$knownHostsFile'."
      return $true
    }
  }

  Write-Warning 'No entry found for the specified host or line number.'
  return $false
}
