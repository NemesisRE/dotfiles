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

# SIG # Begin signature block
# MIIbiwYJKoZIhvcNAQcCoIIbfDCCG3gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUU31MBW0RlFI0/Dy5Y12KEXeq
# a2mgghYHMIIC+jCCAeKgAwIBAgIQH0T/prtX9IlFdTpIz4un8DANBgkqhkiG9w0B
# AQsFADAVMRMwEQYDVQQDDApOUkVERi1QT1NIMB4XDTI0MDcxOTEwMDE0NVoXDTI1
# MDcxOTEwMjE0NVowFTETMBEGA1UEAwwKTlJFREYtUE9TSDCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBAOl2MdANwTlf5vc2DArt9tpjFrS2pAvRQDMrTMxx
# hf9RVxHgzHY7DAQNeNSyDIf67/2XR9of9Iaxy47HwEs2YuE8yluH/17gjWEyVHoX
# OVVlx4rK9Z9LN5T+UcYvNYF0GCOfMm+w5AgMhYyqp/qYyF1O8OIfScLPiCY8jO1a
# ppYE1G6BD4HIGzNNM52SVK+F2TP4AKR9PWo1AmZFAJGcxTxRlmPNNMy3EhL9lFCV
# Vb6owCUJWyotlpfMF8UV1uVju/NFdKtoQV6KPE9Imyuf+iU17ENlraNkqrWKSR/L
# M+fx4NBoRCv7mphDq+AX2+4typ6YXXO9uxzy93Tj16nOyU0CAwEAAaNGMEQwDgYD
# VR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBRyKutN
# xXknoIuZs9LAi7MiMXUcazANBgkqhkiG9w0BAQsFAAOCAQEAjNCkG+3/rk+IilPn
# 9xe2IKcBNQv5huYYMJF2Zas6hX4Ageu+3M2lQP9a0mAgqBrlBT7gXSf7E69r0ZVu
# eiU7labxwkAHezs+SFMEN2wBt+8F1TJxkZkOJrriZ3VY3eseOss0P7GKytBi69lp
# NBL4zWjp1yc6ibQHewJ7VPNuN4vLmIwebT9cyyhA7lf0EUssCiAJodpeVRgWeQsb
# WNPaloUcHordUOJv52NE35SYuJxLDKUpmOR3wwM4HII8nEi223vw1xpj0A3gWbx/
# QAgsMc6eMiXxR82c03T6mFce5rzwFjY9LnXas9+MM05uc/xf6/odLPGeS0/YoOLf
# Jo7GfDCCBY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEM
# BQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UE
# CxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJ
# RCBSb290IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zC
# pyUuySE98orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf
# 1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x
# 4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEio
# ZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7ax
# xLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZ
# OjFEmjNAvwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJ
# l2l6SPDgohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz
# 2cXfSwQAzH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH
# 4b235kOkGLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb
# 5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ
# 9eRpL5gdLfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYD
# VR0OBBYEFOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuC
# MS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3
# aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9v
# dENBLmNydDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0g
# ADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs
# 7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq
# 3votVs/59PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/
# Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9
# /HYJaISfb8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWoj
# ayL/ErhULSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDCCBq4wggSWoAMC
# AQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTIyMDMy
# MzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoT
# DkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJT
# QTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh1tKD0Z5Mom2gsMyD
# +Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+FeoAn39Q7SE2hHxc7Gz
# 7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1decfBmWNlCnT2exp
# 39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxndX7RUCyFobjchu0Cs
# X7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6Th+xtVhNef7Xj3OT
# rCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPjQ2OAe3VuJyWQmDo4
# EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlRErWHRAKKtzQ87fSqEc
# azjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JMq++bPf4OuGQq+nUo
# JEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh3pP+OcD5sjClTNfp
# mEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8ju2TjY+Cm4T72wnSy
# Px4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnSDmuZDNIztM2xAgMB
# AAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBS6FtltTYUv
# cyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAO
# BgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEE
# azBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYB
# BQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYG
# Z4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAfVmOwJO2b5ip
# RCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp/GnBzx0H6T5gyNgL
# 5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40BIiXOlWk/R3f7cnQU
# 1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2dfNBwCnzvqLx1T7pa
# 96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibBt94q6/aesXmZgaNW
# hqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7T6NJuXdmkfFynOlL
# AlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZAmyEhQNC3EyTN3B14
# OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdBeHo46Zzh3SP9HSjT
# x/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnKcPA3v5gA3yAWTyf7
# YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/pNHzV9m8BPqC3jLf
# BInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yYlvZVVCsfgPrA8g4r
# 5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwggbCMIIEqqADAgECAhAFRK/zlJ0IOaa/
# 2z9f5WEWMA0GCSqGSIb3DQEBCwUAMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0
# MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMjMwNzE0MDAwMDAwWhcNMzQx
# MDEzMjM1OTU5WjBIMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIElu
# Yy4xIDAeBgNVBAMTF0RpZ2lDZXJ0IFRpbWVzdGFtcCAyMDIzMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAo1NFhx2DjlusPlSzI+DPn9fl0uddoQ4J3C9I
# o5d6OyqcZ9xiFVjBqZMRp82qsmrdECmKHmJjadNYnDVxvzqX65RQjxwg6seaOy+W
# ZuNp52n+W8PWKyAcwZeUtKVQgfLPywemMGjKg0La/H8JJJSkghraarrYO8pd3hkY
# hftF6g1hbJ3+cV7EBpo88MUueQ8bZlLjyNY+X9pD04T10Mf2SC1eRXWWdf7dEKEb
# g8G45lKVtUfXeCk5a+B4WZfjRCtK1ZXO7wgX6oJkTf8j48qG7rSkIWRw69XloNpj
# sy7pBe6q9iT1HbybHLK3X9/w7nZ9MZllR1WdSiQvrCuXvp/k/XtzPjLuUjT71Lvr
# 1KAsNJvj3m5kGQc3AZEPHLVRzapMZoOIaGK7vEEbeBlt5NkP4FhB+9ixLOFRr7St
# FQYU6mIIE9NpHnxkTZ0P387RXoyqq1AVybPKvNfEO2hEo6U7Qv1zfe7dCv95NBB+
# plwKWEwAPoVpdceDZNZ1zY8SdlalJPrXxGshuugfNJgvOuprAbD3+yqG7HtSOKmY
# CaFxsmxxrz64b5bV4RAT/mFHCoz+8LbH1cfebCTwv0KCyqBxPZySkwS0aXAnDU+3
# tTbRyV8IpHCj7ArxES5k4MsiK8rxKBMhSVF+BmbTO77665E42FEHypS34lCh8zrT
# ioPLQHsCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAA
# MBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsG
# CWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91jGogj57IbzAdBgNV
# HQ4EFgQUpbbvE+fvzdBkodVWqWUxo97V40kwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNI
# QTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEEgYMwgYAwJAYIKwYB
# BQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggrBgEFBQcwAoZMaHR0
# cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5
# NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAgRrW
# 3qCptZgXvHCNT4o8aJzYJf/LLOTN6l0ikuyMIgKpuM+AqNnn48XtJoKKcS8Y3U62
# 3mzX4WCcK+3tPUiOuGu6fF29wmE3aEl3o+uQqhLXJ4Xzjh6S2sJAOJ9dyKAuJXgl
# nSoFeoQpmLZXeY/bJlYrsPOnvTcM2Jh2T1a5UsK2nTipgedtQVyMadG5K8TGe8+c
# +njikxp2oml101DkRBK+IA2eqUTQ+OVJdwhaIcW0z5iVGlS6ubzBaRm6zxbygzc0
# brBBJt3eWpdPM43UjXd9dUWhpVgmagNF3tlQtVCMr1a9TMXhRsUo063nQwBw3syY
# nhmJA+rUkTfvTVLzyWAhxFZH7doRS4wyw4jmWOK22z75X7BC1o/jF5HRqsBV44a/
# rCcsQdCaM0qoNtS5cpZ+l3k4SF/Kwtw9Mt911jZnWon49qfH5U81PAC9vpwqbHkB
# 3NpE5jreODsHXjlY9HxzMVWggBHLFAx+rrz+pOt5Zapo1iLKO+uagjVXKBbLafIy
# mrLS2Dq4sUaGa7oX/cR3bBVsrquvczroSUa31X/MtjjA2Owc9bahuEMs305MfR5o
# cMB3CtQC4Fxguyj/OOVSWtasFyIjTvTs0xf7UGv/B3cfcZdEQcm4RtNsMnxYL2dH
# ZeUbc7aZ+WssBkbvQR7w8F/g29mtkIBEr4AQQYoxggTuMIIE6gIBATApMBUxEzAR
# BgNVBAMMCk5SRURGLVBPU0gCEB9E/6a7V/SJRXU6SM+Lp/AwCQYFKw4DAhoFAKB4
# MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQB
# gjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkE
# MRYEFIZfHO5N7TsyFXQnXwFJaNXGAiYFMA0GCSqGSIb3DQEBAQUABIIBAL4++SpG
# J60oXifmrU8xqMBNhqodce7yYhMhOKa8t77cK2hFunai2OJaHxg74LMX73ROCY2d
# QKNyOt34ci2DLJwJidqtcJ1/mhrLoiF2VGgGhIbqoPGuVgUKo2ps6RH6QEc6dJTJ
# ZVLj7c1ZCI7OTwr+dbUmftPB5zZu1GVhAoirmkNrq9i9Qt/aMEuZ3iayPvcOxD4w
# 5ntTk9Y5SKtufro3b3svc1XirjjU2MNCkbbR9t5FhV4yTM7r4LhwnaYuUF7iPXLD
# y18HHh5XU0sb0qY2vPqwxPMYz3gRA3/FnSCEDVakSVrwx7+8QSsj9WlbM12FpnWp
# QrCY6pQQobXzXXqhggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRp
# Z2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENB
# AhAFRK/zlJ0IOaa/2z9f5WEWMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkD
# MQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjQwNzIyMTQxMDQ5WjAvBgkq
# hkiG9w0BCQQxIgQgW5SeIPPogQviu50WAhFMilzHFa3S35R1q4yQgNVzz/0wDQYJ
# KoZIhvcNAQEBBQAEggIAPXu81Nv8DEtD+hIyJG6B15WAB9wPgMq7IJ91MeJ/NgTn
# 56xfGF2axfDg9mzTP9Fcq0xlwF4V39NUPa+R+IJQh5PoM2VbW15x3Rr7TCRCKxsN
# HVLhpIfuCT2u2d2A44UbehFq4q3ezZ4+xnjGj6v0wHbvQ59rMVjonpTo6cbTq/2H
# AjBhTN6HshzZH3xW0nYPLo9/+JV/kR344PAnruOszDilZt2GLQWt9EGyxzJ1T9X/
# pxXqqOPy6GigioQCydSQzUbklaiEGVwfdQqunB2YSvHeljOvronFLcUVyylPZOHc
# 37ZcpCdUb/E6tNXdGRiHboEQ27fdcfZZbpfjsMqA7lYp7CTEOEcwm+4W3weaobpO
# k0Djku5jAbZ1KJOCb7WMCMsi37b3yQDkviaiQbW3N1Ub6kQSL5XXPcODEVb1utvs
# Ld4jO3EOonNKcli6JDw8y5wcJlJqi+Yak0hlKsAmkY+CBKPmlj7uKcE5blBFvJRN
# 0qYOhMw1pXoyG79ZcV952NfVKtFHbjd4zBpPRYDa4BOarhcRnGLauKCdKN9LOB+c
# wxg2vt7ZAUk+vJXPSRn1IouwHBs0T2U3nEHbDFEE+nAA5fWVtf2O8FGsddt756Kp
# Jvlj6qVtqZLC+to1nbowsEjiRKDRCdQCyWp5DC5MrDklZqp0H99VBMV6i10ea98=
# SIG # End signature block
