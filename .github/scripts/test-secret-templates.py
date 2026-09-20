#!/usr/bin/env python3
"""Regression tests for the secret-lookup templates in home/.chezmoitemplates/.

`bw get item` emits explicit nulls ("notes": null, "login": null, a custom field
"value": null). Templates that treat `hasKey` as "has a usable value" then feed a
nil into `trim`/`regexMatch`, which aborts the whole `chezmoi apply`. Nothing else
in CI reaches these code paths: with `CI` set the templates short-circuit before
they ever call the vault.

The vault is faked with a stub `bw` executable on PATH that prints a crafted item,
so the real templates run unmodified through chezmoi's real `bitwarden` function.

Usage: .github/scripts/test-secret-templates.py   (requires `chezmoi` on PATH)
"""

import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# (template, secrets key, [(description, bw item, expected output)])
CASES = [
    ("get-github-token.tmpl", "aqua_github_token", [
        ("password set", {"login": {"password": "ghp_ok"}, "notes": None}, "ghp_ok"),
        ("empty password, notes null", {"login": {"password": ""}, "notes": None}, ""),
        ("password null, notes set", {"login": {"password": None}, "notes": "tok"}, "tok"),
        ("no login, notes null", {"notes": None}, ""),
        ("login null (secure note)", {"login": None, "notes": "tok"}, "tok"),
        ("custom field value null", {"fields": [{"name": "token", "value": None}]}, ""),
        ("custom field token", {"fields": [{"name": "token", "value": "ghp_f"}]}, "ghp_f"),
    ]),
    ("get-signing-key.tmpl", "git_signing_key", [
        ("sshKey.publicKey", {"sshKey": {"publicKey": "ssh-ed25519 KEY"}}, "ssh-ed25519 KEY"),
        ("notes null", {"notes": None}, ""),
        ("notes is a public key", {"notes": "ssh-ed25519 N"}, "ssh-ed25519 N"),
        ("notes null + publicKey field",
         {"notes": None, "fields": [{"name": "publicKey", "value": "ssh-ed25519 F"}]}, "ssh-ed25519 F"),
        ("publicKey field value null",
         {"notes": "x", "fields": [{"name": "publicKey", "value": None}]}, ""),
    ]),
    ("get-mcp-servers.tmpl", "mcp_servers", [
        ("notes hold yaml", {"notes": "servers:\n  a: {command: x}"}, "servers:\n  a: {command: x}"),
        ("notes null", {"notes": None}, "servers: {}"),
    ]),
]


def render(tmp, template, key, item):
    bw = os.path.join(tmp, "bin", "bw")
    with open(bw, "w") as f:
        f.write("#!/bin/sh\ncat <<'JSON'\n" + json.dumps(item) + "\nJSON\n")
    os.chmod(bw, 0o755)
    cfg = os.path.join(tmp, "chezmoi.toml")
    with open(cfg, "w") as f:
        f.write('[data.secrets]\n  %s = "bitwarden:item"\n' % key)
    env = dict(os.environ, PATH=os.path.join(tmp, "bin") + os.pathsep + os.environ["PATH"])
    # CI / NREDF_NO_BOOTSTRAP make the templates skip the vault entirely.
    env.pop("CI", None)
    env.pop("NREDF_NO_BOOTSTRAP", None)
    p = subprocess.run(
        ["chezmoi", "execute-template", "--source=" + ROOT, "--config", cfg,
         '{{ includeTemplate "%s" . }}' % template],
        capture_output=True, text=True, env=env, stdin=subprocess.DEVNULL)
    if p.returncode != 0:
        return False, "template error: " + (p.stderr.strip().splitlines() or ["?"])[-1]
    return True, p.stdout


def main():
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        os.mkdir(os.path.join(tmp, "bin"))
        for template, key, cases in CASES:
            print(template)
            for desc, item, want in cases:
                ok, got = render(tmp, template, key, item)
                if ok and got.strip() == want.strip():
                    print("  PASS  " + desc)
                else:
                    failures += 1
                    detail = got if not ok else "got %r, want %r" % (got, want)
                    print("  FAIL  %s -> %s" % (desc, detail))
    print("\n%d failure(s)" % failures)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
