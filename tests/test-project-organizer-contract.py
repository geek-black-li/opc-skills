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
FULL_PROFILE_PATH = (
    SKILL_PATH.parent / "references" / "zx-full-delivery-structure.yaml"
)
GUIDED_WORKFLOWS_PATH = (
    SKILL_PATH.parent / "references" / "guided-project-workflows.yaml"
)


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def main() -> None:
    skill = load_yaml(SKILL_PATH)
    scenarios = load_yaml(SCENARIOS_PATH)["scenarios"]
    adapter = ADAPTER_PATH.read_text(encoding="utf-8")

    assert skill["version"] == "6.0.0"

    inputs = skill["input_schema"]["properties"]
    assert inputs["workflow_mode"]["enum"] == [
        "auto",
        "new-project",
        "existing-project",
    ]
    assert inputs["workflow_mode"]["default"] == "auto"
    project_facts = inputs["project_facts"]["properties"]
    for field in ("purpose", "target_users", "stage", "display_name", "project_slug"):
        assert field in project_facts
    application_item = inputs["applications"]["items"]
    assert set(application_item["required"]) == {"id", "side"}
    assert application_item["properties"]["side"]["enum"] == [
        "frontend",
        "backend",
    ]
    assert application_item["properties"]["scaffold_decision"]["enum"] == [
        "generate",
        "skip",
        "undecided",
    ]
    recommendation_update = inputs["recommendation_updates"]["items"]
    assert set(recommendation_update["required"]) == {
        "question_id",
        "decision",
        "source",
    }
    assert recommendation_update["properties"]["decision"]["enum"] == [
        "accept",
        "reject",
        "revise",
    ]
    selected_option_numbers = recommendation_update["properties"]["selected_option_numbers"]
    assert selected_option_numbers["uniqueItems"] is True
    assert selected_option_numbers["minItems"] == 1
    assert selected_option_numbers["items"] == {"type": "integer", "minimum": 1}
    assert inputs["scaffold_strategy"]["enum"] == [
        "all-skip",
        "all-generate",
        "selective",
    ]
    assert inputs["scaffold_application_ids"]["type"] == "array"
    assert "project_root" not in skill["input_schema"]["required"]
    assert inputs["structure_profile"]["enum"] == [
        "zx-full-delivery",
        "adaptive",
        "custom",
    ]
    assert "default" not in inputs["structure_profile"]
    assert inputs["requested_structure"]["type"] == "string"
    assert set(inputs["pending_fact_proposals"]["items"]["required"]) == {
        "id",
        "fact",
        "source",
    }
    assert set(inputs["fact_updates"]["items"]["required"]) == {
        "fact_id",
        "decision",
        "source",
    }
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
    assert "structure_profile" in outputs
    assert "structure_comparison" in outputs
    assert "guided_question" in outputs
    assert "recommendation_register" in outputs
    assert "application_plan" in outputs
    assert "scaffold_plan" in outputs

    guided_question = outputs["guided_question"]["oneOf"][0]
    assert set(guided_question["required"]) == {
        "id",
        "sequence",
        "question",
        "why_asked",
        "selection_mode",
        "recommended_option_id",
        "recommendation_reason",
        "options",
        "answer_hint",
        "custom_allowed",
    }
    option_item = guided_question["properties"]["options"]["items"]
    assert set(option_item["required"]) == {"id", "number", "label", "impact"}
    assert guided_question["properties"]["recommended_option_id"]["type"] == "string"
    assert guided_question["properties"]["sequence"]["type"] == "integer"
    assert guided_question["properties"]["selection_mode"]["enum"] == ["single", "multiple"]

    recommendation_register = outputs["recommendation_register"]["properties"]
    assert set(recommendation_register) == {
        "accepted",
        "revised",
        "rejected",
        "proposed",
    }

    application_plan = outputs["application_plan"]["items"]
    assert set(application_plan["required"]) == {
        "id",
        "side",
        "name",
        "path",
        "existing",
        "source",
    }
    scaffold_plan = outputs["scaffold_plan"]["items"]
    assert set(scaffold_plan["required"]) == {
        "application_id",
        "generate",
        "status",
        "commands",
        "start_command",
        "test_command",
    }
    assert {item["type"] for item in scaffold_plan["properties"]["generate"]["oneOf"]} == {
        "boolean",
        "null",
    }

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
    proposed_item = fact_register["proposed"]["items"]
    assert set(proposed_item["required"]) == {"id", "fact", "source"}

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
        "zx-full-delivery",
        "adaptive",
        "custom",
        "局部确认",
        "未明确提及",
        "不得把 development 改为 src",
        "structure_comparison",
        "references/zx-full-delivery-structure.yaml",
        "references/guided-project-workflows.yaml",
        "问题顺序从项目位置与标识开始",
        "推荐选项只属于 proposed",
        "development/frontend/apps",
        "development/backend/apps",
        "wx-mini",
        "uniapp",
        "不得创建 services、packages、libs 或 shared-code",
        "接口规范跟随提供方应用",
        "代码骨架先询问批量策略",
        "已有应用不得重新生成代码骨架",
        "workflow_mode",
        "recommendation_register",
        "application_plan",
        "scaffold_plan",
        "当前 guided_question 的推荐必须同时登记到 recommendation_register.proposed",
        "事实不足时推荐安全的澄清选项",
        "全部只创建目录时一次把所有新应用记为 generate=false、status=skipped",
        "基础设施推荐暂不确认基础设施",
        "数量统计不能替代完整目录树",
        "摘要中的应用数量必须从 application_plan 实际条目计算",
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
        "unspecified-structure-profile",
        "zx-full-delivery-profile",
        "partial-fact-confirmation",
        "exact-custom-structure",
        "guided-new-project",
        "recommendation-is-not-confirmation",
        "independent-multi-runtime-apps",
        "selective-runnable-scaffolds",
        "provider-owned-specifications",
        "existing-project-no-regeneration",
        "directory-first-new-project",
        "numeric-question-selection",
        "batch-skip-scaffolds",
        "deferred-infrastructure-default",
        "complete-tree-before-confirmation",
        "complete-tree-before-migration",
        "strict-proposal-render-order",
        "multiple-proposal-ambiguity",
    }
    assert scenario_by_id["unknown-empty-project"]["expected_changes"] == []
    assert scenario_by_id["mismatched-proposal-confirmation"]["expected_result"] == "blocked"
    assert "git-init" in scenario_by_id["initialize-without-git-opt-in"][
        "forbidden_operations"
    ]
    assert scenario_by_id["partial-fact-confirmation"]["expected_unmentioned_status"] == "proposed"
    assert scenario_by_id["guided-new-project"]["expected_next_question"] == "project-location"
    assert "用途" not in scenario_by_id["guided-new-project"]["description"]
    assert scenario_by_id["recommendation-is-not-confirmation"][
        "expected_recommendation_status"
    ] == "proposed"
    assert scenario_by_id["independent-multi-runtime-apps"]["forbidden_paths"] == [
        "development/backend/services/",
        "development/backend/packages/",
        "development/backend/libs/",
        "development/backend/shared-code/",
    ]
    assert scenario_by_id["selective-runnable-scaffolds"][
        "expected_generated_applications"
    ] == ["ai-huoke-web-admin", "ai-huoke"]
    assert scenario_by_id["provider-owned-specifications"]["forbidden_paths"] == [
        "development/specifications/",
        "development/backend/specifications/",
    ]
    assert scenario_by_id["existing-project-no-regeneration"][
        "expected_scaffold_status"
    ] == "skipped"

    guided_workflows = load_yaml(GUIDED_WORKFLOWS_PATH)
    assert guided_workflows["workflow_id"] == "zx-guided-project-workflows"
    assert guided_workflows["version"] == "2.0.0"
    assert guided_workflows["question_policy"]["one_question_at_a_time"] is True
    assert guided_workflows["question_policy"]["numeric_selection"] is True
    assert guided_workflows["question_policy"]["sequence_starts_at"] == 1
    assert guided_workflows["question_policy"]["recommendation_is_confirmation"] is False
    assert guided_workflows["question_policy"]["missing_evidence_policy"] == "recommend-safe-clarification"
    assert guided_workflows["application_policy"]["source_sharing"] == "forbidden"
    assert guided_workflows["application_policy"]["forbidden_container_names"] == [
        "services",
        "packages",
        "libs",
        "shared-code",
    ]
    assert guided_workflows["naming"]["frontend"]["terminal_aliases"]["wechat-mini-program"] == "wx-mini"
    assert guided_workflows["naming"]["frontend"]["terminal_aliases"]["uni-app"] == "uniapp"
    assert guided_workflows["specification_ownership"]["owner"] == "provider-application"
    assert guided_workflows["scaffolding"]["decision_scope"] == "batch-first"
    assert guided_workflows["scaffolding"]["default_recommendation"] == "all-skip"
    assert guided_workflows["scaffolding"]["existing_application_policy"] == "never-regenerate"
    expected_proposal_binding_fields = [
        "mode",
        "workflow_mode",
        "project_root",
        "project_facts",
        "recommendation_register",
        "structure_profile",
        "fact_register.confirmed",
        "application_plan",
        "scaffold_plan",
        "proposed_structure",
        "structure_comparison",
        "creation_plan",
        "migration_map",
        "initialize_git",
    ]
    assert skill["proposal_binding"]["fields"] == expected_proposal_binding_fields
    assert guided_workflows["proposal_binding"]["fields"] == expected_proposal_binding_fields
    assert (
        skill["proposal_binding"]["fields"]
        == guided_workflows["proposal_binding"]["fields"]
    )
    assert skill["proposal_binding"]["field_semantics"]["project_root"] == (
        "resolved-authorized-project-root"
    )
    assert guided_workflows["proposal_binding"]["field_semantics"]["project_root"] == (
        "resolved-authorized-project-root"
    )

    full_profile = load_yaml(FULL_PROFILE_PATH)
    assert full_profile["profile_id"] == "zx-full-delivery"
    assert full_profile["version"] == "2.0.0"
    directories = full_profile["directories"]
    files = full_profile["files"]
    assert len(directories) == 39
    assert len(files) == 4
    directory_paths = {item["path"] for item in directories}
    file_paths = {item["path"] for item in files}
    expected_directories = {
        "docs",
        "docs/project",
        "docs/project/01-项目计划",
        "docs/project/02-里程碑",
        "docs/project/03-风险与阻塞",
        "docs/project/04-会议记录",
        "docs/project/05-决策记录",
        "docs/product",
        "docs/product/00-项目背景",
        "docs/product/01-调研分析",
        "docs/product/02-用户研究",
        "docs/product/03-竞品分析",
        "docs/product/04-需求池",
        "docs/product/05-业务流程",
        "docs/product/06-PRD",
        "docs/product/07-版本规划",
        "docs/product/08-需求评审",
        "docs/product/09-验收标准",
        "docs/design",
        "docs/design/01-信息架构",
        "docs/design/02-用户流程",
        "docs/design/03-低保真原型",
        "docs/design/04-视觉设计",
        "docs/design/05-设计规范",
        "docs/design/06-设计评审",
        "docs/testing",
        "docs/testing/01-测试计划",
        "docs/testing/02-测试用例",
        "docs/testing/03-测试报告",
        "docs/testing/04-验收记录",
        "development",
        "development/frontend",
        "development/frontend/apps",
        "development/backend",
        "development/backend/apps",
        "development/experiments",
        "research",
        "research/sources",
        "research/assets",
    }
    assert directory_paths == expected_directories
    assert file_paths == {"AGENTS.md", "README.md", ".gitignore", "docs/README.md"}
    assert scenario_by_id["zx-full-delivery-profile"]["expected_directory_count"] == 39
    assert not {
        "src",
        "development/frontend/packages",
        "development/frontend/libs",
        "development/frontend/shared-code",
        "development/backend/services",
        "development/backend/packages",
        "development/backend/libs",
        "development/backend/shared-code",
        "docs/architecture",
        "docs/operations",
        "docs/archive",
        "docs/research/inputs",
    } & directory_paths

    for phrase in (
        "确认执行项目结构提案",
        "放弃项目结构提案",
        "action=apply",
        "zpo-",
        "structure_profile=zx-full-delivery",
        "structure_profile=adaptive",
        "structure_profile=custom",
        "不得把整组未提及候选项视为确认",
        "引导我创建一个全新项目",
        "引导我整理现有项目",
        "每个问题都必须提供推荐选项和推荐理由",
        "推荐不等于确认",
        "代码骨架采用批量优先",
        "全部只创建目录",
        "ai-huoke-wx-mini",
        "ai-huoke-uniapp",
        "mode=initialize、workflow_mode=new-project",
        "mode=reorganize、workflow_mode=existing-project",
    ):
        assert phrase in adapter, f"missing organizer adapter flow: {phrase}"
    assert "逐应用确认代码骨架" not in adapter, (
        "adapter must not retain the retired mandatory per-application scaffold flow"
    )

    print("zx-project-organizer proposal/apply contract: ok")


if __name__ == "__main__":
    main()
