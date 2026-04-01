#!/usr/bin/env python3
"""Build a JSON documentation index from a local Faust libraries checkout.

This script extracts documentation directly from Faust `.lib` source files rather
than from the generated Markdown site.

The extraction model intentionally mirrors how the documentation is authored in
the Faust libraries repository:

1. Start from `stdfaust.lib` or another explicitly supplied root file.
2. Recursively follow `library("...")` and `import("...")` directives.
3. Detect documented symbols from comment headers such as:
   `//-------`(aa.)Rsqrt`----------`
4. Parse the comment block that follows into:
   - a free-text summary
   - an optional `#### Usage` section
   - an optional `Where:` parameter list
   - an optional `#### Test` code block
   - optional references
5. Emit a machine-readable JSON index that can be searched externally by an
   LLM toolchain without loading the whole standard library into model context.

The script supports two output layouts:

- Monolithic: one full JSON document containing every library and symbol.
- Split: one compact global index plus one detailed JSON file per library
  module. The split layout is more suitable for retrieval-based use with LLMs.

This is not a full Faust parser. It is a documentation extractor with a small
amount of syntax-aware inference, notably for:

- resolving imported library files in the repository tree
- inferring a fallback `usage` string when the docs omit `#### Usage`
- deriving rough `inSignals` / `outSignals` counts from the `usage` string
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict, deque
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Iterable


LIBRARY_DIRECTIVE_RE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*library\("([^"]+)"\)\s*;')
IMPORT_DIRECTIVE_RE = re.compile(r'import\("([^"]+)"\)\s*;')
HEADER_RE = re.compile(r"^//-+\s*`([^`]+)`\s*-+")
PARAM_RE = re.compile(r"^\*\s*`([^`]+)`\s*:\s*(.+)$")
SEPARATOR_RE = re.compile(r"^[-=#*]{3,}$")
DEFINITION_NAME_RE = re.compile(r"^(?:declare\s+)?([A-Za-z_][A-Za-z0-9_\[\]]*)\s*(?:\(|=)")
DECLARE_LICENSE_RE = re.compile(
    r'^declare\s+([A-Za-z_][A-Za-z0-9_\[\]]*)\s+(license|licence)\s+"([^"]*)"\s*;'
)
COMMERCIAL_COMPATIBLE_TOKENS = (
    "mit",
    "bsd",
    "apache",
    "lgpl with exception",
    "lgpl",
    "mpl",
    "unlicense",
    "isc",
    "zlib",
    "boost",
    "public domain",
    "stk-4.3",
)
COMMERCIAL_INCOMPATIBLE_TOKENS = (
    "agpl",
    "gpl",
    "non-commercial",
    "non commercial",
    "cc-by-nc",
    "creativecommons.org/licenses/by-nc",
)


@dataclass(frozen=True)
class LibraryReference:
    """A single dependency edge extracted from Faust source.

    Attributes:
        alias:
            The alias introduced by `xx = library("foo.lib");`.
            Imports declared with `import("foo.lib");` do not introduce an
            alias, so this field is `None` for those references.
        target:
            The raw path string written in the Faust source.
    """

    alias: str | None
    target: str


def normalize_posix_path(path: str | Path) -> str:
    """Return a stable POSIX-style path string.

    The generated JSON is easier to consume across platforms when paths use `/`
    consistently, even if the script is executed on a system using backslashes.
    """

    return str(path).replace("\\", "/")


def repo_relative(path: Path, repo_root: Path) -> str:
    """Return `path` relative to `repo_root` with normalized separators."""

    return normalize_posix_path(path.resolve().relative_to(repo_root.resolve()))


def discover_lib_files(repo_root: Path) -> tuple[dict[str, Path], dict[str, list[Path]]]:
    """Index every `.lib` file visible under the repository root.

    Two lookup tables are produced:

    - `by_relpath`: exact repository-relative path -> file path
    - `by_name`: basename such as `filters.lib` -> candidate file paths

    The second mapping is important for cases where Faust source refers to a
    library by basename only while the real file lives in a subdirectory.
    """

    by_relpath: dict[str, Path] = {}
    by_name: dict[str, list[Path]] = defaultdict(list)
    for lib_path in sorted(repo_root.rglob("*.lib")):
        if not lib_path.is_file():
            continue
        relpath = repo_relative(lib_path, repo_root)
        by_relpath[relpath] = lib_path.resolve()
        by_name[lib_path.name].append(lib_path.resolve())
    return by_relpath, by_name


def parse_library_references(source: str) -> list[LibraryReference]:
    """Extract `library(...)` and `import(...)` directives from Faust source.

    This parser is intentionally simple and regex-based because the target
    constructs are regular in the Faust library sources. The result preserves
    enough information to:

    - continue the recursive traversal
    - remember alias hints such as `aa = library("aanl.lib");`
    """

    refs: list[LibraryReference] = []
    for match in LIBRARY_DIRECTIVE_RE.finditer(source):
        refs.append(LibraryReference(alias=match.group(1), target=match.group(2)))
    for match in IMPORT_DIRECTIVE_RE.finditer(source):
        refs.append(LibraryReference(alias=None, target=match.group(1)))
    return refs


def resolve_reference(
    current_file: Path,
    target: str,
    repo_root: Path,
    by_relpath: dict[str, Path],
    by_name: dict[str, list[Path]],
) -> Path | None:
    """Resolve a referenced library file inside the repository checkout.

    Resolution order is pragmatic rather than language-lawyer precise:

    1. path relative to the current file
    2. path relative to repository root
    3. exact repository-relative match
    4. basename lookup anywhere in the repository

    This order is designed to work well with the structure of the Faust
    libraries tree, including nested modules like `dx7/env.lib`.
    """

    candidates: list[Path] = []

    target_path = Path(target)
    if target_path.is_absolute():
        candidates.append(target_path)
    else:
        candidates.append((current_file.parent / target_path).resolve())
        candidates.append((repo_root / target_path).resolve())

        rel_target = normalize_posix_path(target)
        if rel_target in by_relpath:
            candidates.append(by_relpath[rel_target])

        basename = Path(target).name
        for lib_path in by_name.get(basename, []):
            candidates.append(lib_path)

    seen: set[Path] = set()
    for candidate in candidates:
        resolved = candidate.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        if resolved.is_file():
            return resolved
    return None


def parse_symbol_header(line: str) -> dict[str, str | None] | None:
    """Parse a documented symbol header line.

    Expected input looks like:

    - `//-------`(aa.)Rsqrt`----------`
    - `//---------------------------------`(ma.)T`---------------------------------------`

    The returned mapping contains:

    - `header`: raw logical header content, e.g. `(aa.)Rsqrt`
    - `alias`: extracted alias without trailing dot, e.g. `aa`
    - `name`: symbol name, e.g. `Rsqrt`
    """

    match = HEADER_RE.match(line)
    if not match:
        return None
    header = match.group(1).strip()
    alias_match = re.match(r"^\(([^)]+)\)\s*(.+)$", header)
    if alias_match:
        alias = alias_match.group(1).rstrip(".").strip()
        name = alias_match.group(2).strip()
        return {"header": header, "alias": alias or None, "name": name}
    return {"header": header, "alias": None, "name": header.strip()}


def warn(message: str) -> None:
    """Emit a non-fatal warning during index generation."""

    print(f"WARNING: {message}", file=sys.stderr)


def is_suspicious_symbol_name(name: str) -> bool:
    """Return whether a parsed symbol name looks malformed."""

    if not name:
        return True
    if name.startswith(".") or name.endswith("."):
        return True
    if ", " in name:
        return True
    if "`" in name:
        return True
    return False


def definition_symbol_name(definition: str | None) -> str | None:
    """Extract the defined symbol name from a Faust definition line when simple."""

    if not definition:
        return None
    match = DEFINITION_NAME_RE.match(definition.strip())
    if not match:
        return None
    return match.group(1)


def extract_symbol_licenses(lines: Iterable[str]) -> dict[str, str]:
    """Extract per-symbol license metadata from `declare ... license|licence` lines."""

    licenses: dict[str, str] = {}
    for raw_line in lines:
        match = DECLARE_LICENSE_RE.match(raw_line.strip())
        if not match:
            continue
        symbol_name = match.group(1)
        license_name = match.group(3).strip()
        if license_name:
            licenses[symbol_name] = license_name
    return licenses


def load_license_token_file(path: Path | None) -> tuple[str, ...]:
    """Load one newline-based license token file.

    Empty lines and lines starting with `#` are ignored. Matching is done with
    case-insensitive substring checks, so each non-empty line is interpreted as
    one token/pattern to search for in the normalized license string.
    """

    if path is None:
        return ()

    tokens: list[str] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        token = raw_line.strip().lower()
        if not token or token.startswith("#"):
            continue
        tokens.append(token)
    return tuple(tokens)


def is_commercial_compatible_license(
    license_name: str | None,
    allow_tokens: tuple[str, ...] = COMMERCIAL_COMPATIBLE_TOKENS,
    deny_tokens: tuple[str, ...] = COMMERCIAL_INCOMPATIBLE_TOKENS,
) -> bool:
    """Return whether a license looks commercially compatible.

    This heuristic is intentionally conservative for LLM-assisted code
    generation workflows. It allows common permissive licenses and LGPL-style
    cases, rejects GPL/AGPL/non-commercial markers as not suitable for a
    generic "commercial-compatible" export, and treats the absence of an
    explicit per-symbol license as compatible with the library default.
    """

    if not license_name:
        return True

    normalized = str(license_name).strip().lower()
    if not normalized:
        return True

    if any(token in normalized for token in deny_tokens):
        return False
    return any(token in normalized for token in allow_tokens)


def filter_index_for_license_policy(
    index: dict[str, object],
    policy: str,
    allow_tokens: tuple[str, ...] = COMMERCIAL_COMPATIBLE_TOKENS,
    deny_tokens: tuple[str, ...] = COMMERCIAL_INCOMPATIBLE_TOKENS,
) -> dict[str, object]:
    """Filter an already-built index according to one license policy."""

    if policy == "all":
        return index
    if policy != "commercial-compatible":
        raise ValueError(f"Unsupported license policy: {policy}")

    filtered_libraries: list[dict[str, object]] = []
    filtered_symbols: list[dict[str, object]] = []

    for library in index["libraries"]:
        kept_symbols = [
            symbol for symbol in library.get("symbols", [])
            if is_commercial_compatible_license(
                symbol.get("license"),
                allow_tokens=allow_tokens,
                deny_tokens=deny_tokens,
            )
        ]
        if not kept_symbols:
            continue

        filtered_library = dict(library)
        filtered_library["symbols"] = kept_symbols
        filtered_libraries.append(filtered_library)
        filtered_symbols.extend(kept_symbols)

    filtered_index = dict(index)
    filtered_index["libraries"] = filtered_libraries
    filtered_index["symbols"] = filtered_symbols
    filtered_index["licensePolicy"] = policy
    return filtered_index


def extract_doc_block(lines: list[str], start_index: int) -> dict[str, object] | None:
    """Extract the full documentation block starting at `start_index`.

    The block begins with a documented symbol header, continues through
    subsequent comment lines, and stops when the next symbol header or a real
    non-comment code line is encountered.

    In addition to the comment body, this function also captures the first
    non-comment definition line that follows the block. That extra line enables
    fallback `usage` inference when the docs do not contain an explicit
    `#### Usage` section.
    """

    header_info = parse_symbol_header(lines[start_index] if start_index < len(lines) else "")
    if not header_info:
        return None

    body: list[str] = []
    index = start_index + 1
    while index < len(lines):
        line = lines[index]
        if parse_symbol_header(line):
            break
        if not line.strip().startswith("//"):
            if line.strip():
                break
            index += 1
            continue
        body.append(re.sub(r"^//\s?", "", line))
        index += 1

    definition = None
    definition_index = index
    while definition_index < len(lines):
        candidate = lines[definition_index].strip()
        if not candidate:
            definition_index += 1
            continue
        if candidate.startswith("//"):
            break
        definition = candidate
        break

    return {
        "headerInfo": header_info,
        "body": body,
        "endIndex": index - 1,
        "definition": definition,
    }


def is_separator_line(line: str) -> bool:
    """Return whether a line is only a visual comment separator.

    The Faust docs often include lines made exclusively of dashes or equals to
    visually delimit entries. They should not leak into summaries.
    """

    return bool(SEPARATOR_RE.match(line.strip()))


def split_top_level_args(arg_text: str) -> list[str]:
    """Split a function argument list on top-level commas only.

    Example:
        `a, b(c, d), (x, y)` -> `["a", "b(c, d)", "(x, y)"]`

    This is intentionally shallow: it is only used to build a rough fallback
    `usage` string, not to fully understand Faust syntax.
    """

    parts: list[str] = []
    current: list[str] = []
    depth = 0

    for char in arg_text:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth = max(0, depth - 1)
        elif char == "," and depth == 0:
            part = "".join(current).strip()
            if part:
                parts.append(part)
            current = []
            continue
        current.append(char)

    tail = "".join(current).strip()
    if tail:
        parts.append(tail)
    return parts


def infer_usage_from_definition(name: str, definition: str | None) -> str | None:
    """Infer a minimal `usage` string from the Faust definition line.

    This fallback exists for symbols whose documentation contains a summary but
    no explicit `#### Usage` section.

    Examples:

    - `Rsqrt(x) = ...` -> `_ : Rsqrt(_) : _`
    - `SR = ...` -> `SR : _`

    The output is heuristic by design. It is good enough to derive rough I/O
    arity and to provide a searchable usage hint, but it must not be treated as
    a formal type signature.
    """

    if not definition:
        return None

    escaped_name = re.escape(name)
    match = re.match(rf"^(?:declare\s+{escaped_name}\s+\w+\s+\".*\";\s*)*{escaped_name}\s*(\((.*)\))?\s*=", definition)
    if not match:
        return None

    args_text = match.group(2)
    if args_text is None:
        return f"{name} : _"

    args = split_top_level_args(args_text)
    if not args:
        return f"{name} : _"

    lhs = ",".join("_" for _ in args)
    call = f"{name}({','.join('_' for _ in args)})"
    return f"{lhs} : {call} : _"


def parse_doc_body(body_lines: Iterable[str]) -> dict[str, object]:
    """Parse the comment body associated with one documented symbol.

    The parser recognizes the documentation conventions used in Faust library
    source files:

    - free text before any subsection -> summary
    - `#### Usage` -> usage string or fenced usage block
    - `Where:` -> list of documented parameters
    - general notes that appear inside `Where:` after the parameter bullets
      -> `notes`
    - `#### Test` -> example snippet
    - `#### Reference` / `#### References` -> references list

    Anything not matching those conventions is ignored rather than forced into
    the output schema.
    """

    summary_lines: list[str] = []
    usage_buffer: list[str] = []
    params: list[dict[str, str]] = []
    notes: list[str] = []
    references: list[str] = []
    test_code: str | None = None

    section = "summary"
    in_fence = False
    fence_buffer: list[str] = []
    current_param: dict[str, str] | None = None
    current_note_index: int | None = None

    def is_general_note_line(text: str) -> bool:
        """Heuristically detect note-like prose inside a `Where:` section."""

        return bool(re.match(r"^(note|notes|output|outputs|return|returns|result|results)\b", text, flags=re.IGNORECASE))

    def flush_fence() -> None:
        """Commit the current fenced code block into the active logical section."""

        nonlocal test_code
        text = "\n".join(fence_buffer).strip()
        if not text:
            fence_buffer.clear()
            return
        if section == "usage":
            usage_buffer.extend(line.strip() for line in fence_buffer if line.strip())
        elif section == "test":
            test_code = text
        fence_buffer.clear()

    for raw_line in body_lines:
        line = raw_line.rstrip()
        trimmed = line.strip()

        if trimmed.startswith("#### "):
            if in_fence:
                flush_fence()
                in_fence = False
            title = trimmed[5:].strip().lower()
            if title.startswith("usage"):
                section = "usage"
            elif title.startswith("test"):
                section = "test"
            elif title.startswith("reference"):
                section = "reference"
            else:
                section = "other"
            continue

        if re.match(r"^where\s*:?\s*$", trimmed, flags=re.IGNORECASE):
            section = "where"
            current_param = None
            current_note_index = None
            continue

        if trimmed.startswith("```"):
            if in_fence:
                flush_fence()
                in_fence = False
            else:
                in_fence = True
            continue

        if in_fence:
            fence_buffer.append(line)
            continue

        if section == "summary":
            if trimmed and not is_separator_line(trimmed):
                summary_lines.append(trimmed)
            continue

        if section == "usage":
            if trimmed:
                usage_buffer.append(trimmed)
            continue

        if section == "where":
            match = PARAM_RE.match(trimmed)
            if match:
                current_param = {"name": match.group(1).strip(), "description": match.group(2).strip()}
                params.append(current_param)
                current_note_index = None
            elif current_note_index is not None and trimmed and not trimmed.startswith("* "):
                notes[current_note_index] = f"{notes[current_note_index]} {trimmed}".strip()
            elif current_param and trimmed and not trimmed.startswith("* ") and not is_general_note_line(trimmed):
                current_param["description"] = f"{current_param['description']} {trimmed}".strip()
            elif trimmed and not trimmed.startswith("* "):
                notes.append(trimmed)
                current_note_index = len(notes) - 1
                current_param = None
            continue

        if section == "reference":
            if trimmed.startswith("* "):
                ref_text = trimmed[2:].strip()
                if ref_text:
                    references.append(ref_text)
            elif trimmed:
                references.append(trimmed)

    usage = None
    if usage_buffer:
        if len(usage_buffer) == 1:
            usage = usage_buffer[0]
        else:
            usage = re.sub(r"\s+", " ", " ".join(usage_buffer)).strip()

    return {
        "summary": " ".join(summary_lines).strip(),
        "usage": usage,
        "params": params,
        "notes": notes,
        "testCode": test_code,
        "references": references,
    }


def parse_usage_io(usage: str | None) -> dict[str, int | str | None]:
    """Derive rough input/output signal counts from a Faust usage string.

    The implementation is intentionally conservative. It understands a small
    subset of notations commonly used in the docs:

    - `_` -> one signal
    - `!` -> zero signals
    - comma-separated expressions -> number of comma-separated signals

    If the usage is absent or ambiguous, the counts remain `None`.
    """

    if not usage:
        return {"inSignals": None, "outSignals": None, "raw": None}

    parts = [part.strip() for part in usage.split(":")]
    if len(parts) >= 3:
        lhs = parts[0]
        rhs = parts[-1]
    else:
        lhs = ""
        rhs = parts[-1] if parts else ""

    def count_signals(expr: str) -> int | None:
        if not expr:
            return None
        if expr == "_":
            return 1
        if expr == "!":
            return 0
        if "," in expr:
            return len([part for part in expr.split(",") if part.strip()])
        return 1

    return {"inSignals": count_signals(lhs), "outSignals": count_signals(rhs), "raw": usage}


def build_index(repo_root: Path, stdlib: Path) -> dict[str, object]:
    """Build the full monolithic documentation index.

    The returned structure contains two denormalized views:

    - `libraries`: one entry per visited `.lib` file with its symbol list
    - `symbols`: flat list of all documented symbols across the traversal

    That duplication is deliberate. Library-centric and symbol-centric queries
    are both common, and keeping both views avoids repeated reshaping in client
    code.
    """

    repo_root = repo_root.resolve()
    stdlib = stdlib.resolve()
    if not stdlib.is_file():
        raise FileNotFoundError(f"Missing stdlib file: {stdlib}")

    by_relpath, by_name = discover_lib_files(repo_root)
    visited: set[Path] = set()
    queue: deque[Path] = deque([stdlib])
    alias_hints: dict[str, set[str]] = defaultdict(set)
    libraries: list[dict[str, object]] = []
    symbols: list[dict[str, object]] = []
    seen_ids: dict[str, dict[str, object]] = {}
    seen_qualified_names: dict[str, dict[str, object]] = {}

    while queue:
        file_path = queue.popleft().resolve()
        if file_path in visited:
            continue
        visited.add(file_path)

        source = file_path.read_text(encoding="utf-8")
        lines = source.splitlines()
        symbol_licenses = extract_symbol_licenses(lines)
        file_name = file_path.name
        rel_file = repo_relative(file_path, repo_root)

        # First pass on the file: collect dependency edges and alias hints so
        # that documented symbols can expose meaningful qualified names.
        for ref in parse_library_references(source):
            resolved = resolve_reference(file_path, ref.target, repo_root, by_relpath, by_name)
            if ref.alias and resolved is not None:
                alias_hints[resolved.name].add(ref.alias)
            if resolved is not None:
                queue.append(resolved)

        module_name = file_name[:-4] if file_name.lower().endswith(".lib") else file_name
        hinted_aliases = sorted(alias_hints.get(file_name, set()))
        lib_symbols: list[dict[str, object]] = []

        # Second pass on the file: extract one documented symbol block at a time.
        line_index = 0
        while line_index < len(lines):
            block = extract_doc_block(lines, line_index)
            if not block:
                line_index += 1
                continue

            line_index = int(block["endIndex"])
            header_info = block["headerInfo"]
            body = parse_doc_body(block["body"])

            name = str(header_info["name"] or "").strip()
            if not name:
                line_index += 1
                continue

            source_line_start = int(line_index) - len(block["body"]) + 1
            def_name = definition_symbol_name(block.get("definition"))
            if is_suspicious_symbol_name(name):
                warn(
                    f"suspicious header name {name!r} in {rel_file}:{source_line_start} "
                    f"(header={header_info['header']!r})"
                )
            if def_name and def_name != name:
                warn(
                    f"header/definition mismatch in {rel_file}:{source_line_start}: "
                    f"header name={name!r}, definition name={def_name!r}"
                )

            alias = str(header_info["alias"] or "").strip() or (hinted_aliases[0] if hinted_aliases else module_name)
            usage = body["usage"] or infer_usage_from_definition(name, block.get("definition"))
            io = parse_usage_io(usage)

            # `id` is stable and file-based, while `qualifiedName` is alias-based
            # and therefore closer to how users actually call the symbol.
            symbol = {
                "id": f"{module_name}.{name}",
                "name": name,
                "qualifiedName": f"{alias}.{name}",
                "header": header_info["header"],
                "summary": body["summary"],
                "usage": usage,
                "params": body["params"],
                "notes": body["notes"],
                "io": io,
                "testCode": body["testCode"],
                "references": body["references"],
                "tags": [module_name],
                "source": {
                    "file": file_name,
                    "path": rel_file,
                    "lineStart": source_line_start,
                    "lineEnd": int(block["endIndex"]) + 1,
                },
            }
            if name in symbol_licenses:
                symbol["license"] = symbol_licenses[name]

            previous = seen_ids.get(symbol["id"])
            if previous is not None:
                prev_source = previous["source"]
                warn(
                    f"duplicate symbol id {symbol['id']!r} in {rel_file}:{source_line_start}; "
                    f"previously seen at {prev_source['path']}:{prev_source['lineStart']}"
                )
            else:
                seen_ids[symbol["id"]] = symbol

            previous_qn = seen_qualified_names.get(symbol["qualifiedName"])
            if previous_qn is not None:
                prev_source = previous_qn["source"]
                warn(
                    f"duplicate qualifiedName {symbol['qualifiedName']!r} in {rel_file}:{source_line_start}; "
                    f"previously seen at {prev_source['path']}:{prev_source['lineStart']}"
                )
            else:
                seen_qualified_names[symbol["qualifiedName"]] = symbol

            lib_symbols.append(symbol)
            symbols.append(symbol)
            line_index += 1

        libraries.append(
            {
                "file": file_name,
                "path": rel_file,
                "aliasHints": hinted_aliases,
                "symbols": lib_symbols,
            }
        )

    return {
        "version": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "rootLib": stdlib.name,
        "rootLibPath": repo_relative(stdlib, repo_root),
        "libraries": libraries,
        "symbols": symbols,
    }


def make_symbol_summary(symbol: dict[str, object]) -> dict[str, object]:
    """Project a full symbol entry into a compact search-friendly summary."""

    summary = {
        "id": symbol["id"],
        "name": symbol["name"],
        "qualifiedName": symbol["qualifiedName"],
        "summary": symbol["summary"],
        "usage": symbol["usage"],
        "io": symbol["io"],
        "tags": symbol["tags"],
        "source": symbol["source"],
        "hasTestCode": bool(symbol.get("testCode")),
        "notesCount": len(symbol.get("notes", [])),
        "referencesCount": len(symbol.get("references", [])),
    }
    if symbol.get("license"):
        summary["license"] = symbol["license"]
    return summary


def module_output_relpath(library_path: str) -> str:
    """Return the relative output path for one detailed module JSON file."""

    return normalize_posix_path(PurePosixPath("modules") / PurePosixPath(library_path).with_suffix(".json"))


def build_split_index(index: dict[str, object]) -> tuple[dict[str, object], list[tuple[str, dict[str, object]]]]:
    """Build the split-index layout from the full monolithic index.

    Returns:
        A tuple `(compact_index, module_documents)` where:

        - `compact_index` is the lightweight top-level search index
        - `module_documents` is a list of `(relative_path, payload)` pairs for
          the detailed per-module JSON documents
    """

    compact_libraries: list[dict[str, object]] = []
    compact_symbols: list[dict[str, object]] = []
    module_documents: list[tuple[str, dict[str, object]]] = []

    for library in index["libraries"]:
        library_symbols = library.get("symbols", [])
        symbol_summaries = [make_symbol_summary(symbol) for symbol in library_symbols]
        relpath = module_output_relpath(library["path"])

        compact_libraries.append(
            {
                "file": library["file"],
                "path": library["path"],
                "aliasHints": library.get("aliasHints", []),
                "symbolCount": len(library_symbols),
                "moduleDoc": relpath,
            }
        )
        compact_symbols.extend(symbol_summaries)

        module_documents.append(
            (
                relpath,
                {
                    "version": index["version"],
                    "generatedAt": index["generatedAt"],
                    "rootLib": index["rootLib"],
                    "rootLibPath": index["rootLibPath"],
                    "module": {
                        "file": library["file"],
                        "path": library["path"],
                        "aliasHints": library.get("aliasHints", []),
                    },
                    "symbols": library_symbols,
                },
            )
        )

    compact_index = {
        "version": index["version"],
        "layout": "split-v1",
        "generatedAt": index["generatedAt"],
        "rootLib": index["rootLib"],
        "rootLibPath": index["rootLibPath"],
        "libraries": compact_libraries,
        "symbols": compact_symbols,
    }
    return compact_index, module_documents


def write_json_document(path: Path, payload: dict[str, object], pretty: bool) -> None:
    """Write one JSON document to disk, creating parent directories as needed."""

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=True, indent=2 if pretty else None)
        handle.write("\n")


def write_split_index(index: dict[str, object], split_output_dir: Path, pretty: bool) -> dict[str, object]:
    """Write the split-index layout to `split_output_dir`.

    The directory will contain:

    - `index.json`: compact global index
    - `modules/...`: detailed JSON files, one per library module

    The returned mapping is designed to be merged into the final CLI summary
    printed by `main()`.
    """

    split_output_dir = split_output_dir.resolve()
    compact_index, module_documents = build_split_index(index)

    index_path = split_output_dir / "index.json"
    write_json_document(index_path, compact_index, pretty)

    for relpath, payload in module_documents:
        write_json_document(split_output_dir / relpath, payload, pretty)

    return {
        "splitOutputDir": normalize_posix_path(split_output_dir),
        "splitIndex": normalize_posix_path(index_path),
        "moduleFilesCount": len(module_documents),
    }


def parse_args() -> argparse.Namespace:
    """Build and parse the command-line interface."""

    parser = argparse.ArgumentParser(
        description="Build a JSON index for Faust library documentation comments."
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Root of the faustlibraries checkout (default: script parent repo root).",
    )
    parser.add_argument(
        "--stdlib",
        type=Path,
        default=None,
        help="Entry stdlib file to scan (default: <repo-root>/stdfaust.lib).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("dist/faust-doc-index.json"),
        help="Output JSON path.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output.",
    )
    parser.add_argument(
        "--split-output-dir",
        type=Path,
        default=None,
        help="Optional directory for a split index: compact index.json + detailed modules/*.json.",
    )
    parser.add_argument(
        "--license-policy",
        choices=["all", "commercial-compatible"],
        default="all",
        help=(
            "Optional license filter for exported symbols. "
            "'commercial-compatible' keeps only symbols whose per-function license "
            "matches a conservative allow-list heuristic."
        ),
    )
    parser.add_argument(
        "--license-allowlist-file",
        type=Path,
        default=None,
        help=(
            "Optional newline-based file extending the built-in allowlist "
            "used by --license-policy commercial-compatible."
        ),
    )
    parser.add_argument(
        "--license-denylist-file",
        type=Path,
        default=None,
        help=(
            "Optional newline-based file extending the built-in denylist "
            "used by --license-policy commercial-compatible."
        ),
    )
    return parser.parse_args()


def main() -> int:
    """CLI entry point.

    This function:

    1. parses CLI arguments
    2. builds the full index
    3. writes the monolithic JSON output
    4. optionally writes the split layout
    5. prints a compact machine-readable summary to stdout
    """

    args = parse_args()
    repo_root = args.repo_root.resolve()
    stdlib = args.stdlib.resolve() if args.stdlib else (repo_root / "stdfaust.lib").resolve()
    output = args.output.resolve()
    allow_tokens = COMMERCIAL_COMPATIBLE_TOKENS
    deny_tokens = COMMERCIAL_INCOMPATIBLE_TOKENS

    if args.license_allowlist_file is not None:
        allow_tokens = allow_tokens + load_license_token_file(args.license_allowlist_file.resolve())
    if args.license_denylist_file is not None:
        deny_tokens = deny_tokens + load_license_token_file(args.license_denylist_file.resolve())

    index = build_index(repo_root=repo_root, stdlib=stdlib)
    index = filter_index_for_license_policy(
        index,
        args.license_policy,
        allow_tokens=allow_tokens,
        deny_tokens=deny_tokens,
    )
    write_json_document(output, index, args.pretty)

    split_summary = {}
    if args.split_output_dir:
        split_summary = write_split_index(index, args.split_output_dir, args.pretty)

    summary = {
        "output": normalize_posix_path(output),
        "rootLibPath": index["rootLibPath"],
        "librariesCount": len(index["libraries"]),
        "symbolsCount": len(index["symbols"]),
        "licensePolicy": args.license_policy,
    }
    if args.license_allowlist_file is not None:
        summary["licenseAllowlistFile"] = normalize_posix_path(args.license_allowlist_file.resolve())
    if args.license_denylist_file is not None:
        summary["licenseDenylistFile"] = normalize_posix_path(args.license_denylist_file.resolve())
    summary.update(split_summary)
    print(json.dumps(summary, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
