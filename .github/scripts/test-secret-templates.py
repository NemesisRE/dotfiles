#!/usr/bin/env python3
"""Regression tests for the secret-lookup templates in home/.chezmoitemplates/.

`bw get item` emits explicit nulls ("notes": null, "login": null, a custom field
"value": null), and `op item get` omits keys outright (a field left empty has no
"value", a field may have no "label"). Templates that treat `hasKey` as "has a
usable value", or read `.value` directly, then feed a nil into `trim`/`eq`/
`regexMatch`, which aborts the whole `chezmoi apply`. Nothing else in CI reaches
these code paths: with `CI` set the templates short-circuit before they ever
call the vault.

Each vault is faked with a stub executable on PATH (`bw`, `op`, `keepassxc-cli`)
that prints a crafted item, so the real templates run unmodified through
chezmoi's real `bitwarden`/`onepassword`/`keepassxc` functions. The `op` stub
also asserts the item name reaches `op item get` as the item, not the vault.

Usage: .github/scripts/test-secret-templates.py   (requires `chezmoi` on PATH)
"""

import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

OP_ITEM = "MyItem"


def kp(show, **attrs):
    """A keepassxc entry: `show` output lines, plus custom attributes."""
    return {"show": show, "attrs": attrs}


# (template, secrets key, [(description, vault, item, expected output[, env])])
# vault is "bw", "op" or "kp". An expected output of None means "must fail".
CASES = [
    ("get-github-token.tmpl", "aqua_github_token", [
        ("password set", "bw", {"login": {"password": "ghp_ok"}, "notes": None}, "ghp_ok"),
        ("empty password, notes null", "bw", {"login": {"password": ""}, "notes": None}, ""),
        ("password null, notes set", "bw", {"login": {"password": None}, "notes": "tok"}, "tok"),
        ("no login, notes null", "bw", {"notes": None}, ""),
        ("login null (secure note)", "bw", {"login": None, "notes": "tok"}, "tok"),
        ("custom field value null", "bw", {"fields": [{"name": "token", "value": None}]}, ""),
        ("custom field token", "bw", {"fields": [{"name": "token", "value": "ghp_f"}]}, "ghp_f"),
        ("fields without a match fall back to notes", "bw",
         {"fields": [{"name": "user", "value": "me"}], "notes": "tok_n"}, "tok_n"),
        ("fields null, notes set", "bw", {"fields": None, "notes": "tok_n"}, "tok_n"),
        ("field without a name", "bw", {"fields": [{"value": "x"}], "notes": None}, ""),
        ("NREDF_NO_BOOTSTRAP=true skips the vault", "bw",
         {"login": {"password": "ghp_ok"}}, "", {"NREDF_NO_BOOTSTRAP": "true"}),
        ("op password field", "op",
         {"fields": [{"id": "password", "label": "password", "value": "ghp_op"}]}, "ghp_op"),
        ("op field missing value and label", "op",
         {"fields": [{"id": "password"}, {"id": "username"}]}, ""),
        ("op no fields key", "op", {"id": "abc", "title": "t"}, ""),
        ("op token by label", "op", {"fields": [{"id": "x1", "label": "token", "value": "ghp_l"}]}, "ghp_l"),
        ("op falls back to notes", "op",
         {"fields": [{"id": "password"},
                     {"id": "notesPlain", "purpose": "NOTES", "label": "notesPlain", "value": "tok_n"}]},
         "tok_n"),
        ("keepassxc password", "kp", kp("Title: t\nPassword: ghp_k\nNotes: n\n"), "ghp_k"),
        ("keepassxc empty password, notes", "kp", kp("Title: t\nPassword: \nNotes: tok_n\n"), "tok_n"),
        ("keepassxc neither", "kp", kp("Title: t\n"), ""),
    ]),
    ("get-signing-key.tmpl", "git_signing_key", [
        ("sshKey.publicKey", "bw", {"sshKey": {"publicKey": "ssh-ed25519 KEY"}}, "ssh-ed25519 KEY"),
        ("notes null", "bw", {"notes": None}, ""),
        ("notes is a public key", "bw", {"notes": "ssh-ed25519 N"}, "ssh-ed25519 N"),
        ("notes null + publicKey field", "bw",
         {"notes": None, "fields": [{"name": "publicKey", "value": "ssh-ed25519 F"}]}, "ssh-ed25519 F"),
        ("publicKey field value null", "bw",
         {"notes": "x", "fields": [{"name": "publicKey", "value": None}]}, ""),
        ("NREDF_NO_BOOTSTRAP=true skips the vault", "bw",
         {"sshKey": {"publicKey": "ssh-ed25519 KEY"}}, "", {"NREDF_NO_BOOTSTRAP": "true"}),
        ("op public_key field", "op",
         {"fields": [{"id": "public_key", "label": "public key", "value": "ssh-ed25519 OP"}]},
         "ssh-ed25519 OP"),
        ("op field missing value and label", "op",
         {"fields": [{"id": "public_key"}, {"id": "private_key"}]}, ""),
        ("op notes hold the key", "op",
         {"fields": [{"id": "notesPlain", "purpose": "NOTES", "value": "ssh-ed25519 ON"}]},
         "ssh-ed25519 ON"),
        ("op notes are not a key", "op",
         {"fields": [{"id": "notesPlain", "purpose": "NOTES", "value": "hello"}]}, ""),
        ("keepassxc notes hold the key", "kp", kp("Title: t\nNotes: ssh-ed25519 KN\n"), "ssh-ed25519 KN"),
        ("keepassxc public_key attribute", "kp",
         kp("Title: t\nNotes: other\n", public_key="ssh-ed25519 KA"), "ssh-ed25519 KA"),
        # keepassxc-cli mode can only read a custom attribute with
        # keepassxcAttribute, which fails when it is missing; that is the one
        # lookup left that aborts on a key-less entry (see get-signing-key.tmpl).
        ("keepassxc no key anywhere fails loudly", "kp", kp("Title: t\nNotes: other\n"), None),
    ]),
    ("get-mcp-servers.tmpl", "mcp_servers", [
        ("notes hold yaml", "bw", {"notes": "servers:\n  a: {command: x}"}, "servers:\n  a: {command: x}"),
        ("notes null", "bw", {"notes": None}, "servers: {}"),
        ("NREDF_NO_BOOTSTRAP=true skips the vault", "bw",
         {"notes": "servers:\n  a: {command: x}"}, "servers: {}", {"NREDF_NO_BOOTSTRAP": "true"}),
        ("op notes field", "op",
         {"fields": [{"id": "notesPlain", "purpose": "NOTES", "value": "servers:\n  b: {command: y}"}]},
         "servers:\n  b: {command: y}"),
        ("op notes field without value", "op",
         {"fields": [{"id": "notesPlain", "purpose": "NOTES"}]}, "servers: {}"),
        ("keepassxc notes", "kp", kp("Title: t\nNotes: servers:\n  c: {command: z}\n"),
         "servers:\n  c: {command: z}"),
    ]),
]

