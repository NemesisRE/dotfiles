# chezmoi-managed nu function file.
# -----------------------------------------------------------------------------
# Bitwarden session management with OS keychain / biometric unlock.
#
# Port of common/functions/nredf_bw.bash — see that file for the full design
# writeup. Backends: macOS `security`, Linux KDE Wallet (gdbus D-Bus calls,
# falling back to `kwallet-query`), GNOME `secret-tool`, plaintext file.
#
# Every function here that ends up setting $env.BW_SESSION is `def --env`;
# the keychain backend probing/read/write/delete helpers are plain `def`s
# that only return values or touch external state, never $env.
# -----------------------------------------------------------------------------

def nredf-bw-service []: nothing -> string { "nredf.bw_session" }

def nredf-bw-account []: nothing -> string {
    let u = ($env.USER? | default "")
    if not ($u | is-empty) { $u } else { (^id -un | str trim) }
}

def nredf-bw-marker []: nothing -> string {
    let base = ($env.XDG_RUNTIME_DIR? | default ($env.TMPDIR? | default "/tmp"))
    $"($base)/nredf_bw_(nredf-bw-account).active"
}

def nredf-bw-kwallet-service []: nothing -> string {
    if (which gdbus | is-empty) {
        return ""
    }
    for s in ["org.kde.kwalletd6" "org.kde.kwalletd5" "org.kde.kwalletd"] {
        let mod = ($s | split row "." | last)
        let en = (^gdbus call --session --dest $s --object-path $"/modules/($mod)" --method org.kde.KWallet.isEnabled | complete | get stdout)
        if ($en | str contains "true") {
            return $s
        }
        if ($en | str contains "false") {
            continue
        }
        if (^gdbus call --session --dest $s --object-path $"/modules/($mod)" --method org.freedesktop.DBus.Peer.Ping | complete | get exit_code) == 0 {
            return $s
        }
    }
    ""
}

def nredf-bw-kwallet-open [service: string, wallet: string = "kdewallet"]: nothing -> string {
    let mod = ($service | split row "." | last)
    let res = (^gdbus call --session --dest $service --object-path $"/modules/($mod)" --method org.kde.KWallet.open $wallet 0 nredf | complete | get stdout)
    if ($res | is-empty) {
        return ""
    }
    let handle = ($res | str replace --regex '.*\((?:[a-zA-Z0-9]+ )?(-?[0-9]+).*' '$1')
    if ($handle =~ '^[0-9]+$') { $handle } else { "" }
}

def nredf-bw-keychain-backend []: nothing -> string {
    if $env.NREDF_OS == "macos" {
        return "macos"
    }
    if (not (which kwallet-query | is-empty)) or ((not (which gdbus | is-empty)) and (not ((nredf-bw-kwallet-service) | is-empty))) {
        return "kwallet"
    }
    if not (which secret-tool | is-empty) {
        return "secret-tool"
    }
    "fallback"
}

