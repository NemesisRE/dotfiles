# Security Advisory: Potential Secret Exposure and Unpinned Dependencies in Dotfiles Configuration

## Summary
A security review of this dotfiles repository has identified potential risks regarding the accidental exposure of sensitive credentials in the Git history and the execution of unpinned third-party plugins/binaries. This configuration manages shells (Zsh, Bash, PowerShell) and tools via chezmoi, aqua, and sheldon.

| Attribute | Value |
| :--- | :--- |
| **Advisory ID** | GHSA-xxxx-xxxx-xxxx (Will be assigned by GitHub) |
| **Severity** | High / Moderate |
| **Affected Components** | chezmoi templates, sheldon plugins, aqua tools |
| **Remediation** | Secret rotation, strict version pinning, and configuration updates |

---

## Impact
Depending on the exact setup of your local environment, the risks include:

1. Credential Leakage (Chezmoi): If API keys, SSH keys, or personal tokens were stored directly in plain text within chezmoi templates instead of using encrypted password manager integrations, they could be exposed publicly in the repository history.
2. Supply Chain & Arbitrary Code Execution (Sheldon & Aqua): If sheldon (Zsh/Bash plugin manager) or aqua (CLI tool manager) pull plugins or binaries directly from main/latest branches without explicit version tags, a compromise of an upstream repository could lead to malicious code execution during shell startup.

---

## Remediation & Mitigation

### 1. For Chezmoi (Secret Management)
* Action: Never commit plain text secrets. Utilize Chezmoi's built-in integrations for password managers (e.g., 1Password, Bitwarden, KeePassXC).
* Example (Bitwarden Integration):
  ```
  github_token = {{ bitwarden "item" "my-github-token" }}
  ```
* Purge History: If secrets were already pushed to GitHub, rotate them immediately. Use tools like git-filter-repo or BFG Repo-Cleaner to completely purge the keys from your repository history.

### 2. For Sheldon (Zsh/Bash Plugins)
* Action: Ensure all plugins in plugins.toml are pinned to a specific tag or exact commit hash instead of tracking a mutable branch like master or main.
* Secure Example:
  ```
  [plugins.zsh-autosuggestions]
  github = "zsh-users/zsh-autosuggestions"
  tag = "v0.7.0"
  ```

### 3. For Aqua (CLI Tools)
* Action: Lock tool versions in aqua.yaml and always generate/commit the aqua-checksums.json file to verify the integrity of downloaded binaries.
* Command: Run "aqua g -i <package>" to always append exact versions.

---

## References
* Chezmoi Security Best Practices: https://www.chezmoi.io/user-guide/security/
* Sheldon Configuration Documentation: https://sheldon.cli.rs/
* Aqua CLI Version Manager Security: https://aquaproj.github.io/

---

### Credits
We would like to thank the community for promoting secure dotfiles management and responsible disclosure practices.
