#!/usr/bin/env python3
"""Ensure Self-Improve cannot silently create or edit a Skill."""

from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
SELFIMPROVE = ROOT / "builtin" / "skill-selfimprove.yaml"
CREATOR = ROOT / "builtin" / "skill-creator.yaml"
EDITOR = ROOT / "builtin" / "skill-editor.yaml"
ADAPTER = ROOT / "adapters" / "codex" / "zx-skills" / "SKILL.md"


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def assert_confirmation_input(skill: dict, expected_action: str) -> None:
    inputs = skill["input_schema"]["properties"]
    assert inputs["invocation_source"]["enum"] == ["direct", "self-improve"]
    assert inputs["invocation_source"]["default"] == "direct"
    confirmation = inputs["self_improve_confirmation"]
    assert set(confirmation["required"]) == {"confirmed", "proposal_id", "action"}
    assert confirmation["properties"]["confirmed"]["const"] is True
    assert confirmation["properties"]["action"]["const"] == expected_action


def main() -> None:
    selfimprove = load_yaml(SELFIMPROVE)
    creator = load_yaml(CREATOR)
    editor = load_yaml(EDITOR)
    adapter = ADAPTER.read_text(encoding="utf-8")

    assert selfimprove["version"] == "3.0.0"
    branches = selfimprove["output_schema"]["oneOf"]
    by_conclusion = {
        branch["properties"]["conclusion"]["const"]: branch for branch in branches
    }
    assert set(by_conclusion) == {"no-action", "create-skill", "update-skill"}

    no_action = by_conclusion["no-action"]
    assert no_action["properties"]["result"]["const"] == "no-action"

    expected_assessment_fields = {
        "reusable_capability",
        "why_worth_distilling",
        "cross_project_scenarios",
        "reuse_evidence",
        "project_specific_exclusions",
        "planned_change",
        "risks",
    }
    for conclusion in ("create-skill", "update-skill"):
        branch = by_conclusion[conclusion]
        properties = branch["properties"]
        assert properties["result"]["const"] == "awaiting-confirmation"
        assert properties["proposal_id"]["pattern"] == "^zxsi-[a-f0-9]{16}$"
        assessment = properties["extraction_assessment"]
        assert set(assessment["required"]) == expected_assessment_fields
        assert {
            "result",
            "conclusion",
            "proposal_id",
            "extraction_assessment",
        }.issubset(branch["required"])

    selfimprove_prompt = selfimprove["prompt"]
    for phrase in (
        "为什么值得提炼",
        "项目独有内容",
        "awaiting-confirmation",
        "同一轮不得调用",
        "canonical JSON",
    ):
        assert phrase in selfimprove_prompt, f"missing self-improve gate: {phrase}"

    assert creator["version"] == "2.2.0"
    assert editor["version"] == "2.2.0"
    assert_confirmation_input(creator, "create-skill")
    assert_confirmation_input(editor, "update-skill")
    assert "blocked" in creator["output_schema"]["properties"]["result"]["enum"]
    assert "blocked" in editor["output_schema"]["properties"]["result"]["enum"]

    for skill in (creator, editor):
        prompt = skill["prompt"]
        for phrase in (
            "invocation_source=self-improve",
            "重新计算 proposal_id",
            "确认不匹配",
            "blocked",
        ):
            assert phrase in prompt, f"missing downstream gate: {phrase}"

    for phrase in (
        "确认提炼",
        "放弃提炼",
        "同一轮不得",
        "awaiting-confirmation",
        "proposal_id",
    ):
        assert phrase in adapter, f"missing adapter confirmation flow: {phrase}"

    print("self-improve user-confirmation gate: ok")


if __name__ == "__main__":
    main()
