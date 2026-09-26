# Universal archive extract/compress via ouch (https://github.com/ouch-org/ouch),
# which auto-detects format from the file extension so one function covers
# zip/tar/tar.gz/tar.zst/7z/rar/... instead of a per-format case statement.
# Same names and behavior as the bash/zsh/fish/nu versions.

function extract {
  if (-not (Get-Command ouch -ErrorAction SilentlyContinue)) {
    Write-Error 'command "ouch" does not exist on system'
    return
  }
  if ($args.Count -eq 0) {
    Write-Error 'Usage: extract <archive>...'
    return
  }
  & ouch decompress @args
}

# Short alias name, matching ouch's own `ouch d`/`ouch c` convention and the
# oh-my-zsh `x` alias this is meant to parallel.
function x {
  extract @args
}

function compress {
  if (-not (Get-Command ouch -ErrorAction SilentlyContinue)) {
    Write-Error 'command "ouch" does not exist on system'
    return
  }
  if ($args.Count -lt 2) {
    Write-Error 'Usage: compress <out> <files...>'
    return
  }
  $out = $args[0]
  $files = $args[1..($args.Count - 1)]
  & ouch compress @files $out
}