def nredf-bw-keychain-get []: nothing -> string {
    let backend = (nredf-bw-keychain-backend)
    let account = (nredf-bw-account)
    let service = (nredf-bw-service)
    mut token = ""

    if $backend == "macos" {
        for key in [$service "bw_session" "BW_SESSION"] {
            $token = (^security find-generic-password -s $key -a $account -w | complete | get stdout | str trim)
            if not ($token | is-empty) { break }
        }
    } else if $backend == "kwallet" {
        if not (which gdbus | is-empty) {
            let kservice = (nredf-bw-kwallet-service)
            if not ($kservice | is-empty) {
                let mod = ($kservice | split row "." | last)
                mut wallets = ["kdewallet"]
                for m in ["networkWallet" "localWallet"] {
                    let def_w_raw = (^gdbus call --session --dest $kservice --object-path $"/modules/($mod)" --method $"org.kde.KWallet.($m)" | complete | get stdout)
                    let def_w = ($def_w_raw | str replace --regex ".*'([^']*)'.*" '$1')
                    if (not ($def_w | is-empty)) and (not ($def_w in $wallets)) {
                        $wallets = ($wallets | append $def_w)
                    }
                }

                for w in $wallets {
                    if not ($token | is-empty) { break }
                    let handle = (nredf-bw-kwallet-open $kservice $w)
                    if ($handle | is-empty) { continue }

                    mut folders = ["Passwords" "nredf"]
                    let f_raw = (^gdbus call --session --dest $kservice --object-path $"/modules/($mod)" --method org.kde.KWallet.folderList $handle | complete | get stdout)
                    if not ($f_raw | is-empty) {
                        let cleaned = ($f_raw | ^tr -d "[],()'")
                        for f_item in ($cleaned | split row " ") {
                            if (not ($f_item | is-empty)) and (not ($f_item in $folders)) {
                                $folders = ($folders | append $f_item)
                            }
                        }
                    }

                    for folder in $folders {
                        if not ($token | is-empty) { break }
                        for key in [$service "bw_session" "BW_SESSION" "bitwarden" "Bitwarden" "bw"] {
                            let raw = (^gdbus call --session --dest $kservice --object-path $"/modules/($mod)" --method org.kde.KWallet.readPassword $handle $folder $key nredf | complete | get stdout)
                            let candidate = ($raw | str replace --regex ".*'([^']*)'.*" '$1')
                            if (not ($candidate | is-empty)) and ($candidate != $raw) {
                                $token = $candidate
                                break
                            }
                        }
                    }
                }
            }
        }

        if ($token | is-empty) and (not (which kwallet-query | is-empty)) {
            for folder in ["Passwords" "nredf"] {
                if not ($token | is-empty) { break }
                for key in [$service "bw_session" "BW_SESSION" "bitwarden" "Bitwarden" "bw"] {
                    let candidate = (^kwallet-query --read-password $key --folder $folder kdewallet | complete | get stdout | str trim)
                    if (not ($candidate | is-empty)) and (not ($candidate | str contains "cannot be read")) and (not ($candidate | str contains "kann nicht gelesen werden")) {
                        $token = $candidate
                        break
                    }
                }
            }
        }
    } else if $backend == "secret-tool" {
        for key in [$service "bw_session"] {
            $token = (^secret-tool lookup service $key username $account | complete | get stdout | str trim)
            if not ($token | is-empty) { break }
            $token = (^secret-tool lookup service $key | complete | get stdout | str trim)
            if not ($token | is-empty) { break }
        }
    } else {
        let f = (($env.XDG_RUNTIME_DIR? | default "/tmp") | path join "nredf_bw_session")
        if ($f | path exists) {
            $token = (open $f | into string | str trim)
        }
    }

    $token
}

def nredf-bw-keychain-set [token: string] {
    let backend = (nredf-bw-keychain-backend)
    let account = (nredf-bw-account)
    let service = (nredf-bw-service)

    if $backend == "macos" {
        for k in [$service "bw_session"] {
            ^security delete-generic-password -s $k -a $account | complete
            ^security add-generic-password -s $k -a $account -w $token -U | complete
        }
    } else if $backend == "kwallet" {
        mut saved = false
        if not (which gdbus | is-empty) {
            let kservice = (nredf-bw-kwallet-service)
            if not ($kservice | is-empty) {
                let handle = (nredf-bw-kwallet-open $kservice)
                if not ($handle | is-empty) {
                    let mod = ($kservice | split row "." | last)
                    for k in [$service "bw_session"] {
                        let res = (^gdbus call --session --dest $kservice --object-path $"/modules/($mod)" --method org.kde.KWallet.writePassword $handle Passwords $k $token nredf | complete | get stdout)
                        if ($res | str contains "(0,)") { $saved = true }
                    }
                    if not $saved {
                        let has_f = (^gdbus call --session --dest $kservice --object-path $"/modules/($mod)" --method org.kde.KWallet.hasFolder $handle nredf | complete | get stdout)
                        if not ($has_f | str contains "true") {
                            ^gdbus call --session --dest $kservice --object-path $"/modules/($mod)" --method org.kde.KWallet.createFolder $handle nredf | complete
                        }
                        for k in [$service "bw_session"] {
                            let res = (^gdbus call --session --dest $kservice --object-path $"/modules/($mod)" --method org.kde.KWallet.writePassword $handle nredf $k $token nredf | complete | get stdout)
                            if ($res | str contains "(0,)") { $saved = true }
                        }
                    }
                }
            }
        }
        if (not $saved) and (not (which kwallet-query | is-empty)) {
            for k in [$service "bw_session"] {
                let r1 = ($token | ^kwallet-query --write-password $k --folder Passwords kdewallet | complete)
                if $r1.exit_code != 0 {
                    $token | ^kwallet-query --write-password $k --folder nredf kdewallet | complete
                }
            }
        }
    } else if $backend == "secret-tool" {
        for k in [$service "bw_session"] {
            $token | ^secret-tool store --label "NREDF Bitwarden session" service $k username $account | complete
        }
    } else {
        let f = (($env.XDG_RUNTIME_DIR? | default "/tmp") | path join "nredf_bw_session")
        $token | save --force $f
        ^chmod 600 $f
    }

    touch (nredf-bw-marker)
}

