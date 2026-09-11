
# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# powershell completion for kubectl                              -*- shell-script -*-

function __kubectl_debug {
  if ($env:BASH_COMP_DEBUG_FILE) {
    "$args" | Out-File -Append -FilePath "$env:BASH_COMP_DEBUG_FILE"
  }
}

filter __kubectl_escapeStringWithSpecialChars {
  $_ -replace '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&', '`$&'
}

$rootCommands = @('kubectl');
$aliases = (Get-Alias).Where( { $_.Definition -in $rootCommands }).Name;
if ($aliases) {
  $rootCommands += $aliases
}

Register-ArgumentCompleter -CommandName $rootCommands -ScriptBlock {
  param(
    $WordToComplete,
    $CommandAst,
    $CursorPosition
  )

  # Get the current command line and convert into a string
  $Command = $CommandAst.CommandElements
  $Command = "$Command"

  __kubectl_debug ''
  __kubectl_debug '========= starting completion logic =========='
  __kubectl_debug "WordToComplete: $WordToComplete Command: $Command CursorPosition: $CursorPosition"

  # The user could have moved the cursor backwards on the command-line.
  # We need to trigger completion from the $CursorPosition location, so we need
  # to truncate the command-line ($Command) up to the $CursorPosition location.
  # Make sure the $Command is longer then the $CursorPosition before we truncate.
  # This happens because the $Command does not include the last space.
  if ($Command.Length -gt $CursorPosition) {
    $Command = $Command.Substring(0, $CursorPosition)
  }
  __kubectl_debug "Truncated command: $Command"

  $ShellCompDirectiveError = 1
  $ShellCompDirectiveNoSpace = 2
  $ShellCompDirectiveNoFileComp = 4
  $ShellCompDirectiveFilterFileExt = 8
  $ShellCompDirectiveFilterDirs = 16

  # Prepare the command to request completions for the program.
  # Split the command at the first space to separate the program and arguments.
  $Program, $Arguments = $Command.Split(' ', 2)
  $RequestComp = "$Program __complete $Arguments"
  __kubectl_debug "RequestComp: $RequestComp"

  # we cannot use $WordToComplete because it
  # has the wrong values if the cursor was moved
  # so use the last argument
  if ($WordToComplete -ne '' ) {
    $WordToComplete = $Arguments.Split(' ')[-1]
  }
  __kubectl_debug "New WordToComplete: $WordToComplete"


  # Check for flag with equal sign
  $IsEqualFlag = ($WordToComplete -Like '--*=*' )
  if ( $IsEqualFlag ) {
    __kubectl_debug 'Completing equal sign flag'
    # Remove the flag part
    $Flag, $WordToComplete = $WordToComplete.Split('=', 2)
  }

  if ( $WordToComplete -eq '' -And ( -Not $IsEqualFlag )) {
    # If the last parameter is complete (there is a space following it)
    # We add an extra empty parameter so we can indicate this to the go method.
    __kubectl_debug 'Adding extra empty parameter'
    # We need to use `"`" to pass an empty argument a "" or '' does not work!!!
    $RequestComp = "$RequestComp" + ' `"`"'
  }

  __kubectl_debug "Calling $RequestComp"
  #call the command store the output in $out and redirect stderr and stdout to null
  # $Out is an array contains each line per element
  Invoke-Expression -OutVariable out "$RequestComp" 2>&1 | Out-Null


  # get directive from last line
  [int]$Directive = $Out[-1].TrimStart(':')
  if ($Directive -eq '') {
    # There is no directive specified
    $Directive = 0
  }
  __kubectl_debug "The completion directive is: $Directive"

  # remove directive (last element) from out
  $Out = $Out | Where-Object { $_ -ne $Out[-1] }
  __kubectl_debug "The completions are: $Out"

  if (($Directive -band $ShellCompDirectiveError) -ne 0 ) {
    # Error code.  No completion.
    __kubectl_debug 'Received error from custom completion go code'
    return
  }

  $Longest = 0
  $Values = $Out | ForEach-Object {
    #Split the output in name and description
    $Name, $Description = $_.Split("`t", 2)
    __kubectl_debug "Name: $Name Description: $Description"

    # Look for the longest completion so that we can format things nicely
    if ($Longest -lt $Name.Length) {
      $Longest = $Name.Length
    }

    # Set the description to a one space string if there is none set.
    # This is needed because the CompletionResult does not accept an empty string as argument
    if (-Not $Description) {
      $Description = ' '
    }
    @{Name = "$Name"; Description = "$Description" }
  }


  $Space = ' '
  if (($Directive -band $ShellCompDirectiveNoSpace) -ne 0 ) {
    # remove the space here
    __kubectl_debug 'ShellCompDirectiveNoSpace is called'
    $Space = ''
  }

  if ((($Directive -band $ShellCompDirectiveFilterFileExt) -ne 0 ) -or
       (($Directive -band $ShellCompDirectiveFilterDirs) -ne 0 )) {
    __kubectl_debug 'ShellCompDirectiveFilterFileExt ShellCompDirectiveFilterDirs are not supported'

    # return here to prevent the completion of the extensions
    return
  }

  $Values = $Values | Where-Object {
    # filter the result
    $_.Name -like "$WordToComplete*"

    # Join the flag back if we have an equal sign flag
    if ( $IsEqualFlag ) {
      __kubectl_debug 'Join the equal sign flag back to the completion value'
      $_.Name = $Flag + '=' + $_.Name
    }
  }

  if (($Directive -band $ShellCompDirectiveNoFileComp) -ne 0 ) {
    __kubectl_debug 'ShellCompDirectiveNoFileComp is called'

    if ($Values.Length -eq 0) {
      # Just print an empty string here so the
      # shell does not start to complete paths.
      # We cannot use CompletionResult here because
      # it does not accept an empty string as argument.
      ''
      return
    }
  }

  # Get the current mode
  $Mode = (Get-PSReadLineKeyHandler | Where-Object { $_.Key -eq 'Tab' }).Function
  __kubectl_debug "Mode: $Mode"

  $Values | ForEach-Object {

    # store temporary because switch will overwrite $_
    $comp = $_

    # PowerShell supports three different completion modes
    # - TabCompleteNext (default windows style - on each key press the next option is displayed)
    # - Complete (works like bash)
    # - MenuComplete (works like zsh)
    # You set the mode with Set-PSReadLineKeyHandler -Key Tab -Function <mode>

    # CompletionResult Arguments:
    # 1) CompletionText text to be used as the auto completion result
    # 2) ListItemText   text to be displayed in the suggestion list
    # 3) ResultType     type of completion result
    # 4) ToolTip        text for the tooltip with details about the object

    switch ($Mode) {

      # bash like
      'Complete' {

        if ($Values.Length -eq 1) {
          __kubectl_debug 'Only one completion left'

          # insert space after value
          [System.Management.Automation.CompletionResult]::new($($comp.Name | __kubectl_escapeStringWithSpecialChars) + $Space, "$($comp.Name)", 'ParameterValue', "$($comp.Description)")

        } else {
          # Add the proper number of spaces to align the descriptions
          while ($comp.Name.Length -lt $Longest) {
            $comp.Name = $comp.Name + ' '
          }

          # Check for empty description and only add parentheses if needed
          if ($($comp.Description) -eq ' ' ) {
            $Description = ''
          } else {
            $Description = "  ($($comp.Description))"
          }

          [System.Management.Automation.CompletionResult]::new("$($comp.Name)$Description", "$($comp.Name)$Description", 'ParameterValue', "$($comp.Description)")
        }
      }

      # zsh like
      'MenuComplete' {
        # insert space after value
        # MenuComplete will automatically show the ToolTip of
        # the highlighted value at the bottom of the suggestions.
        [System.Management.Automation.CompletionResult]::new($($comp.Name | __kubectl_escapeStringWithSpecialChars) + $Space, "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
      }

      # TabCompleteNext and in case we get something unknown
      Default {
        # Like MenuComplete but we don't want to add a space here because
        # the user need to press space anyway to get the completion.
        # Description will not be shown because thats not possible with TabCompleteNext
        [System.Management.Automation.CompletionResult]::new($($comp.Name | __kubectl_escapeStringWithSpecialChars), "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
      }
    }

  }
}

# SIG # Begin signature block
# MIIbiwYJKoZIhvcNAQcCoIIbfDCCG3gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUptS+RBwU8M5MY3J31bsPEu8x
# jWugghYHMIIC+jCCAeKgAwIBAgIQH0T/prtX9IlFdTpIz4un8DANBgkqhkiG9w0B
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
# MRYEFCZ/1FhmmKFT9FrAB2iI9RNy5lEHMA0GCSqGSIb3DQEBAQUABIIBAJde+tPz
# XWzjEVcjcRfal5VMsovK81pDsIB1AEdgBRFPljOqdcGb8sev9iA7TgAXIH9bs6hh
# ZnKXo63YvNLyyth/fPOuaUpzwycCZs7H3pzPv68mPAsK9b2FZfP7L1jGmX7Ioqvk
# Nw+traY6V0lyudcr8ox8ujl1MwYHkXE8wPT+UQ7OU+jW9/MnmB/hYTy4QucKV22z
# bLxKp3zBKq86a4fxPXmMh++4IhvqqNE3G0yojVkx2MDk2IMA3JzN1S+TuEkUXBaN
# ZHrGGUoO5RMrhDYszStyw2Bxhr8FG3Pn/OWI4+WggXuQV9eraigDj4vnS7WW6Yfx
# hwnguCAKSrQpk9KhggMgMIIDHAYJKoZIhvcNAQkGMYIDDTCCAwkCAQEwdzBjMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRp
# Z2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENB
# AhAFRK/zlJ0IOaa/2z9f5WEWMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZIhvcNAQkD
# MQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjQwNzE5MTAyNTI2WjAvBgkq
# hkiG9w0BCQQxIgQgKLiErImf4cWwD7CX+Q+KUdKLdzQ6y1IbOtt2Nsf2NOMwDQYJ
# KoZIhvcNAQEBBQAEggIAS7w1a/wYdlX3laFV1JIS5KkDSiq5X+V9rhtsjAi7x913
# iRkwHJIPb1AnyuhqnKLDlVtHs5Mybqd/BLOQ2BC/hlSfdwD7vsbYcc3rYGlWVZcz
# E5LMRSQKeMEnO69l5YtriNz1Gy/odoFT7DmZa5kyXabCozhas2YYQ1I1z6hYBeZZ
# SBL100fXwJUz1pYwvF28e1J/3ZDHv9dR1qPyh+2kZYSojna8G7cX5ysdbbwgXMt9
# GkiqSHngQ86Ni03Zj4thUuQbRleZH3AohjEOtzrFIz8C3LJIqIXS/7FOAJMQrjD7
# 31k/Q0ZSBcr2Vqt/sR+hlUPwGT/9e3ULi5cpDIvtEzR6jr5KvzvMRC+xpI74xlnn
# 3ke+iuk9OI6d5U8DIrEChYlGwdEkjfK5OFI1YunpNMJxLRUtTYmu5Fl7zOXoG8u0
# 9AkS2vzM28kPvTwfSV3WXY+MazW03PJyODicZI0RwqzKq0leJRDPilT8vZIDBlIF
# fE3yoA1KgrU4YP5ib1MwCAnInAXPcXlWJUe/G4cm0aM2Lg/3z/ghtzznJdXJt7hg
# JSI5UXH4gbdEo3L7Yh/iEcHBKKTc7hLhAqXk1G68OdSVlevwlYq0GYxgbxyfrnAY
# 8MEwgK+IkFpHRY9oe1+9ufvZ3NguIKTp7ZDPRTqAxt5qwXHF3aQIUrrkygnWrlA=
# SIG # End signature block
