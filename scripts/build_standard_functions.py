#!/usr/bin/env python3
"""Generate doc/docs/standardFunctions.md from the source markers.

The set of functions comes from the `` `name` is a standard Faust function ``
(or ``are standard Faust functions``) marker lines in the git-tracked .lib
files at the repository root: the sources are the single source of truth.
The curated presentation (section, human-readable label, description) is
read from the existing standardFunctions.md when the function is already
listed there; a function marked standard but absent from the index gets an
auto-generated row (label = function name, description = first line of its
documentation block).

Usage:
    scripts/build_standard_functions.py [--check]

Without options, rewrites doc/docs/standardFunctions.md in place.
With --check, writes nothing and exits 1 if the file is out of date.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
MD = "doc/docs/standardFunctions.md"

SECTIONS = [
    "Analysis Tools",
    "Basic Elements",
    "Conversion",
    "Effects",
    "Envelope Generators",
    "Filters",
    "Oscillators/Sound Generators",
    "Synths",
]

# Section for functions not already curated in the index, by library prefix.
DEFAULT_SECTION = {
    "an": "Analysis Tools",
    "ba": "Basic Elements",
    "si": "Basic Elements",
    "ro": "Basic Elements",
    "de": "Basic Elements",
    "co": "Effects",
    "ef": "Effects",
    "pf": "Effects",
    "re": "Effects",
    "sp": "Effects",
    "ho": "Effects",
    "en": "Envelope Generators",
    "fi": "Filters",
    "os": "Oscillators/Sound Generators",
    "no": "Oscillators/Sound Generators",
    "so": "Oscillators/Sound Generators",
    "sy": "Synths",
}

header_re = re.compile(r"^//-{2,}.*?`\(([a-z]+)\.\)")
name_in_header_re = re.compile(r"`\(?[a-z]*\.?\)?([A-Za-z0-9_\[\]|]+)`")
marker_re = re.compile(
    r"`(?:[a-z]{2}\.)?([A-Za-z0-9_\[\]|]+)`(?:,\s*`(?:[a-z]{2}\.)?([A-Za-z0-9_\[\]|]+)`)*"
    r"[^`]*\b(?:is a|are) standard Faust function"
)
backtick_re = re.compile(r"`(?:[a-z]{2}\.)?([A-Za-z0-9_\[\]|]+)`")


def tracked_libs():
    out = subprocess.check_output(["git", "ls-files", "*.lib"]).decode().split()
    return [f for f in out if "/" not in f]


def anchor(prefix, name):
    return prefix + re.sub(r"[^a-z0-9_]", "", name.lower())


def scan_sources():
    """Return {(prefix, name): (libfile, first_doc_line)} for marked functions."""
    found = {}
    for lib in tracked_libs():
        with open(lib, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        block_prefix = None
        block_first = ""
        in_block = False
        for line in lines:
            m = header_re.match(line)
            if m:
                block_prefix = m.group(1)
                block_first = ""
                in_block = True
                continue
            if in_block and line.startswith("//"):
                body = line[2:].strip()
                if (not block_first and body and not body.startswith("#")
                        and not body.startswith("-") and "standard Faust function" not in body):
                    block_first = body.rstrip()
                if "standard Faust function" in body and block_prefix:
                    mm = marker_re.search(body)
                    if mm:
                        head = body[: body.find("is a standard")
                                    if "is a standard" in body
                                    else body.find("are standard")]
                        for name in backtick_re.findall(head):
                            found[(block_prefix, name)] = (lib, block_first)
            elif in_block and not line.startswith("//"):
                in_block = False
    return found


row_re = re.compile(
    r"^\[(?P<label>[^\]]+)\]\([^)]*\) \| "
    r"\[`(?P<prefix>[a-z]+)\.`\]\([^)]*\)\[`(?P<name>[^`]+)`\]\([^)]*\) \| "
    r"(?P<desc>.*)$"
)


def read_curated(path):
    """Return preamble text and {(prefix, name): (section, label, desc)}."""
    curated = {}
    preamble = []
    section = None
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("## "):
                section = line[3:].strip()
            elif section is None:
                preamble.append(line)
            else:
                m = row_re.match(line.strip())
                if m:
                    curated[(m.group("prefix"), m.group("name"))] = (
                        section, m.group("label"), m.group("desc").strip())
    return "".join(preamble).rstrip("\n") + "\n", curated


def build(found, preamble, curated):
    per_section = {s: [] for s in SECTIONS}
    for (prefix, name), (lib, first_line) in sorted(found.items()):
        libbase = os.path.splitext(lib)[0]
        page = "libs/%s.md" % libbase
        link = "#%s" % anchor(prefix, name)
        if (prefix, name) in curated:
            section, label, desc = curated[(prefix, name)]
            if section not in per_section:
                section = DEFAULT_SECTION.get(prefix, "Basic Elements")
        else:
            section = DEFAULT_SECTION.get(prefix, "Basic Elements")
            label = name
            desc = first_line.rstrip(".") if first_line else name
        row = ("[%s](%s%s) | [`%s.`](%s)[`%s`](%s%s) | %s"
               % (label, page, link, prefix, page, name, page, link, desc))
        per_section[section].append((label.lower(), row))
    out = [preamble]
    for section in SECTIONS:
        rows = per_section[section]
        if not rows:
            continue
        out.append("\n\n## %s\n" % section)
        out.append("\n<div class=\"table-begin\"></div>\n")
        out.append("\nFunction Type | Function Name | Description\n--- | --- | ---\n")
        for _, row in sorted(rows):
            out.append(row + "\n")
        out.append("\n<div class=\"table-end\"></div>\n")
    return "".join(out) + "\n"


def main():
    check = "--check" in sys.argv
    found = scan_sources()
    preamble, curated = read_curated(MD)
    text = build(found, preamble, curated)
    if check:
        current = open(MD, encoding="utf-8").read()
        if current != text:
            sys.stderr.write("%s is out of date; run scripts/build_standard_functions.py\n" % MD)
            sys.exit(1)
        print("%s is up to date (%d standard functions)." % (MD, len(found)))
        return
    with open(MD, "w", encoding="utf-8") as f:
        f.write(text)
    print("Wrote %s (%d standard functions)." % (MD, len(found)))


if __name__ == "__main__":
    main()
