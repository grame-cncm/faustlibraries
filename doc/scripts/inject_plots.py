#!/usr/bin/env python3
"""Insert generated plots into one generated library page.

Injection is by convention rather than by annotation: a heading for
``(aa.)hardclip`` picks up ``img/aa_hardclip.svg`` if that file exists, and is
left untouched otherwise. Nothing has to be written in the 1000+ documentation
blocks of the libraries, and a function gains its figure the moment the plot is
generated.

Kept out of `faustlib2md.awk` on purpose: the awk script owns the comment-to-
markdown translation and has no business testing the filesystem.

    inject_plots.py <page.md> <img-dir> <img-url-prefix>
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# A heading may document several functions (`### `(an.)window_rect`,
# `(an.)window_hann`, ...`): every name found on the line is tried, so a
# family block collects the figure of each member that has one.
HEADING = re.compile(r"^### +`\(")
NAME = re.compile(r"`\((?P<prefix>[a-zA-Z0-9]+)\.\)(?P<name>[A-Za-z0-9_]+)`")


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    page, img_dir, url_prefix = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    if not page.exists():
        return 0

    out, injected = [], 0
    for line in page.read_text(errors="replace").splitlines():
        out.append(line)
        if not HEADING.match(line):
            continue
        for m in NAME.finditer(line):
            stem = f"{m.group('prefix')}_{m.group('name')}"
            if (img_dir / f"{stem}.svg").exists():
                out.append("")
                out.append(f"![{m.group('name')} — response plots]"
                           f"({url_prefix}/{stem}.svg)")
                injected += 1

    if injected:
        page.write_text("\n".join(out) + "\n")
        print(f"  {page.name}: {injected} plot(s) injected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
