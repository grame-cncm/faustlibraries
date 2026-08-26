#!/usr/bin/env python3
"""Normalize `declare ... license` strings to SPDX identifiers.

The libraries historically used 16+ spellings for ~8 actual licenses
("MIT License", "MIT license", "MIT", ...). Tools that classify symbols by
license (scripts/build_faust_doc_index.py --license-policy) match strings, so
every variant spelling is a potential misclassification. This script rewrites
the license strings in `declare [symbol] license|licence "..."` lines to one
canonical SPDX identifier per license, and can verify the invariant.

Licenses without an SPDX-listed identifier use a LicenseRef- name:
  * LicenseRef-STK-4.3: the MIT-style Synthesis ToolKit license.
  * LicenseRef-LGPL-2.1-or-later-with-Faust-exception: the GRAME license
    (LGPL 2.1 or later, with the Faust output-relicensing exception spelled
    out in the file headers).

Version-ambiguous inputs are mapped conservatively: a bare "GPLv3" or
"LGPLv2.1" becomes the -only form (claiming or-later would grant rights the
author never stated); the bare "LGPL" of the two GRAME demos follows the
GRAME file header (2.1 or later).

Usage:
    scripts/normalize_licenses.py           # rewrite the .lib files in place
    scripts/normalize_licenses.py --check   # exit 1 on any non-canonical string
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

CANONICAL = {
    "MIT": "MIT",
    "MIT License": "MIT",
    "MIT license": "MIT",
    "STK-4.3": "LicenseRef-STK-4.3",
    "MIT-style STK-4.3 license": "LicenseRef-STK-4.3",
    "GPLv3": "GPL-3.0-only",
    "GPL-3.0": "GPL-3.0-only",
    "GPLv3 license": "GPL-3.0-only",
    "GPL2+": "GPL-2.0-or-later",
    "AGPL-3.0": "AGPL-3.0-only",
    "LGPLv2.1": "LGPL-2.1-only",
    "LGPL v3.0 license": "LGPL-3.0-only",
    "LGPL": "LGPL-2.1-or-later",
    "LGPL with exception": "LicenseRef-LGPL-2.1-or-later-with-Faust-exception",
    "ISC license": "ISC",
    "BSD 3-Clause License": "BSD-3-Clause",
}

ALLOWED = set(CANONICAL.values()) | {
    "AGPL-3.0-only",
    "GPL-3.0-or-later",
    "LGPL-2.1-or-later",
    "LGPL-2.1-only",
    "LGPL-3.0-only",
    "LGPL-3.0-or-later",
    "BSD-2-Clause",
    "Apache-2.0",
    "ISC",
    "CC0-1.0",
}

decl_re = re.compile(
    r'^(declare(?:\s+[A-Za-z_][A-Za-z0-9_\[\]]*)?\s+licen[sc]e\s+")([^"]*)(".*)$'
)


def tracked_libs():
    out = subprocess.check_output(["git", "ls-files", "*.lib"]).decode().split()
    return [f for f in out if "/" not in f]


def main():
    check = "--check" in sys.argv
    bad = []
    changed = 0
    for lib in tracked_libs():
        with open(lib, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        dirty = False
        for i, line in enumerate(lines):
            m = decl_re.match(line)
            if not m:
                continue
            value = m.group(2).strip()
            if value in ALLOWED:
                continue
            if value in CANONICAL:
                if check:
                    bad.append((lib, i + 1, value, CANONICAL[value]))
                else:
                    lines[i] = m.group(1) + CANONICAL[value] + m.group(3) + "\n"
                    lines[i] = lines[i].rstrip("\n") + "\n"
                    dirty = True
                    changed += 1
            else:
                bad.append((lib, i + 1, value, None))
        if dirty:
            with open(lib, "w", encoding="utf-8") as f:
                f.writelines(lines)
    for lib, no, value, repl in bad:
        if repl:
            print("%s:%d: non-canonical license %r (should be %r)" % (lib, no, value, repl))
        else:
            print("%s:%d: unknown license string %r" % (lib, no, value))
    if not check:
        print("Rewrote %d license declaration(s)." % changed)
    if bad:
        sys.exit(1)
    if check:
        print("All license declarations are canonical.")


if __name__ == "__main__":
    main()
