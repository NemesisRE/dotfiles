if (Get-Command kubectl -ErrorAction SilentlyContinue) {
  Set-Alias -Name k -Value kubectl -Option AllScope -Force
}
if (Get-Command Select-KubeNamespace -ErrorAction SilentlyContinue) {
  Set-Alias -Name kns -Value Select-KubeNamespace -Option AllScope -Force
}
if (Get-Command Select-KubeContext -ErrorAction SilentlyContinue) {
  Set-Alias -Name kctx -Value Select-KubeContext -Option AllScope -Force
}

# lazygit alias (matches bash/zsh lg)
if (Get-Command lazygit -ErrorAction SilentlyContinue) {
  Set-Alias -Name lg -Value lazygit -Option AllScope -Force
}

# lsd aliases (matches bash/zsh ll, la)
if (Get-Command lsd -ErrorAction SilentlyContinue) {
  function ll { lsd -lFh @args }
  function la { lsd -lAFh @args }
}
