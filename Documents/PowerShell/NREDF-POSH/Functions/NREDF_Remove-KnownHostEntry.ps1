function Remove-KnownHostEntry {
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = 'ByHostname', Mandatory = $true)]
    [string]$Hostname,

    [Parameter(ParameterSetName = 'ByLineNumber', Mandatory = $true)]
    [int]$LineNumber
  )

  $knownHostsFile = "$env:USERPROFILE\.ssh\known_hosts"

  if (-not (Test-Path $knownHostsFile)) {
    Write-Warning "Die Datei '$knownHostsFile' wurde nicht gefunden."
    return $false
  }

  $content = Get-Content $knownHostsFile
  $originalCount = $content.Count
  $deleted = $false

  if ($PSBoundParameters.ContainsKey('Hostname')) {
    # Löschen nach Hostname
    $newContent = $content | Where-Object { $_ -notlike "*$Hostname*" }
    if ($content.Count -gt $newContent.Count) {
      $content = $newContent
      $deletedItem = "Host '$Hostname'"
      $deleted = $true
    }
  } elseif ($PSBoundParameters.ContainsKey('LineNumber')) {
    # Löschen nach Zeilennummer
    if ($LineNumber -lt 1 -or $LineNumber -gt $originalCount) {
      Write-Warning "Ungültige Zeilennummer '$LineNumber'. Die Zeilennummer muss zwischen 1 und $originalCount liegen."
      return $false
    }
    $lineNumberToDelete = $LineNumber - 1 # PowerShell verwendet 0-basierte Indizes
    $deletedItem = "Zeile '$LineNumber': $($content[$lineNumberToDelete])"
    $newContent = $content | Where-Object { $_.ReadCount -ne $LineNumber }
    if ($content.Count -gt $newContent.Count) {
      $content = $newContent
      $deleted = $true
    }
  }

  if ($deleted) {
    $content | Set-Content $knownHostsFile
    Write-Host "Eintrag für $deletedItem erfolgreich aus '$knownHostsFile' gelöscht."
    return $true
  } else {
    Write-Warning 'Kein Eintrag für den angegebenen Host oder die Zeilennummer gefunden.'
    return $false
  }
}
