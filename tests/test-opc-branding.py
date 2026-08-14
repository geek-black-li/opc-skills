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


ACTIVE_BRAND_FILES = [
    "skill-manifest.yaml",
    "builtin/skill-creator.yaml",
    "builtin/skill-editor.yaml",
    "builtin/skill-import-external.yaml",
    "builtin/skill-selfimprove.yaml",
    "templates/codex-agents-reminder.md",
    "scripts/install-codex.sh",
    "scripts/install-codex.ps1",
    "scripts/configure-codex-reminder.sh",
    "scripts/configure-codex-reminder.ps1",
]
for path in ACTIVE_BRAND_FILES:
    assert "ZXSkills" not in read(path), path

manifest = yaml.safe_load(read("skill-manifest.yaml"))
assert manifest["repository"]["id"] == "opc-skills"
assert manifest["repository"]["name"] == "OPCSkills"
assert "skills-temp-inbox/**" in manifest["discovery"]["global_exclude"]
assert manifest["validation"]["custom_skill_id_pattern"].startswith("^zx-")
assert manifest["validation"]["external_forbidden_id_prefixes"] == ["zx-"]

primary = read("adapters/codex/opc-skills/SKILL.md")
assert re.search(r"^name: opc-skills$", primary, re.MULTILINE)
assert "$opc-skills" in primary
assert "$zx-skills" not in primary
assert not (ROOT / "adapters/codex/zx-skills").exists()

reminder = read("templates/codex-agents-reminder.md")
assert "<!-- zx-skills-reminder:start -->" in reminder
assert "<!-- zx-skills-reminder:end -->" in reminder
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

readme = read("README.md")
for phrase in (
    "# OPCSkills：全栈 OPC 本地 Skills 仓库",
    "git clone https://github.com/geek-black-li/opc-skills.git",
    "cd opc-skills",
    "$opc-skills 查看仓库状态",
    "~/.agents/skills/opc-skills",
    "~/.agents/skills/zx-skills",
    "Gitee 备用远程",
    "zx-<category>-<function>",
):
    assert phrase in readme, phrase

assert "`$opc-skills` 是仓库主入口" in readme
assert "`$zx-skills` 仅作为兼容别名" in readme
assert "Gitee 备用远程需要手动同步，不是自动镜像" in readme

daily_use = readme.split("## 日常用法", 1)[1].split("\n## ", 1)[0]
daily_commands = re.findall(r"^\$(?:opc|zx)-skills\b.*$", daily_use, re.MULTILINE)
assert daily_commands
assert all(command.startswith("$opc-skills") for command in daily_commands), daily_commands

for phrase in (
    "adapters/codex/opc-skills/",
    "adapters/codex/zx-skills/",
    "`status` 只有在两个受管入口都正确指向当前仓库时才通过",
    "`uninstall` 只删除这两个由安装器管理的链接",
    "外部路径绝不会被覆盖",
    "旧版只安装了 `$zx-skills`",
    "旧标记 `zx-skills-reminder` 会刻意保持不变",
):
    assert phrase in readme, phrase

for preserved_contract in (
    "### 项目结构整理为什么也分两步",
    "## 常见问题",
    "### 扩展业务分类",
    "#### 个人 Skill 命名空间",
    "### `skills-temp-inbox`：外部 Skill 隔离暂存箱",
    "## 工作流 A：手动沉淀",
    "## 工作流 B：自动 Self-Improve",
    "## 工作流 C：导入第三方 Skill",
    "## 多工具兼容与接入",
    "zx-skills-reminder",
    "zxsi-",
    "zpo-",
    "zx-project-organizer",
    "zx-ui-spec",
    "zx-ui-check",
):
    assert preserved_contract in readme, preserved_contract
