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

# lazygit alias (matches bash/zsh lzg, lg)
if (Get-Command lazygit -ErrorAction SilentlyContinue) {
  Set-Alias -Name lzg -Value lazygit -Option AllScope -Force
  Set-Alias -Name lg -Value lazygit -Option AllScope -Force
}

# lazydocker alias (matches bash/zsh lzd)
if (Get-Command lazydocker -ErrorAction SilentlyContinue) {
  Set-Alias -Name lzd -Value lazydocker -Option AllScope -Force
}

# lazyjournal alias (matches bash/zsh lzj, lj)
if (Get-Command lazyjournal -ErrorAction SilentlyContinue) {
  Set-Alias -Name lzj -Value lazyjournal -Option AllScope -Force
  Set-Alias -Name lj -Value lazyjournal -Option AllScope -Force
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

# Neovim aliases
if (Get-Command nvim -ErrorAction SilentlyContinue) {
  Set-Alias -Name vim -Value nvim -Option AllScope -Force
  Set-Alias -Name vi -Value nvim -Option AllScope -Force
}

# bat alias (syntax-highlighted cat)
if (Get-Command bat -ErrorAction SilentlyContinue) {
  function cat { bat --paging=never @args }
}

# Utility command parity (which, touch)
if (-not (Get-Command which -ErrorAction SilentlyContinue)) {
  function which { Get-Command @args }
}
if (-not (Get-Command touch -ErrorAction SilentlyContinue)) {
  function touch {
    foreach ($file in $args) {
      if (Test-Path $file) {
        (Get-Item $file).LastWriteTime = Get-Date
      } else {
        New-Item -ItemType File -Path $file -Force | Out-Null
      }
    }
  }
}

