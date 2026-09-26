# Shared Windows environment setup for yazi (and HOME), included by
# run_onchange_after_windows_yazi-plugins.ps1.tmpl via includeTemplate. It used to be
# copied into three places (that hook, the winget prerequisites hook and bootstrap.ps1).
# The profile (pwsh/Defaults.ps1) repeats the per-session half at startup; this
# persists it to the User environment for yazi launched from outside NREDF's profile.
# Every step is best-effort: a hook must never abort `chezmoi apply`.

function NREDF_SetUserEnv {
    param([string]$Name, [string]$Value)
    [System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Process)
    if ([System.Environment]::GetEnvironmentVariable($Name, [System.EnvironmentVariableTarget]::User) -ne $Value) {
        [System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::User)
        Write-Host "    Configured ${Name}: $Value"
    }
}

# Yazi needs `file` for MIME detection; on Windows it ships with Git for Windows.
$yaziFileCandidates = @(
    $env:YAZI_FILE_ONE
    (Join-Path $env:ProgramFiles "Git\usr\bin\file.exe")
    (Join-Path ${env:ProgramFiles(x86)} "Git\usr\bin\file.exe")
    (Join-Path $env:LOCALAPPDATA "Programs\Git\usr\bin\file.exe")
)
$gitCmd = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($gitCmd) {
    $yaziFileCandidates += (Join-Path (Split-Path (Split-Path $gitCmd.Source)) "usr\bin\file.exe")
}
$yaziFile = $yaziFileCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if ($yaziFile) {
    NREDF_SetUserEnv 'YAZI_FILE_ONE' $yaziFile
} else {
    Write-Warning "Git for Windows' file.exe not found; yazi cannot detect MIME types until Git is installed."
}

# Point yazi at the chezmoi-managed config, and junction %APPDATA%\yazi\config to it
# for yazi started without YAZI_CONFIG_HOME in its environment.
$yaziConfigDir = Join-Path $HOME ".config\yazi"
NREDF_SetUserEnv 'YAZI_CONFIG_HOME' $yaziConfigDir

$yaziAppDataDir = Join-Path $env:APPDATA "yazi"
$yaziAppDataConfig = Join-Path $yaziAppDataDir "config"
if (-not (Test-Path -LiteralPath $yaziAppDataConfig)) {
    try {
        if (-not (Test-Path -LiteralPath $yaziAppDataDir)) {
            New-Item -ItemType Directory -Path $yaziAppDataDir -Force -ErrorAction Stop | Out-Null
        }
        New-Item -ItemType Junction -Path $yaziAppDataConfig -Target $yaziConfigDir -ErrorAction Stop | Out-Null
        Write-Host "    Linked $yaziAppDataConfig -> $yaziConfigDir"
    } catch {
        Write-Warning "Could not create the yazi config junction ${yaziAppDataConfig}: $_"
    }
}

# Windows has no HOME by default; nvim (astrocommunity's chezmoi pack) and other
# POSIX-minded tools read it.
NREDF_SetUserEnv 'HOME' $HOME
