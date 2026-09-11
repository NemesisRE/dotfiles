# NREDF-POSH

## Prerequisites

We need PowerShell Core this will not function with Windows PowerShell!

We also need `git`, [`fzf`](https://github.com/junegunn/fzf) and [`oh-my-posh`](https://ohmyposh.dev/)

## Manual Installation

If you are familiar with using powershell

1. If on windows and not already done you have to set the execution policy to remote signed

    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
    ```

1. Checkout the repository into your profile directory

1. Add the following snippet at the top of your profile

    ```powershell
    # Load NRE Dotfiles
    $ENV:PROFILE_PATH = (Get-Item $PROFILE).Directory
    $ENV:NREDF_PATH = "$ENV:PROFILE_PATH\NREDF-POSH"
    . "$ENV:NREDF_PATH\Profile.ps1"
    ```

1. On windows import `NREDF-POSH.sst` to your Trusted Publisher cert store

## Scripted Installation

Run the following snippet

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/NemesisRE/NREDF-POSH/main/install.ps1'))
```
