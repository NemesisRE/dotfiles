# Kubernetes aliases (matches bash/zsh k, kctx, kns)
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
  Set-Alias -Name k -Value kubectl -Option AllScope -Force
}
if (Get-Command Select-KubeNamespace -ErrorAction SilentlyContinue) {
  Set-Alias -Name kns -Value Select-KubeNamespace -Option AllScope -Force
} elseif (Get-Command kubens -ErrorAction SilentlyContinue) {
  Set-Alias -Name kns -Value kubens -Option AllScope -Force
} elseif (Get-Command kubectl -ErrorAction SilentlyContinue) {
  function kns { kubectl ns @args }
}

if (Get-Command Select-KubeContext -ErrorAction SilentlyContinue) {
  Set-Alias -Name kctx -Value Select-KubeContext -Option AllScope -Force
} elseif (Get-Command kubectx -ErrorAction SilentlyContinue) {
  Set-Alias -Name kctx -Value kubectx -Option AllScope -Force
} elseif (Get-Command kubectl -ErrorAction SilentlyContinue) {
  function kctx { kubectl ctx @args }
}

# lazygit alias (matches bash/zsh lg)
if (Get-Command lazygit -ErrorAction SilentlyContinue) {
  Set-Alias -Name lg -Value lazygit -Option AllScope -Force
}

# lsd aliases (matches bash/zsh ls, ll, la)
if (Get-Command lsd -ErrorAction SilentlyContinue) {
  Set-Alias -Name ls -Value lsd -Option AllScope -Force
  function ll { lsd -lFh @args }
  function la { lsd -lAFh @args }
}

# grep alias (matches bash/zsh grep)
if (Get-Command grep -ErrorAction SilentlyContinue) {
  function grep { & (Get-Command -CommandType Application grep) --color=auto @args }
} elseif (Get-Command rg -ErrorAction SilentlyContinue) {
  Set-Alias -Name grep -Value rg -Option AllScope -Force
}

# Docker container IP listing (matches bash/zsh dipls)
if (Get-Command docker -ErrorAction SilentlyContinue) {
  function dipls {
    docker ps -q | ForEach-Object {
      docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}`t{{.Name}}' $_
    }
  }
}
