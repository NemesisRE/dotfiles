#!/usr/bin/env python3
"""Verify (or refresh) the SHA-256 pins for downloaded-and-executed artifacts.

Several installers download a release archive and run it. Each is pinned to a
version *and* a SHA-256, so a tampered or replaced upstream asset is rejected on
the user's machine. A pin is only worth having if it cannot silently rot, which is
what this script enforces in CI: it re-downloads every pinned artifact, hashes the
real bytes and compares. A Renovate bump of `version` therefore fails CI until the
hashes are refreshed with `pins.py update`.

  pins.py verify   re-download everything and compare (exit 1 on any mismatch)
  pins.py update   recompute the hashes and rewrite the pin files in place

Pins covered:
  home/.chezmoidata/kitty.yaml            Linux kitty archives (x86_64, arm64)
  home/.chezmoidata/aqua-bootstrap.yaml   Windows aqua zips (amd64, arm64)
  bootstrap.ps1                           same aqua literals (cannot read chezmoi data)
  home/.chezmoiscripts/run_once_before_install-tools.sh.tmpl   aqua-installer script

No third-party dependencies (the YAML involved is deliberately trivial).
"""

import argparse
import hashlib
import os
import re
import sys
import time
import urllib.request

DEFAULT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

KITTY = "home/.chezmoidata/kitty.yaml"
AQUA = "home/.chezmoidata/aqua-bootstrap.yaml"
BOOTSTRAP = "bootstrap.ps1"
INSTALLER = "home/.chezmoiscripts/run_once_before_install-tools.sh.tmpl"

HEX = r"[0-9a-f]{64}"


