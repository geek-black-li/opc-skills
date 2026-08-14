#!/usr/bin/env python3
from pathlib import Path
import re
import yaml

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


manifest = yaml.safe_load(read("skill-manifest.yaml"))
assert manifest["repository"]["id"] == "opc-skills"
assert manifest["repository"]["name"] == "OPCSkills"

primary = read("adapters/codex/opc-skills/SKILL.md")
compat = read("adapters/codex/zx-skills/SKILL.md")
assert re.search(r"^name: opc-skills$", primary, re.MULTILINE)
assert "$opc-skills" in primary
assert "adapters/codex/opc-skills/SKILL.md" in compat
assert re.search(r"^name: zx-skills$", compat, re.MULTILINE)
assert "## 第三方 Skill" not in compat

reminder = read("templates/codex-agents-reminder.md")
assert "<!-- zx-skills-reminder:start -->" in reminder
assert "$opc-skills 总结一下当前链路" in reminder

assert manifest["validation"]["custom_skill_id_format"] == "zx-<category>-<function>"
for stable_prefix in ("zxsi-", "zpo-"):
    assert stable_prefix in read("scripts/compute-proposal-id.py")
for path in (ROOT / "skills-custom").glob("*/**/skill.y*ml"):
    skill = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert skill["id"].startswith("zx-")
