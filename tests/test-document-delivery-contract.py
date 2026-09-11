#!/usr/bin/env python3

from pathlib import Path
import re

import yaml


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path: str) -> str:
    path = ROOT / relative_path
    assert path.is_file(), f"missing required delivery asset: {relative_path}"
    return path.read_text(encoding="utf-8")


def load_yaml(relative_path: str):
    return yaml.safe_load(read(relative_path))


ASSETS = {
    "prd": "skills-custom/01-product/zx-product-prd/assets/PRD-模板.md",
    "technical": "skills-custom/03-fullstack-arch-dev/zx-dev-architecture/assets/技术设计文档-模板.md",
    "tasks": "skills-custom/06-project-manage/zx-project-organizer/assets/任务清单-模板.md",
    "agents": "skills-custom/06-project-manage/zx-project-organizer/assets/AGENTS-模板.md",
}

documents = {name: read(path) for name, path in ASSETS.items()}
adapter = read("adapters/codex/opc-skills/SKILL.md")

for marker in ("F-001", "BR-001", "AC-001", "NFR-001", "PERM-001", "DATA-001"):
    assert marker in documents["prd"], f"PRD template is missing {marker}"
assert "本文档是需求的唯一来源" not in documents["prd"]
assert "最新明确指令" in documents["prd"]
assert "阻塞问题" in documents["prd"]
assert "非阻塞或延期项" in documents["prd"]
assert "验证方式" in documents["prd"]
assert "关联规则" in documents["prd"]
assert "同一编号不要换义或复用" in documents["prd"]

for marker in (
    "对应 PRD",
    "仓库基线",
    "PRD 状态",
    "交接结论",
    "当前状态与证据",
    "ADR-001",
    "需求追踪",
    "需要复核",
):
    assert marker in documents["technical"], f"technical template is missing {marker}"
for hard_coded_default in (
    "React 18.3.1",
    "Express 4.19.2",
    "JWT，有效期 7 天，存 localStorage",
    "所有表都",
    "每个迁移必须可回滚",
    "可自动执行",
):
    assert hard_coded_default not in documents["technical"], hard_coded_default
assert "lockfile" in documents["technical"]
assert "幂等键" in documents["technical"]

for marker in (
    "🧪",
    "验收状态",
    "不构成执行授权",
    "完整 TASK ID",
    "验证计划与实际证据",
    "当前请求状态",
    "授权来源／时间／单次边界",
    "历史记录不授权未来任务",
    "上游修订",
    "技术设计写明“可以进入实施计划”",
    "并行",
):
    assert marker in documents["tasks"], f"task template is missing {marker}"
assert "阶段之间**严格按顺序**推进" not in documents["tasks"]
assert "单任务预计改动 ≤" not in documents["tasks"]
assert "已授权／需确认／不需要" not in documents["tasks"]

for marker in (
    "复制到仓库根目录并命名为 AGENTS.md",
    "AGENTS.override.md",
    "工作区与变更保护",
    "当前用户明确提出的任务",
    "嵌套 AGENTS.md",
    "git diff --check",
    "花括号占位符",
):
    assert marker in documents["agents"], f"AGENTS template is missing {marker}"
assert len(documents["agents"].encode("utf-8")) < 16 * 1024
assert "| 当前阶段 |" not in documents["agents"]
assert "React" not in documents["agents"]

assert "[PRD](./PRD.md)" in documents["tasks"]
assert "[技术设计](./技术设计.md)" in documents["tasks"]
assert "[任务清单](./docs/任务清单.md)" in documents["agents"]
assert "[UI 设计规范](./docs/UI设计规范.md)" in documents["agents"]

prd_skill = load_yaml("skills-custom/01-product/zx-product-prd/skill.yaml")
assert prd_skill["id"] == "zx-product-prd"
assert prd_skill["version"] == "1.1.0"
assert prd_skill["origin"] == "custom"
assert prd_skill["category"] == "01-product"
assert prd_skill["input_schema"]["properties"]["mode"]["enum"] == [
    "auto",
    "assess",
    "draft",
    "review",
]
assert prd_skill["input_schema"]["properties"]["mode"]["default"] == "auto"
requirement_kind = (
    prd_skill["output_schema"]["properties"]["requirement_register"]["items"]
    ["properties"]["kind"]
)
assert "data" in requirement_kind["enum"]
assert "assets/PRD-模板.md" in prd_skill["prompt"]
for marker in ("blocking", "non-blocking", "BR-", "AC-", "NFR-", "PERM-", "DATA-", "evidence"):
    assert marker in prd_skill["prompt"], f"PRD skill is missing {marker}"

architecture = load_yaml(
    "skills-custom/03-fullstack-arch-dev/zx-dev-architecture/skill.yaml"
)
assert architecture["version"] == "1.4.0"
architecture_inputs = architecture["input_schema"]["properties"]
for field in ("prd_path", "prd_revision", "requirement_ids"):
    assert field in architecture_inputs, f"architecture skill is missing {field}"
architecture_outputs = architecture["output_schema"]
for field in ("upstream_revision", "traceability", "stale_reasons", "handoff_status"):
    assert field in architecture_outputs["required"], f"architecture output does not require {field}"
assert "content_hash" in architecture_outputs["properties"]["upstream_revision"]["required"]
assert "原始 UTF-8 字节" in architecture_outputs["properties"]["upstream_revision"]["properties"]["content_hash"]["description"]
assert "assets/技术设计文档-模板.md" in architecture["prompt"]
for marker in ("stale", "追踪矩阵", "AC-", "NFR-", "DATA-"):
    assert marker in architecture["prompt"], f"architecture skill is missing {marker}"

organizer = load_yaml(
    "skills-custom/06-project-manage/zx-project-organizer/skill.yaml"
)
assert organizer["version"] == "7.2.0"
for asset in ("assets/AGENTS-模板.md", "assets/任务清单-模板.md"):
    assert asset in organizer["prompt"], f"organizer does not route {asset}"
for routed_asset in (
    "skills-custom/01-product/zx-product-prd/assets/PRD-模板.md",
    "skills-custom/03-fullstack-arch-dev/zx-dev-architecture/assets/技术设计文档-模板.md",
):
    assert routed_asset in organizer["prompt"], f"organizer does not route {routed_asset}"
assert "任务清单不构成执行授权" in organizer["prompt"]
assert "最终文件内容不得残留花括号占位符" in organizer["prompt"]
assert "创建/更新/复审 PRD" in adapter and "zx-product-prd" in adapter
assert "创建/更新/复审技术设计" in adapter and "zx-dev-architecture" in adapter

manifest = load_yaml("skill-manifest.yaml")
required = set(manifest["skill_contract"]["required_fields"])
for skill in (prd_skill, architecture, organizer):
    assert required <= skill.keys(), required - skill.keys()
    assert re.fullmatch(manifest["validation"]["version_pattern"], skill["version"])

print("OPCSkills document delivery contract tests passed.")
