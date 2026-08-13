#!/usr/bin/env python3
"""Contract checks for zx-project-organizer's proposal/apply safety gate."""

from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
SKILL_PATH = (
    ROOT
    / "skills-custom"
    / "06-project-manage"
    / "zx-project-organizer"
    / "skill.yaml"
)
SCENARIOS_PATH = ROOT / "tests" / "fixtures" / "project-organizer-scenarios.yaml"
ADAPTER_PATH = ROOT / "adapters" / "codex" / "zx-skills" / "SKILL.md"


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def main() -> None:
    skill = load_yaml(SKILL_PATH)
    scenarios = load_yaml(SCENARIOS_PATH)["scenarios"]
    adapter = ADAPTER_PATH.read_text(encoding="utf-8")

    assert skill["version"] == "3.0.0"

    inputs = skill["input_schema"]["properties"]
    assert inputs["action"]["enum"] == ["propose", "apply"]
    assert inputs["action"]["default"] == "propose"
    assert inputs["initialize_git"]["type"] == "boolean"
    assert inputs["initialize_git"]["default"] is False
    assert set(inputs["confirmation"]["required"]) == {"confirmed", "proposal_id"}
    assert inputs["confirmation"]["properties"]["confirmed"]["const"] is True
    assert set(inputs["approved_proposal"]["required"]) == {
        "proposal_id",
        "canonical_payload",
    }

    outputs = skill["output_schema"]["properties"]
    expected_results = {
        "needs-input",
        "awaiting-confirmation",
        "audited",
        "migration-proposed",
        "initialized",
        "reorganized",
        "blocked",
        "validation-failed",
    }
    assert set(outputs["result"]["enum"]) == expected_results
    assert "proposal_id" in outputs
    assert "proposal_payload" in outputs
    assert "creation_plan" in outputs

    plan_item = outputs["creation_plan"]["items"]
    assert set(plan_item["required"]) == {"path", "kind", "operation", "reason"}
    assert set(plan_item["properties"]["kind"]["enum"]) == {
        "directory",
        "file",
        "git-init",
    }
    assert "content" in plan_item["properties"]
    assert "content_sha256" in plan_item["properties"]

    fact_register = outputs["fact_register"]["properties"]
    for bucket in ("confirmed", "inferred", "unknown"):
        item = fact_register[bucket]["items"]
        assert item["type"] == "object"
        assert set(item["required"]) == {"fact", "source"}

    prompt = skill["prompt"]
    required_prompt_phrases = [
        "canonical JSON",
        "proposal_id",
        "approved_proposal.canonical_payload",
        "重新计算",
        "不得重新生成",
        "完整文件内容",
        "initialize_git=true",
        "action=apply",
        "确认不匹配",
    ]
    for phrase in required_prompt_phrases:
        assert phrase in prompt, f"missing organizer rule: {phrase}"

    scenario_by_id = {scenario["id"]: scenario for scenario in scenarios}
    assert set(scenario_by_id) == {
        "unknown-empty-project",
        "confirmed-mobile-api-project",
        "mismatched-proposal-confirmation",
        "initialize-without-git-opt-in",
        "unconfirmed-reorganization",
    }
    assert scenario_by_id["unknown-empty-project"]["expected_changes"] == []
    assert scenario_by_id["mismatched-proposal-confirmation"]["expected_result"] == "blocked"
    assert "git-init" in scenario_by_id["initialize-without-git-opt-in"][
        "forbidden_operations"
    ]

    for phrase in (
        "确认执行项目结构提案",
        "放弃项目结构提案",
        "action=apply",
        "zpo-",
    ):
        assert phrase in adapter, f"missing organizer adapter flow: {phrase}"

    print("zx-project-organizer proposal/apply contract: ok")


if __name__ == "__main__":
    main()
