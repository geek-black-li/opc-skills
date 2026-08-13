#!/usr/bin/env python3
"""Compute deterministic ZXSkills proposal IDs from a JSON value."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any


PREFIX_PATTERN = re.compile(r"^[a-z][a-z0-9]*-$")


def canonical_json(value: Any) -> bytes:
    """Return compact, recursively key-sorted UTF-8 JSON without a trailing newline."""
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compute <prefix><first-16-hex-of-SHA256(canonical-JSON)>.",
    )
    parser.add_argument(
        "--prefix",
        required=True,
        help="Proposal prefix including the trailing hyphen, such as zxsi- or zpo-.",
    )
    parser.add_argument(
        "--file",
        type=Path,
        help="Read JSON from this UTF-8 file; otherwise read standard input.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not PREFIX_PATTERN.fullmatch(args.prefix):
        print("error: --prefix must match ^[a-z][a-z0-9]*-$", file=sys.stderr)
        return 2

    try:
        raw = args.file.read_text(encoding="utf-8") if args.file else sys.stdin.read()
        value = json.loads(raw)
        digest = hashlib.sha256(canonical_json(value)).hexdigest()[:16]
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print(f"{args.prefix}{digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
