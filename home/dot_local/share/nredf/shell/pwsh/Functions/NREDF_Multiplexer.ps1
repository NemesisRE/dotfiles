# chezmoi-managed pwsh function file.
# -----------------------------------------------------------------------------
# Zellij auto-attach over SSH / WSL
#
# Port of common/functions/nredf_remote_multiplexer.bash (also
# nredf_remote_multiplexer.fish/.nu). Attaches only when all of these hold:
# over SSH or WSL, not already inside zellij (this repo doesn't use tmux —
# there's nothing to check there), interactive, and the setting is enabled
# (home/.chezmoidata/shell.yaml's `shell.multiplexer` / `wsl_multiplexer`).
#
# bash/zsh/fish/nu get NREDF_SHELL_MULTIPLEXER / NREDF_SHELL_WSL_MULTIPLEXER
# baked in at chezmoi-apply time (see common/rc.tmpl). Profile.ps1/Sources.ps1
# aren't chezmoi templates, so pwsh instead gets these two exported straight
# from shell.yaml by a small hand-written hunk in Aliases.ps1.tmpl — the one
# template that's already sourced (via Sources.ps1) before the Functions
# bundle, so both env vars are set long before Profile.ps1 ever calls
# NREDF_RemoteMultiplexer.
# -----------------------------------------------------------------------------

function NREDF_RemoteMultiplexer {
  if ($env:TERM_PROGRAM -eq 'vscode') {
    return
  }

  # Never start the multiplexer in a non-interactive or background session.
  try {
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
      return
    }
  } catch {
    return
  }

  if (-not (Get-Command zellij -ErrorAction SilentlyContinue)) {
    return
  }

  if ($env:ZELLIJ) {
    return
  }

  $isSsh = [bool]($env:SSH_TTY -or $env:SSH_CONNECTION -or $env:SSH_CLIENT)

  # WSL_DISTRO_NAME/WSL_INTEROP are set directly by WSL on every process it
  # spawns — reading them live here is just as cheap as bash's chezmoi-baked
  # NREDF_WSL and needs no template rendering to do it.
  $isWsl = [bool]($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP)

  $shouldStart = $false

  if ($isSsh) {
    $multiplexerEnabled = $env:NREDF_SHELL_MULTIPLEXER
    if ([string]::IsNullOrEmpty($multiplexerEnabled)) { $multiplexerEnabled = $env:NREDF_SHELL_GENERELL_MULTIPLEXER }
    if ([string]::IsNullOrEmpty($multiplexerEnabled)) { $multiplexerEnabled = 'true' }
    if ($multiplexerEnabled -ne 'false') {
      $shouldStart = $true
    }
  } elseif ($isWsl) {
    $wslMultiplexer = $env:NREDF_SHELL_WSL_MULTIPLEXER
    if ([string]::IsNullOrEmpty($wslMultiplexer)) { $wslMultiplexer = $env:NREDF_SHELL_MULTIPLEXER_WSL }
    if ([string]::IsNullOrEmpty($wslMultiplexer)) { $wslMultiplexer = 'false' }
    if ($wslMultiplexer -in @('true', '1', 'yes')) {
      $shouldStart = $true
    }
  }

  if (-not $shouldStart) {
    return
  }

  $hostName = $env:HOSTNAME
  if ([string]::IsNullOrEmpty($hostName) -and $env:HOST) {
    $hostName = ($env:HOST -split '\.')[0]
  }
  if ([string]::IsNullOrEmpty($hostName)) {
    if (Get-Command hostname -ErrorAction SilentlyContinue) {
      $hostName = (& hostname -s 2>$null)
    } elseif (Get-Command hostnamectl -ErrorAction SilentlyContinue) {
      $hostName = (& hostnamectl hostname 2>$null)
    }
  }

  $bold = if ($PSStyle) { $PSStyle.Bold } else { "$([char]27)[1m" }
  $reset = if ($PSStyle) { $PSStyle.Reset } else { "$([char]27)[0m" }
  Write-Host "${bold}Starting multiplexer (zellij)${reset}"
  & zellij attach -c $hostName
}
