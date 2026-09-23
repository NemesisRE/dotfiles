# PowerShell-only local functions

Drop `.ps1` files here — each one is dot-sourced automatically on shell
startup (`Get-ChildItem -Filter '*.ps1'`, so this README and anything else
that isn't `.ps1` is safely ignored).

```powershell
# example.ps1
function My-Function {
  "hello from a local function"
}
```

`../aliases.ps1` and `../modules.ps1` (both optional) work the same way for
a single alias file or extra module imports. For a simple alias or an extra
`$PATH` entry shared across every shell, `~/.config/nredf/local.yaml` is
usually less to write — see `~/.config/nredf/README.md` for the full
picture.
