#!/usr/bin/env python3
from pathlib import Path
import importlib.util
import re
import subprocess
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


manifest = yaml.safe_load(read("skill-manifest.yaml"))
assert manifest["repository"]["id"] == "opc-skills"
assert manifest["repository"]["name"] == "OPCSkills"
assert "skills-temp-inbox/**" in manifest["discovery"]["global_exclude"]

primary = read("adapters/codex/opc-skills/SKILL.md")
compat = read("adapters/codex/zx-skills/SKILL.md")
assert re.search(r"^name: opc-skills$", primary, re.MULTILINE)
assert "$opc-skills" in primary
assert "adapters/codex/opc-skills/SKILL.md" in compat
assert re.search(r"^name: zx-skills$", compat, re.MULTILINE)
assert len(compat.splitlines()) <= 32
assert re.findall(r"^#{1,6}\s+(.+)$", compat, re.MULTILINE) == ["OPCSkills 兼容入口"]
for primary_heading in (
    "个人命名空间",
    "动态分类",
    "意图路由",
    "第三方 Skill",
    "总结与沉淀",
    "业务 Skill 提案确认",
    "引导式项目创建与整理",
    "输出和变更",
    "示例",
):
    assert f"## {primary_heading}" not in compat

reminder = read("templates/codex-agents-reminder.md")
assert "<!-- zx-skills-reminder:start -->" in reminder
assert "$opc-skills 总结一下当前链路" in reminder

assert manifest["validation"]["custom_skill_id_format"] == "zx-<category>-<function>"
proposal_id_script = ROOT / "scripts/compute-proposal-id.py"
for stable_prefix in ("zxsi-", "zpo-"):
    assert stable_prefix in proposal_id_script.read_text(encoding="utf-8")

proposal_id_spec = importlib.util.spec_from_file_location("compute_proposal_id", proposal_id_script)
assert proposal_id_spec is not None and proposal_id_spec.loader is not None
proposal_id = importlib.util.module_from_spec(proposal_id_spec)
proposal_id_spec.loader.exec_module(proposal_id)

proposal_payload = {"parameters": {"b": 2, "a": "中文"}, "conclusion": "update-skill"}
expected_canonical_json = b'{"conclusion":"update-skill","parameters":{"a":"\xe4\xb8\xad\xe6\x96\x87","b":2}}'
assert proposal_id.canonical_json(proposal_payload) == expected_canonical_json
proposal_result = subprocess.run(
    [sys.executable, str(proposal_id_script), "--prefix", "zxsi-"],
    input='{"parameters":{"b":2,"a":"中文"},"conclusion":"update-skill"}',
    text=True,
    capture_output=True,
    check=False,
)
assert proposal_result.returncode == 0, proposal_result.stderr
assert proposal_result.stdout == "zxsi-8bb527a7809fedfb\n"
assert re.fullmatch(r"zxsi-[0-9a-f]{16}\n", proposal_result.stdout)

for path in (ROOT / "skills-custom").glob("*/**/skill.y*ml"):
    skill = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert skill["id"].startswith("zx-")
