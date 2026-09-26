#!/usr/bin/env python3
"""Mechanical checks for the repo-wide invariants documented in AGENTS.md.

These are static, source-only checks (no chezmoi execution) for conventions
that a template render or a shell lint would never catch: a `run_onchange_`
script whose hash comment silently goes stale, a hook that can abort
`chezmoi apply`, a `modify_` script with the wrong extension/marker, or a
secret-fed file that isn't `private_`. Each check either PASSes, FAILs, or
lists itself as an allowlisted pre-existing violation (printed but not
counted as a failure) so a batch of unrelated work doesn't have to fix
something it didn't touch.

Usage: .github/scripts/test-repo-rules.py   (stdlib only, no chezmoi needed)
"""

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HOME = os.path.join(ROOT, "home")
SCRIPTS_DIR = os.path.join(HOME, ".chezmoiscripts")
TEMPLATES_DIR = os.path.join(HOME, ".chezmoitemplates")

# ── shared helpers ───────────────────────────────────────────────────────────

ATTR_PREFIXES = (
    "create_", "dot_", "empty_", "encrypted_", "exact_", "executable_",
    "external_", "literal_", "modify_", "private_", "readonly_", "remove_",
    "symlink_",
)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def rel(path):
    return os.path.relpath(path, ROOT)


def walk_home():
    for dirpath, dirnames, filenames in os.walk(HOME):
        dirnames.sort()
        for name in sorted(filenames):
            yield os.path.join(dirpath, name)


def component_is_private(component):
    """Does one source path component (dir or file, attributes concatenated
    with no separator, e.g. "private_dot_claude") carry the private_ flag?

    chezmoi strips recognised attribute prefixes left-to-right until it hits
    the literal name; this mirrors that walk well enough to answer "was
    private_ one of the attributes" without reimplementing chezmoi's parser.
    """
    remaining = component
    saw_private = False
    changed = True
    while changed:
        changed = False
        for prefix in ATTR_PREFIXES:
            if remaining.startswith(prefix):
                if prefix == "private_":
                    saw_private = True
                remaining = remaining[len(prefix):]
                changed = True
                break
    return saw_private


def path_chain_has_private(path):
    """Any component from home/ down to and including the file itself?"""
    relpath = os.path.relpath(path, HOME)
    return any(component_is_private(part) for part in relpath.split(os.sep))


# ── check 1: run_onchange_ scripts must re-run when their inputs change ─────
#
# chezmoi only re-runs a run_onchange_ script when its RENDERED TEXT changes,
# so a template that reads another file's content at apply time has to prove
# that in its own output: either hash the input with `include`/`includeTemplate`
# piped to `sha256sum`, or interpolate the triggering data value directly (its
# own text then changes whenever that value does — see
# run_onchange_after_windows_explorer-tweaks.ps1.tmpl, which has no external
# file to hash and instead prints `.windows.explorer.apply_tweaks` itself).

TMPL_TAG_RE = re.compile(r"\{\{-?\s*(.*?)\s*-?\}\}", re.DOTALL)
CONTROL_KEYWORDS = ("if ", "else", "end", "range ", "with ", "define ", "block ", "template ")


def has_change_trigger(text):
    if "sha256sum" in text:
        return True
    for match in TMPL_TAG_RE.finditer(text):
        expr = match.group(1).strip()
        if not expr or expr.startswith(("-", "/*")):
            continue
        if expr.startswith(CONTROL_KEYWORDS):
            continue
        if expr.startswith("."):
            return True
    return False


def check_run_onchange_hash():
    problems = []
    for name in sorted(os.listdir(SCRIPTS_DIR)):
        if not name.startswith("run_onchange_"):
            continue
        path = os.path.join(SCRIPTS_DIR, name)
        if not has_change_trigger(read(path)):
            problems.append(rel(path))
    return problems


# ── check 2: every hook is guarded so it can never abort `chezmoi apply` ────
#
# A `before` script that exits non-zero stops the whole apply before any
# dotfile is written; an `after` script that hangs or fails leaves the user
# thinking something broke. Both CI and an explicit opt-out must short-circuit
# before any real work (network, sudo, package installs) runs.

# Pre-existing on origin/main, not touched by this change: allowlisted rather
# than "fixed" here, since none of them do anything that can hang or abort
# (rm -f, an -ErrorAction-guarded cache rebuild, an -ErrorAction-guarded pkg
# install) — see the comment on each entry.
GUARD_ALLOWLIST = {
    # rm -f on a legacy path; cannot fail in a way that aborts the apply.
    "home/.chezmoiscripts/run_once_before_clean-legacy-zsh-functions.sh.tmpl":
        "TODO(batch/14): rm -f only, harmless without a guard — add one anyway for consistency.",
    # `bat cache --build` behind Get-Command; no network, no sudo.
    "home/.chezmoiscripts/run_onchange_after_windows_bat_cache.ps1.tmpl":
        "TODO(batch/14): no network/sudo, but add the guard for consistency with every other hook.",
    # `ya pkg install` behind Get-Command, output discarded; not gated on CI today.
    "home/.chezmoiscripts/run_onchange_after_windows_yazi-plugins.ps1.tmpl":
        "TODO(batch/14): add the guard — `ya pkg install` does touch the network.",
}


