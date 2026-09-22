# 🔐 Secrets & Multi-Store Management Guide

NREDF dotfiles feature a **pluggable, multi-store secret management architecture** powered by [chezmoi](https://chezmoi.io). It allows you to manage developer secrets (such as GitHub API tokens for [aqua](https://aquaproj.github.io/) and Git SSH commit signing keys) seamlessly without hardcoding credentials or duplicating them across multiple password managers.

---

## 🌟 Core Concepts

1. **Direct Machine Mapping**: Every machine's `~/.config/chezmoi/chezmoi.toml` declares where its credentials come from.
2. **Multi-Store Concurrency**: You can mix and match stores on a single deployment (e.g. personal secrets from **Bitwarden** and work secrets from **KeePassXC**).
3. **Zero Secret Duplication**: SSH keys and personal access tokens remain in their primary, canonical vault items (the same items used by Bitwarden/1Password SSH agents and your browser).
4. **URI-Based Routing**: Secret references use a lightweight URI syntax (`bitwarden:ItemName`, `keepassxc:ItemName`, `onepassword:ItemName`, or raw static string).
5. **CI & Offline Safe**: If running in CI or if a secret store CLI is not available, templates degrade gracefully without crashing.

---

## 🧭 Profile Presets

When running `chezmoi init` (or `chezmoi init --prompt`), you are prompted to choose a secrets profile preset:

| Preset | Description | Default Mappings |
| :--- | :--- | :--- |
| **`personal`** | Recommended for personal laptops & home workstations | `aqua_github_token`: `bitwarden:GitHub Token`<br>`git_signing_key`: `bitwarden:SSH Key`<br>`mcp_servers`: `bitwarden:mcp-servers` |
| **`work`** | Recommended for work / corporate environments | `aqua_github_token`: `bitwarden:GitHub Token`<br>`git_signing_key`: `keepassxc:Work/Git Signing Key`<br>`mcp_servers`: `keepassxc:Work/MCP Servers`<br>`keepassxc_db`: `~/Documents/Work/work.kdbx` |
| **`custom`** | Prompts for custom URIs or alternative stores (e.g. 1Password) | Custom paths, nested items, or direct UUIDs |
| **`none`** | Disables external secret stores | Relies purely on static string prompts |

---

## 🔗 URI Pointer Format

Secrets configured under `[data.secrets]` in `~/.config/chezmoi/chezmoi.toml` use prefix-based routing:

```toml
[data.secrets]
    profile = "work"
    aqua_github_token = "bitwarden:GitHub Token"
    git_signing_key   = "keepassxc:Work/Git Signing Key"
```

| Prefix | Secret Provider | Extraction Details |
| :--- | :--- | :--- |
| `bitwarden:<item>` or `bw:<item>` | Bitwarden CLI (`bw`) | **SSH Key**: `.sshKey.publicKey` (native SSH item), `.notes`, or field `publicKey`.<br>**Token**: `.login.password`, field `token`, `aqua_github_token`, or `notes`. |
| `keepassxc:<item>` | KeePassXC CLI (`keepassxc-cli`) | **SSH Key**: attribute `public_key` or entry `Notes`.<br>**Token**: entry `Password` or `Notes`. |
| `onepassword:<item>` or `op:<item>` | 1Password CLI (`op`) | **SSH Key**: field `public_key` or notes.<br>**Token**: item password or field `token`. |
| *(no prefix)* | Raw string fallback | Treated as a static string literal (e.g. `ssh-ed25519 AAA...`). |

---

## 🗄️ Multi-Store Hybrid Deployments

You can query multiple password managers in a single `chezmoi apply` run.

### Example: Personal Bitwarden + Work KeePassXC

On a work machine, you may want aqua package downloads authenticated via your personal GitHub token, while Git commits are signed with a corporate key inside KeePassXC.

In `~/.config/chezmoi/chezmoi.toml`:

```toml
# 1. Configure provider CLIs
[bitwarden]
    command = "bw"
    unlock = "auto"

[keepassxc]
    command = "keepassxc-cli"
    database = "C:/Users/username/Documents/Work/work.kdbx"
    prompt = true

# 2. Map credentials to their respective stores
[data.secrets]
    profile = "work"
    aqua_github_token = "bitwarden:GitHub Token"
    git_signing_key   = "keepassxc:Work/Git Signing Key"
```

During `chezmoi apply`:

1. Chezmoi calls `bw` to retrieve `GitHub Token` (prompting for unlock if locked).
2. Chezmoi calls `keepassxc-cli` to retrieve `Work/Git Signing Key` (prompting for KDBX password if required).
3. Both tools receive their credentials in a single apply step.

---

## ⚙️ Managed Secrets & Output Files

### 1. Aqua GitHub Token (`~/.config/nredf/aqua.env`)

* **Template**: `home/dot_config/nredf/private_aqua.env.tmpl`
* **Target**: `~/.config/nredf/aqua.env` (permissions `0600`)
* **Variables Exported**:

  ```bash
  AQUA_GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
  GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
  ```

* Automatically sourced by:
  * Bash / Zsh (`dot_local/share/nredf/shell/common/rc.tmpl`)
  * Fish (`dot_local/share/nredf/shell/fish/functions/nredf_aqua.fish`)
  * PowerShell (`Documents/PowerShell/NREDF-POSH/Defaults.ps1`)
  * Post-apply aqua run-onchange hooks on Linux, macOS, and Windows.
  * Nushell reads it too (`dot_local/share/nredf/shell/nu/functions/nredf_aqua.nu`), but — like PowerShell — *parses* it as plain `KEY=value` data rather than sourcing/evaluating it as code, since it's POSIX-shell syntax and neither nu nor PowerShell can execute that directly.

### 2. Git Commit Signing Key (`~/.config/git/config`)

* **Template**: `home/dot_config/git/config.tmpl`
* **Target**: `~/.config/git/config`
* **Output**:

  ```ini
  [user]
      signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@email.com"

  [commit]
      gpgsign = true

  [gpg]
      format = ssh
  ```

* When using Bitwarden or 1Password, the private key stays securely inside the password manager's desktop SSH Agent — only the public key string is rendered into `git/config`.

### 3. MCP Servers (`~/.config/nredf/mcp.json` and editor configs)

MCP server definitions usually carry bearer tokens and API keys, so they are kept in your vault rather than in this repo. `mcp_servers` points at a vault item whose **notes** hold the definitions as YAML (or JSON):

```yaml
servers:
  docs:
    url: https://mcp.example.com/mcp
    headers:
      Authorization: Bearer <token>
  local-tool:
    command: npx
    args: ["-y", "some-mcp-server"]
    env:
      API_KEY: <key>
```

* **Rendered to**: `~/.config/nredf/mcp.json` (the single private copy the sync scripts read), VS Code's `mcp.json`, the Cline settings file, and `~/.gemini/config/mcp_config.json`. Every one of these is `private_` (mode `0600`); VS Code's paths are per-OS (`~/.config/Code` on Linux only, `~/Library/Application Support/Code` on macOS, `%APPDATA%\Code` on Windows).
* **Claude Code**: `run_onchange_after_claude_mcp.sh.tmpl` (and its PowerShell twin) merges the servers into `~/.claude.json`.
  * It **merges** into your existing `mcpServers` rather than replacing them, so servers you added with `claude mcp add` survive.
  * If the vault is locked or the item is empty it does **nothing** instead of wiping the file. The trade-off: removing a server from the vault does not remove it from `~/.claude.json`.
* With `mcp_servers` empty, the editor files are still rendered but with no servers, and `~/.claude.json` is left untouched.

---

## 🛠️ Step-by-Step Setup

### Step 1: Prepare Vault Items

#### In Bitwarden

1. **GitHub Item**:
   * Create a **Login** or **Secure Note** named `GitHub Token`.
   * Put your GitHub Personal Access Token (PAT with `read:packages` or public repo access) in the **Password** field (or custom field `token`).
2. **SSH Key Item**:
   * Create an **SSH Key** item named `SSH Key`.
   * Store your private and public key. (Bitwarden Desktop SSH Agent will automatically serve this key for daily Git and SSH operations).

#### In KeePassXC (if using KeePassXC for work)

1. Create an entry named `Work/Git Signing Key`.
2. Add the public key in an attribute named `public_key` or in the entry **Notes**.

---

### Step 2: Configure Chezmoi

Run `chezmoi init`:

```bash
chezmoi init
```

> **Already initialised?** The prompts use `promptStringOnce`, which keeps the value stored in `~/.config/chezmoi/chezmoi.toml` and does not ask again. To change a preset or a vault item name, run `chezmoi init --prompt`, or edit that file directly.

Choose your preset:

* For personal machines, select `personal`.
* For work machines, select `work` and provide your `.kdbx` path.
* When prompted for `Git signing key`, leave it blank to automatically resolve from your secret store.

---

### Step 3: Apply Dotfiles

```bash
chezmoi apply
```

Chezmoi will unlock your secret store(s), retrieve the credentials, and populate your configurations.

---

## 🔍 Verification & Troubleshooting

### Test Secret Resolution Directly

You can test template resolution in your terminal without modifying files:

```bash
# Verify Git signing key resolution
chezmoi execute-template '{{ includeTemplate "get-signing-key.tmpl" . }}'

# Verify GitHub token resolution
chezmoi execute-template '{{ includeTemplate "get-github-token.tmpl" . }}'
```

### Dry-Run Apply

```bash
chezmoi apply --dry-run
```

### Checking `aqua.env`

```bash
# On Unix:
cat ~/.config/nredf/aqua.env

# On Windows (PowerShell):
Get-Content "$HOME\.config\nredf\aqua.env"
```

### CI / Headless Mode

When running in automated CI environments (`CI=true`) or when `NREDF_NO_BOOTSTRAP=1` is set, all secret lookups safely return empty strings, preventing interactive CLI prompts or failed builds.