def nredf-bw-keychain-del [] {
    let backend = (nredf-bw-keychain-backend)
    let account = (nredf-bw-account)
    let service = (nredf-bw-service)

    if $backend == "macos" {
        for key in [$service "bw_session" "BW_SESSION"] {
            ^security delete-generic-password -s $key -a $account | complete
        }
    } else if $backend == "kwallet" {
        if not (which gdbus | is-empty) {
            let kservice = (nredf-bw-kwallet-service)
            if not ($kservice | is-empty) {
                let handle = (nredf-bw-kwallet-open $kservice)
                if not ($handle | is-empty) {
                    let mod = ($kservice | split row "." | last)
                    for folder in ["Passwords" "nredf"] {
                        for key in [$service "bw_session" "BW_SESSION"] {
                            ^gdbus call --session --dest $kservice --object-path $"/modules/($mod)" --method org.kde.KWallet.removeEntry $handle $folder $key nredf | complete
                        }
                    }
                }
            }
        }
        if not (which kwallet-query | is-empty) {
            for folder in ["Passwords" "nredf"] {
                for key in [$service "bw_session" "BW_SESSION"] {
                    ^kwallet-query --delete-entry $key --folder $folder kdewallet | complete
                }
            }
        }
    } else if $backend == "secret-tool" {
        for key in [$service "bw_session"] {
            ^secret-tool clear service $key username $account | complete
        }
    } else {
        rm --force (($env.XDG_RUNTIME_DIR? | default "/tmp") | path join "nredf_bw_session")
    }

    rm --force (nredf-bw-marker)
}

def nredf-bw-secret-configured []: nothing -> bool {
    let config_dir = ($env.XDG_CONFIG_HOME | path join "chezmoi")
    for c in [
        ($config_dir | path join "chezmoi.toml")
        ($config_dir | path join "chezmoi.yaml")
        ($config_dir | path join "chezmoi.json")
        ($env.HOME | path join ".config" "chezmoi" "chezmoi.toml")
        ($env.HOME | path join ".config" "chezmoi" "chezmoi.yaml")
        ($env.HOME | path join ".chezmoi.toml")
        ($env.HOME | path join ".chezmoi.yaml")
    ] {
        if not ($c | path exists) { continue }
        let content = (open $c | into string)
        if ($content =~ '(?m)^[ \t]*\[(data\.)?bitwarden\]') { return true }
        if ($content =~ '["''[ \t](bitwarden|bw):') { return true }
        if ($content =~ '\{\{[ \t]*(\([ \t]*)?bitwarden[ \t]') { return true }
    }

    let src_dir = ($env.NREDF_DOT_PATH? | default ($env.HOME | path join ".local" "share" "chezmoi"))
    let data_dir = ($src_dir | path join "home" ".chezmoidata")
    if ($data_dir | path exists) {
        let hits = (^grep -rEl "[\"'[:blank:]](bitwarden|bw):" $data_dir | complete)
        if ($hits.exit_code == 0) and (not ($hits.stdout | is-empty)) { return true }
    }
    let data_file = ($src_dir | path join "home" ".chezmoidata.yaml")
    if ($data_file | path exists) {
        let content = (open $data_file | into string)
        if ($content =~ '["''[ \t](bitwarden|bw):') { return true }
    }

    false
}