def read(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8") as f:
        return f.read()


def write(root, rel, text):
    with open(os.path.join(root, rel), "w", encoding="utf-8") as f:
        f.write(text)


def find(pattern, text, what):
    m = re.search(pattern, text, re.M)
    if not m:
        sys.exit("pins.py: could not find %s" % what)
    return m.group(1)


def sha256_url(url, tries=3):
    """Stream `url` and return its SHA-256 (no temp files, ~30 MB at most)."""
    for attempt in range(1, tries + 1):
        try:
            h = hashlib.sha256()
            req = urllib.request.Request(url, headers={"User-Agent": "dotfiles-pins-check"})
            with urllib.request.urlopen(req, timeout=120) as r:
                for chunk in iter(lambda: r.read(1 << 20), b""):
                    h.update(chunk)
            return h.hexdigest()
        except Exception as e:  # network flake or 404; retry then report
            if attempt == tries:
                raise SystemExit("pins.py: cannot download %s: %s" % (url, e))
            time.sleep(2 * attempt)


def sync_bootstrap_version(root):
    """Make bootstrap.ps1's $aquaVersion follow the data file.

    Renovate bumps only home/.chezmoidata/aqua-bootstrap.yaml. bootstrap.ps1 is
    fetched raw before chezmoi exists so it carries its own copy of the version,
    which `update` must carry along or the two disagree and `verify` fails.
    """
    version = find(r'^\s*version:\s*"?(v[^"\s#]+)', read(root, AQUA), "aqua-bootstrap version")
    boot = read(root, BOOTSTRAP)
    new, n = re.subn(r'(\$aquaVersion\s*=\s*")v[^"]+(")', lambda m: m.group(1) + version + m.group(2), boot, count=1)
    if n != 1:
        sys.exit("pins.py: could not find $aquaVersion in %s" % BOOTSTRAP)
    if new != boot:
        write(root, BOOTSTRAP, new)
        print("  synced   bootstrap.ps1 $aquaVersion -> %s" % version)


def pins(root):
    """Return [(label, url, pinned_sha, rewrite)] for every pinned artifact."""
    out = []

    kitty = read(root, KITTY)
    kv = find(r'^\s*version:\s*"?(v[^"\s#]+)', kitty, "kitty version")
    for arch in ("x86_64", "arm64"):
        pinned = find(r'^\s*%s:\s*"(%s)"' % (arch, HEX), kitty, "kitty sha256 " + arch)
        url = "https://github.com/kovidgoyal/kitty/releases/download/%s/kitty-%s-%s.txz" % (kv, kv[1:], arch)
        out.append(("kitty %s %s" % (kv, arch), url, pinned, (KITTY, r'(^\s*%s:\s*")%s(")' % (arch, HEX))))

    aqua = read(root, AQUA)
    av = find(r'^\s*version:\s*"?(v[^"\s#]+)', aqua, "aqua-bootstrap version")
    boot = read(root, BOOTSTRAP)
    bv = find(r'\$aquaVersion\s*=\s*"(v[^"]+)"', boot, "bootstrap.ps1 $aquaVersion")
    if bv != av:
        sys.exit("pins.py: bootstrap.ps1 pins aqua %s but %s pins %s" % (bv, AQUA, av))
    for arch in ("amd64", "arm64"):
        pinned = find(r'^\s*%s:\s*"(%s)"' % (arch, HEX), aqua, "aqua sha256 " + arch)
        url = "https://github.com/aquaproj/aqua/releases/download/%s/aqua_windows_%s.zip" % (av, arch)
        out.append(("aqua %s windows/%s" % (av, arch), url, pinned, (AQUA, r'(^\s*%s:\s*")%s(")' % (arch, HEX))))
        # bootstrap.ps1 must carry the same literal.
        b_pinned = find(r'^\s*%s\s*=\s*"(%s)"' % (arch, HEX), boot, "bootstrap.ps1 " + arch)
        out.append(("bootstrap.ps1 aqua %s windows/%s" % (av, arch), url, b_pinned,
                    (BOOTSTRAP, r'(^\s*%s\s*=\s*")%s(")' % (arch, HEX))))

    inst = read(root, INSTALLER)
    iv = find(r'AQUA_INSTALLER_VERSION="(v[^"]+)"', inst, "AQUA_INSTALLER_VERSION")
    isha = find(r'AQUA_INSTALLER_SHA256="(%s)"' % HEX, inst, "AQUA_INSTALLER_SHA256")
    url = "https://raw.githubusercontent.com/aquaproj/aqua-installer/%s/aqua-installer" % iv
    out.append(("aqua-installer %s" % iv, url, isha, (INSTALLER, r'(AQUA_INSTALLER_SHA256=")%s(")' % HEX)))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", nargs="?", default="verify", choices=("verify", "update"))
    ap.add_argument("--root", default=DEFAULT_ROOT, help="repository root (default: this repo)")
    args = ap.parse_args()

    if args.mode == "update":
        sync_bootstrap_version(args.root)

    cache = {}  # the same URL appears twice (data file + bootstrap.ps1): download once
    bad = 0
    edits = []
    for label, url, pinned, rewrite in pins(args.root):
        if url not in cache:
            cache[url] = sha256_url(url)
        actual = cache[url]
        if actual == pinned:
            print("  ok       %s" % label)
            continue
        if args.mode == "update":
            print("  updated  %s\n           %s -> %s" % (label, pinned, actual))
            edits.append((rewrite, actual))
        else:
            bad += 1
            print("  MISMATCH %s\n           pinned %s\n           actual %s\n           %s" % (label, pinned, actual, url))

    for (rel, pattern), actual in edits:
        text = read(args.root, rel)
        new, n = re.subn(pattern, lambda m: m.group(1) + actual + m.group(2), text, count=1, flags=re.M)
        if n != 1:
            sys.exit("pins.py: could not rewrite a pin in %s" % rel)
        write(args.root, rel, new)

    if bad:
        print("\n%d pin(s) do not match. If you bumped a version, run: .github/scripts/pins.py update" % bad)
        return 1
    print("\nall pins %s" % ("refreshed" if edits else "verified"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
