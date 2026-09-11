# Compute file hashes - useful for checking successful downloads
function md5 { Get-FileHash -Algorithm MD5 $args }
function sha1 { Get-FileHash -Algorithm SHA1 $args }
function sha256 { Get-FileHash -Algorithm SHA256 $args }

# From https://github.com/Pscx/Pscx
function sudo() { Invoke-Elevated @args }

# Reload profile
function reload() { & ${PROFILE} }