def check_hook_guards():
    # Substring/word-presence only — this does not verify the guard actually
    # short-circuits before real work runs (that needs parsing control flow,
    # out of scope for a mechanical repo-rules check). A hook that merely
    # mentions both words in a comment without an early `exit 0` would pass
    # this check while still being unguarded; nothing in this repo does that
    # today, but a human reviewer, not this script, is the backstop against it.
    problems, allowlisted = [], []
    for name in sorted(os.listdir(SCRIPTS_DIR)):
        path = os.path.join(SCRIPTS_DIR, name)
        text = read(path)
        has_ci = re.search(r"\bCI\b", text) is not None
        has_bootstrap = "NREDF_NO_BOOTSTRAP" in text
        if has_ci and has_bootstrap:
            continue
        entry = rel(path)
        if entry in GUARD_ALLOWLIST:
            allowlisted.append((entry, GUARD_ALLOWLIST[entry]))
        else:
            problems.append(entry)
    return problems, allowlisted


# ── check 3: modify_ scripts ─────────────────────────────────────────────────
#
# A modify_ source with a .tmpl extension never sees `.chezmoi.stdin` (chezmoi
# renders it as a template instead of running it as a modify script), so the
# merge logic silently gets the *previous* file's content instead of stdin.

MODIFY_MARKER = "{{- /* chezmoi:modify-template */ -}}"


def check_modify_scripts():
    problems = []
    for path in walk_home():
        name = os.path.basename(path)
        # Catches modify_ preceded by other attributes too (e.g. private_modify_foo).
        if "modify_" not in name:
            continue
        if name.endswith(".tmpl"):
            problems.append((rel(path), "modify_ source must not have a .tmpl extension"))
            continue
        text = read(path)
        if not text.lstrip().startswith(MODIFY_MARKER):
            problems.append((rel(path), "must start with the chezmoi:modify-template marker"))
    return problems


# ── check 4: secret-fed files must be private_ ───────────────────────────────
#
# Anything whose template pulls a value out of get-*.tmpl or renders through
# render-mcp-config is a candidate to leak secret material to other local
# users unless the file (or an ancestor directory) is private_ (mode 0600 /
# 0700). Scripts under .chezmoiscripts/ aren't checked here: they aren't
# deployed into the destination tree as a persistent dotfile the way a normal
# source path is, so the private_ attribute doesn't apply to them the same
# way — any secret they touch is written out through a *different*,
# already-checked target path.

SECRET_TEMPLATE_RE = re.compile(r'includeTemplate\s+"(get-[\w.-]+\.tmpl|render-mcp-config\.tmpl)"')

# Pre-existing on origin/main: get-signing-key.tmpl only ever extracts the
# *public* half of the signing key (an ssh-ed25519/ecdsa public key, or a GPG
# key id) — verified by reading .chezmoitemplates/get-signing-key.tmpl, which
# has no code path that returns a private key or passphrase. git/config.tmpl
# is legitimately public (mode 0644); flagging it would be a false positive.
PRIVATE_TEMPLATE_ALLOWLIST = {
    "home/dot_config/git/config.tmpl":
        "TODO(batch/14 note, not a fix): uses get-signing-key.tmpl but only ever "
        "receives the public key — see .chezmoitemplates/get-signing-key.tmpl.",
}


def check_private_secret_files():
    problems, allowlisted = [], []
    for path in walk_home():
        if path.startswith(SCRIPTS_DIR + os.sep) or path.startswith(TEMPLATES_DIR + os.sep):
            continue
        if not path.endswith(".tmpl"):
            continue
        text = read(path)
        if not SECRET_TEMPLATE_RE.search(text):
            continue
        if path_chain_has_private(path):
            continue
        entry = rel(path)
        if entry in PRIVATE_TEMPLATE_ALLOWLIST:
            allowlisted.append((entry, PRIVATE_TEMPLATE_ALLOWLIST[entry]))
        else:
            problems.append(entry)
    return problems, allowlisted


# ── runner ───────────────────────────────────────────────────────────────────

def main():
    failures = 0

    print("run_onchange_ scripts re-run on their own input changes")
    bad = check_run_onchange_hash()
    if bad:
        failures += len(bad)
        for entry in bad:
            print("  FAIL  %s -- no sha256sum hash and no embedded data value" % entry)
    else:
        print("  PASS  every run_onchange_ script hashes or embeds its trigger")

    print("hooks are guarded with CI and NREDF_NO_BOOTSTRAP")
    bad, allowlisted = check_hook_guards()
    if bad:
        failures += len(bad)
        for entry in bad:
            print("  FAIL  %s -- missing CI and/or NREDF_NO_BOOTSTRAP guard" % entry)
    else:
        print("  PASS  every non-allowlisted hook is guarded")
    for entry, note in allowlisted:
        print("  WARN  %s (allowlisted) -- %s" % (entry, note))

    print("modify_ scripts are plain files with the modify-template marker")
    bad = check_modify_scripts()
    if bad:
        failures += len(bad)
        for entry, why in bad:
            print("  FAIL  %s -- %s" % (entry, why))
    else:
        print("  PASS  every modify_ script is correctly shaped")

    print("secret-fed files are private_")
    bad, allowlisted = check_private_secret_files()
    if bad:
        failures += len(bad)
        for entry in bad:
            print("  FAIL  %s -- uses a secret template but nothing in its path is private_" % entry)
    else:
        print("  PASS  every non-allowlisted secret-fed file is private_")
    for entry, note in allowlisted:
        print("  WARN  %s (allowlisted) -- %s" % (entry, note))

    print("\n%d failure(s)" % failures)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
