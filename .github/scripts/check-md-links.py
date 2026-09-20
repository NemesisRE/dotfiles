#!/usr/bin/env python3
"""Fail if a Markdown file links to a repo file that does not exist.

Catches the two kinds of rot this repo has had: absolute `file:///Users/<name>/...`
links (dead for every reader but the author) and relative links to paths that were
renamed or never existed. Only local links are checked: http(s)/mailto/anchor-only
links are skipped, and `#fragment` / `?query` parts are stripped (fragments are not
validated -- heading slugs with emoji are too fiddly to reproduce reliably).

Usage: .github/scripts/check-md-links.py [file.md ...]   (default: every tracked *.md)
"""

import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)|!\[[^\]]*\]\(\s*<?([^)\s>]+)>?")
FENCE = re.compile(r"^\s*(```|~~~)")


def targets(text):
    """Yield (line_number, link) for each link outside fenced code blocks."""
    in_fence = False
    for n, line in enumerate(text.splitlines(), 1):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        line = re.sub(r"`[^`]*`", lambda m: " " * len(m.group(0)), line)  # ignore inline code
        for m in LINK.finditer(line):
            yield n, m.group(1) or m.group(2)


def main():
    files = sys.argv[1:] or subprocess.run(
        ["git", "-C", ROOT, "ls-files", "*.md"], capture_output=True, text=True, check=True).stdout.split()
    bad = 0
    for rel in files:
        path = rel if os.path.isabs(rel) else os.path.join(ROOT, rel)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        for n, link in targets(text):
            if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", link) and not link.startswith("file:"):
                continue  # http(s), mailto, ...
            if link.startswith("#"):
                continue
            if link.startswith("file:"):
                bad += 1
                print("%s:%d: absolute file:// link (dead for everyone else): %s" % (rel, n, link))
                continue
            target = re.split(r"[#?]", link, maxsplit=1)[0]
            # A leading "/" is repo-root relative (as GitHub renders it).
            resolved = os.path.join(ROOT, target.lstrip("/")) if target.startswith("/") else os.path.join(os.path.dirname(path), target)
            if not os.path.exists(os.path.normpath(resolved)):
                bad += 1
                print("%s:%d: broken link: %s" % (rel, n, link))
    print("\n%d broken link(s) in %d file(s)" % (bad, len(files)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
