#!/usr/bin/env python3
"""Structure governance contracts; these do not substitute for agent scenarios."""
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "skills-custom/06-project-manage/zx-project-organizer"
profile = yaml.safe_load((BASE / "references/zx-full-delivery-structure.yaml").read_text())
skill = yaml.safe_load((BASE / "skill.yaml").read_text())

governance = profile.get("document_governance", {})
assert governance.get("baseline_location") == "docs/README.md", "missing project baseline slot"
assert governance.get("baseline_fields") == ["structure_profile", "template_version", "confirmed_exceptions"]
assert governance.get("missing_baseline") == "unknown-not-latest"
assert governance.get("upgrade") == "compare-propose-confirm-apply"
assert governance.get("ownership") == {
    "project_architecture": "docs/project/05-决策记录",
    "cross_module_decisions": "docs/project/05-决策记录",
    "application_design": "provider-application",
    "interface_contract": "provider-application/specifications",
}
paths = {entry["path"] for entry in profile["directories"]}
assert len(paths) == profile["policy"]["directory_count"] == 38
assert "docs/design/01-信息架构与交互流程" in paths
assert "docs/design/03-品牌与视觉资产" in paths
assert "docs/product/06-PRD" in paths
assert "docs/architecture" not in paths
for phrase in ["缺失登记", "不自动迁移", "已确认例外", "跳号", "creation_plan", "应用内部详细设计"]:
    assert phrase in skill["prompt"], phrase
assert "若custom/adaptive已确认结构不含docs/README.md，不自动创建该文件" in skill["prompt"]
assert "目录基线" in next(x for x in profile["files"] if x["path"] == "docs/README.md")["required_sections"]
print("PASS: baseline slot, ownership, upgrade policy and unchanged 38-directory layout")
