# Comment acknowledging contribution
# This function was created with assistance from Gemini, a large language model from Google AI.
# https://ai.googleblog.com/2022/01/lamda-language-model-for-dialogue-and.html

function Import-TerminalScheme {
  param(
    [Parameter(Mandatory = $true, HelpMessage = 'Path to the theme file in JSON format.')]
    [string]$ThemeFile,
    [Parameter(Mandatory = $false, HelpMessage = "Specify 'stable' or 'preview' for the Windows Terminal version (default: stable).")]
    [string]$TerminalVersion = 'stable',
    [Parameter(Mandatory = $false, HelpMessage = 'Optional path to the settings.json file (default location used based on TerminalVersion).')]
    [string]$SettingsFile = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"  # Formatted string
  )

  <#
  .SYNOPSIS
  Imports a theme from a JSON file into the specified or default Windows Terminal settings file.

  .DESCRIPTION
  This function imports a theme defined in a JSON file (following the Windows Terminal schema)
  into the settings file for your Windows Terminal. You can optionally specify the version of
  Windows Terminal (stable or preview) and the path to the settings file.

  .PARAMETER ThemeFile
  The path to the JSON file containing the theme definition.

  .PARAMETER TerminalVersion
  Specify 'stable' or 'preview' for the Windows Terminal version (default: stable).

  .PARAMETER SettingsFile
  Optional path to the settings.json file (default location used based on TerminalVersion).

  .EXAMPLE
  Import-TerminalTheme "MyTheme.json" -TerminalVersion "preview"

  This example imports the theme from "MyTheme.json" into the settings file for the preview version of Windows Terminal.
  #>

  # Check TerminalVersion and update SettingsFile path
  switch ($TerminalVersion) {
    "stable" {
      break
    }  # No action needed, path already set
    "preview" {
      $SettingsFile = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
      break
    }
    default {
      Write-Warning "Invalid TerminalVersion parameter. Choose 'stable' or 'preview'."
      return
    }
  }

  # Check if theme file and settings file exist
  if (!(Test-Path $ThemeFile) -or !(Test-Path $SettingsFile)) {
    Write-Warning 'One or both files were not found.'
    return
  }

  # Read theme content
  $themeContent = Get-Content $ThemeFile -Raw

  # Convert theme content to object
  $newThemeScheme = ConvertFrom-Json $themeContent

  # Read settings.json content
  $settingsContent = Get-Content $SettingsFile -Raw | ConvertFrom-Json

  # Check if a scheme with the same name already exists
  $existingScheme = $settingsContent.schemes | Where-Object { $_.name -eq $newThemeScheme.name }

  if ($existingScheme) {
    # If scheme exists, get its index in the schemes array
    $existingSchemeIndex = $settingsContent.schemes.IndexOf($existingScheme[0])

    # Update existing scheme (Approach 1: Modify existing object)
    $settingsContent.schemes[$existingSchemeIndex] = $newThemeScheme
  } else {
    # If scheme doesn't exist, add it to the schemes array
    $settingsContent.schemes += $newThemeScheme
  }

  # Save updated settings.json
  $settingsContent | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile
}