def --env nredf-bw-do-unlock [] {
    if (which bw | is-empty) {
        print --stderr "Bitwarden CLI (bw) is not installed. Run: aqua install"
        return
    }

    mut session = ""
    if (^bw login --check | complete | get exit_code) != 0 {
        print --stderr "Bitwarden: not logged in — running bw login"
        let r = (^bw login --raw | complete)
        if $r.exit_code != 0 { return }
        $session = ($r.stdout | str trim)
    } else {
        print --stderr "Bitwarden: vault locked — running bw unlock"
        let r = (^bw unlock --raw | complete)
        if $r.exit_code != 0 { return }
        $session = ($r.stdout | str trim)
    }

    if ($session | is-empty) {
        print --stderr "Bitwarden: unlock returned an empty session token"
        return
    }

    nredf-bw-keychain-set $session
    $env.BW_SESSION = $session
}

# Public: nredf-bw-restore-session
# Restores BW_SESSION from the OS keychain if not already set. Fast and
# non-blocking: never prompts, suitable for shell startup.
def --env nredf-bw-restore-session [] {
    if not ($env.BW_SESSION? | default "" | is-empty) {
        return
    }
    let cached = (nredf-bw-keychain-get)
    if not ($cached | is-empty) {
        $env.BW_SESSION = $cached
        touch (nredf-bw-marker)
    }
}

# Public: nredf-bw-ensure-session
# Ensures BW_SESSION is set and valid.
def --env nredf-bw-ensure-session [--force] {
    if (which bw | is-empty) {
        print --stderr "Bitwarden CLI (bw) is not installed. Run: aqua install"
        return false
    }

    if not ($env.BW_SESSION? | default "" | is-empty) {
        if (^bw unlock --check | complete | get exit_code) == 0 {
            nredf-bw-keychain-set $env.BW_SESSION
            return true
        }
        hide-env --ignore-errors BW_SESSION
    }

    let cached_session = (nredf-bw-keychain-get)
    if not ($cached_session | is-empty) {
        $env.BW_SESSION = $cached_session
        if (^bw unlock --check | complete | get exit_code) == 0 {
            return true
        }
        hide-env --ignore-errors BW_SESSION
        nredf-bw-keychain-del
    }

    if (not $force) and (not (nredf-bw-secret-configured)) {
        return true
    }

    nredf-bw-do-unlock
    not ($env.BW_SESSION? | default "" | is-empty)
}

# Public: bwu — Bitwarden Unlock.
def --env bwu [] {
    if (not ($env.BW_SESSION? | default "" | is-empty)) and ((^bw unlock --check | complete | get exit_code) == 0) {
        nredf-bw-keychain-set $env.BW_SESSION
        print "\e[1;32m✔ Bitwarden vault already unlocked \(keychain synchronized\)\e[0m"
        return
    }

    let cached_session = (nredf-bw-keychain-get)
    if not ($cached_session | is-empty) {
        $env.BW_SESSION = $cached_session
        if (^bw unlock --check | complete | get exit_code) == 0 {
            nredf-bw-keychain-set $env.BW_SESSION
            print "\e[1;32m✔ Bitwarden vault unlocked from keychain\e[0m"
            return
        }
        hide-env --ignore-errors BW_SESSION
        nredf-bw-keychain-del
    }

    if (nredf-bw-ensure-session --force) {
        print "\e[1;32m✔ Bitwarden vault unlocked\e[0m"
    } else {
        print --stderr "\e[1;31m✘ Failed to unlock Bitwarden vault\e[0m"
    }
}

# Public: bwlock — lock the vault and wipe the keychain entry.
def --env bwlock [] {
    nredf-bw-keychain-del

    if not ($env.BW_SESSION? | default "" | is-empty) {
        ^bw lock | complete
        hide-env --ignore-errors BW_SESSION
    }

    print "\e[1;33m⚿ Bitwarden vault locked and session cleared\e[0m"
}
