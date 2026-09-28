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
for rule in ["Service默认按业务模块", "DAO按数据对象", "New构造方法", "resp.Json(c, err, response)",
             "code/msg/data", "business.go", "code.go", "configs/code.yaml", "X-Request-ID", "WithTx(tx).Write",
             "公开与私有方法", "不为旧写法增加兼容转发", "逐项对照维护者"]:
    assert rule in body, rule
assert "bcontroller.Json(" not in body
assert body.count("```go") == 2
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


# These are instruction-contract regressions, not a claim that an agent or a
# production backend has passed acceptance. Each scenario fixes a known omission.
template = (DIRECTORY / "assets/技术设计文档-模板.md").read_text(encoding="utf-8")
scenarios = {
    "approved-baseline": ["二-B、已确认原型到后端的功能对齐", "确认依据", "原型位置、修订"],
    "missing-list-behavior": ["搜索、筛选、排序、分页", "不能只过滤当前页"],
    "state-or-permission-drift": ["状态转换、角色权限", "不得静默增删业务行为"],
    "mock-is-not-proof": ["模拟成功不能作为真实验证通过", "后端验证不等于前端联调或用户验收"],
    "source-conflict": ["最新用户确认", "受影响项", "不强制没有原型的项目补造原型"],
    "no-second-business-system": ["不以通用CRUD替代原型合同", "不强制一个按钮对应一个接口"],
    "bidirectional-review": ["接口设计后", "授权实现后", "已实现、已验证、未完成和差异"],
}
for scenario, rules in scenarios.items():
    for rule in rules:
        assert rule in skill["prompt"], (scenario, rule)
assert "基于已确认原型设计或复核后端接口的功能覆盖" in skill["triggers"]["intents"]
for rule in ["原型操作 → 接口请求响应 → 业务规则与数据变更 → 验证用例", "已确认原型", "确认依据"]:
    assert rule in template, rule
for rule in ["原型功能对齐", "Route、Controller、Service、DAO及Req/Resp", "已实现、已验证、未完成和差异"]:
    assert rule in body, rule
assert skill["version"] == "1.10.0"
record = next(item for item in skill["metadata"]["self_improve_updates"]
              if item["proposal_id"] == "zxsi-6f8cb8228ec71cf2")
assert record["confirmed"] is True and record["action"] == "update-skill"
assert record["version_before"] == "1.9.0" and record["version_after"] == "1.10.0"
print("PASS: Go/ezgo and 7 prototype-alignment instruction scenarios; authorization contracts unchanged")
