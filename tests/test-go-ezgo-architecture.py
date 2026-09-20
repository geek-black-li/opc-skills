#!/usr/bin/env python3
"""Guard the optional architecture profile and its existing authorization contract."""
from pathlib import Path
import re
import yaml

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "skills-custom/03-fullstack-arch-dev/zx-dev-architecture"
skill = yaml.safe_load((DIRECTORY / "skill.yaml").read_text(encoding="utf-8"))
reference = DIRECTORY / "references/go-ezgo-backend.md"
body = reference.read_text(encoding="utf-8")

# Adding a profile must not replace the existing multi-stack modes or expand writes.
assert skill["id"] == "zx-dev-architecture"
assert skill["category"] == "03-fullstack-arch-dev"
assert skill["origin"] == "custom"
assert skill["input_schema"]["properties"]["mode"]["enum"] == ["auto", "assess", "design", "review"]
assert skill["input_schema"]["required"] == ["project_root", "request"]
assert skill["output_schema"]["properties"]["status"]["enum"] == ["assessed", "drafted", "reviewed", "blocked"]
assert "references/go-ezgo-backend.md" in skill["prompt"]
assert "其他技术栈沿用通用流程" in "\n".join(skill["workflow"])
for guard in ["仅选择Go而未定框架", "未选语言或仅选择单体时不推断Go", "不自动生成工程"]:
    assert guard in skill["prompt"] + "\n".join(skill["constraints"]), guard

# Explicit decision table covers non-Go, unknown framework, another framework,
# and ezgo without a database choice; Mongo is never silently implied.
for scenario in ["尚未选择语言", "框架未定", "已选择Go且确认采用ezgo", "其他框架", "数据库未定"]:
    assert scenario in body, scenario
for required in [
    "serv.NewApp", "WithCLI", "command/logic", "controller/route", "XReq", "XResp",
    "dao/http", "model/mmongo", "Key", "Database", "Collection", "Validate", "OpenAPI",
    "operation_id", "request_id", "期望版本", "同一会话context", "公开方法在前",
    "逐项分行", "内部api免鉴权", "隔离数据库", "SIGTERM", "go test -race",
    "go vet", "GOWORK=off", "不是可直接运行的工程",
]:
    assert required in body, required
assert body.count("```go") == 1
assert body.count("```") % 2 == 0
for forbidden in ["175.27.134.81", "/Users/", "pfc_api", "BEGIN OPENSSH PRIVATE KEY"]:
    assert forbidden not in body, forbidden
assert not re.search(r"\b(?:TODO|TBD|FIXME)\b", body)
record = next(item for item in skill["metadata"]["self_improve_updates"]
              if item["proposal_id"] == "zxsi-8938765c8475f3c3")
assert record["confirmed"] is True
assert record["action"] == "update-skill"
assert record["version_before"] == "1.6.0"
assert record["version_after"] == "1.7.0"
print("PASS: optional Go/ezgo profile, evidence boundaries and existing contracts")
