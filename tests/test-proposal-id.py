#!/usr/bin/env python3
"""Cross-tool test vectors for deterministic ZXSkills proposal IDs."""

from pathlib import Path
import json
import subprocess
import sys
import tempfile
from typing import Optional


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "compute-proposal-id.py"


def run(*args: str, stdin: Optional[str] = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        input=stdin,
        text=True,
        capture_output=True,
        check=False,
    )


def main() -> None:
    assert SCRIPT.is_file(), "proposal ID calculator is missing"

    compact = '{"parameters":{"b":2,"a":"中文"},"conclusion":"update-skill"}'
    formatted = json.dumps(json.loads(compact), ensure_ascii=False, indent=2) + "\n"

    first = run("--prefix", "zxsi-", stdin=compact)
    second = run("--prefix", "zxsi-", stdin=formatted)
    assert first.returncode == 0, first.stderr
    assert second.returncode == 0, second.stderr
    assert first.stdout == second.stdout
    assert first.stdout == "zxsi-8bb527a7809fedfb\n"

    with tempfile.TemporaryDirectory() as temp_dir:
        source = Path(temp_dir) / "proposal.json"
        source.write_text(formatted, encoding="utf-8")
        from_file = run("--prefix", "zpo-", "--file", str(source))
    assert from_file.returncode == 0, from_file.stderr
    assert from_file.stdout == "zpo-8bb527a7809fedfb\n"

    invalid_prefix = run("--prefix", "bad", stdin="{}")
    assert invalid_prefix.returncode != 0

    invalid_json = run("--prefix", "zpo-", stdin="not-json\n")
    assert invalid_json.returncode != 0

    print("ZXSkills proposal ID test vectors: ok")


if __name__ == "__main__":
    main()