REFS = {"bw": "bitwarden:item", "op": "op:" + OP_ITEM, "kp": "keepassxc:Group/Entry"}


def write_stubs(bindir, vault, item):
    """(Re)write the stub for `vault` so it prints `item`."""
    if vault == "bw":
        body = "cat <<'JSON'\n%s\nJSON\n" % json.dumps(item)
        name = "bw"
    elif vault == "op":
        # `op [--session T] item get --format json <item> [--vault V]`: the item
        # name must directly follow `--format json` and end the command line (no
        # --vault), or chezmoi was handed the item name as the vault.
        body = (
            'if [ "$1" = signin ]; then echo stub-session; exit 0; fi\n'
            'case "$* " in *"item get --format json %s ") ;;\n'
            '  *) echo "stub op: bad args: $*" >&2; exit 1 ;; esac\n'
            "cat <<'JSON'\n%s\nJSON\n" % (OP_ITEM, json.dumps(item))
        )
        name = "op"
    else:
        # `keepassxc-cli show <db> <entry> [--attributes A] --quiet --show-protected`
        cases = "".join(
            "    %s) printf '%%s\\n' %s ;;\n" % (k, json.dumps(v)) for k, v in item["attrs"].items())
        body = (
            'attr=""; prev=""\n'
            'for a in "$@"; do [ "$prev" = --attributes ] && attr="$a"; prev="$a"; done\n'
            'if [ -z "$attr" ]; then\n'
            "cat <<'SHOW'\n%sSHOW\nexit 0\nfi\n"
            'case "$attr" in\n%s'
            '    *) echo "ERROR: unknown attribute $attr." >&2; exit 1 ;;\n'
            "esac\n" % (item["show"], cases)
        )
        name = "keepassxc-cli"
    path = os.path.join(bindir, name)
    with open(path, "w") as f:
        f.write("#!/bin/sh\n" + body)
    os.chmod(path, 0o755)


def render(tmp, template, key, vault, item, extra_env):
    bindir = os.path.join(tmp, "bin")
    write_stubs(bindir, vault, item)
    cfg = os.path.join(tmp, "chezmoi.toml")
    with open(cfg, "w") as f:
        f.write('[data.secrets]\n  %s = "%s"\n' % (key, REFS[vault]))
        f.write('[keepassxc]\n  database = "%s"\n  prompt = false\n'
                % os.path.join(tmp, "stub.kdbx"))
        f.write('[onepassword]\n  prompt = false\n')
    env = dict(os.environ, PATH=bindir + os.pathsep + os.environ["PATH"])
    # CI / NREDF_NO_BOOTSTRAP make the templates skip the vault entirely.
    env.pop("CI", None)
    env.pop("NREDF_NO_BOOTSTRAP", None)
    env.update(extra_env)
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
            for case in cases:
                desc, vault, item, want = case[:4]
                extra_env = case[4] if len(case) > 4 else {}
                ok, got = render(tmp, template, key, vault, item, extra_env)
                if want is None:
                    passed = not ok
                    detail = "rendered %r, want a template error" % got
                else:
                    passed = ok and got.strip() == want.strip()
                    detail = got if not ok else "got %r, want %r" % (got, want)
                if passed:
                    print("  PASS  " + desc)
                else:
                    failures += 1
                    print("  FAIL  %s -> %s" % (desc, detail))
    print("\n%d failure(s)" % failures)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
