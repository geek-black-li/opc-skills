#!/usr/bin/env python3
"""RED contract for zx-project-organizer's directory-first v6 workflow."""

from pathlib import Path
import json
import re

import yaml


ROOT = Path(__file__).resolve().parents[1]
SKILL_PATH = (
    ROOT
    / "skills-custom"
    / "06-project-manage"
    / "zx-project-organizer"
    / "skill.yaml"
)
WORKFLOWS_PATH = SKILL_PATH.parent / "references" / "guided-project-workflows.yaml"
FULL_PROFILE_PATH = SKILL_PATH.parent / "references" / "zx-full-delivery-structure.yaml"
SCENARIOS_PATH = ROOT / "tests" / "fixtures" / "project-organizer-scenarios.yaml"
ADAPTER_PATH = ROOT / "adapters" / "codex" / "opc-skills" / "SKILL.md"
README_PATH = ROOT / "README.md"
DESIGN_PATH = ROOT / "docs" / "superpowers" / "specs" / "2026-08-14-project-organizer-directory-first-questions-design.md"
PLAN_PATH = ROOT / "docs" / "superpowers" / "plans" / "2026-08-14-project-organizer-directory-first-questions.md"


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


TASK_3_DOCUMENT_PROMPT_PHRASES = (
    "回复数字即可",
    "1=确认当前",
    "暂不确认基础设施",
    "完整目录树",
    "全部只创建目录",
)


TASK_3_COMPLETE_PROPOSAL_GATE_PHRASES = (
    "完整提案门槛",
    "完整目录树",
    "完整 migration/creation map",
    "完整 planned file contents/commands",
    "风险与校验",
    "数量摘要不能替代",
)


USER_FACING_PROPOSAL_SEQUENCE = [
    "complete-proposed-structure",
    "complete-migration-or-creation-map",
    "complete-planned-file-contents-and-commands",
    "risks-and-validation",
    "concrete-proposal-id",
    "proposal-actions",
]


DECLARED_EXAMPLE_APPLICATION_PATHS = {
    "development/frontend/apps/ai-huoke-web-admin",
    "development/backend/apps/ai-huoke",
}


BACKEND_TYPE_CONTRACT = {
    "backend-monolith": {
        "role": "单体后端",
        "path_patterns": [
            "development/backend/apps/<project-slug>",
            "development/backend/apps/<project-slug>-api",
        ],
    },
    "backend-application": {
        "role": "独立后端应用",
        "path_patterns": ["development/backend/apps/<project-slug>-<responsibility>"],
    },
    "api-gateway": {
        "role": "API 网关",
        "path_patterns": ["development/backend/apps/<project-slug>-gateway"],
    },
    "bff": {
        "role": "BFF",
        "path_patterns": ["development/backend/apps/<project-slug>-<terminal>-bff"],
    },
    "background-worker": {
        "role": "后台任务",
        "path_patterns": ["development/backend/apps/<project-slug>-worker"],
    },
    "scheduled-job": {
        "role": "定时任务",
        "path_patterns": ["development/backend/apps/<project-slug>-scheduler"],
    },
    "data-sync": {
        "role": "数据同步",
        "path_patterns": [
            "development/backend/apps/<project-slug>-data-sync",
            "development/backend/apps/<project-slug>-data-sync-job",
        ],
    },
}


def parse_readme_tree_paths(tree: str) -> set[str]:
    """Extract normalized paths from the designated README Unicode tree fence."""
    parents: list[str] = []
    paths: set[str] = set()
    for line in tree.splitlines()[1:]:
        match = re.match(r"^(?P<prefix>(?:(?:│   )|(?:    ))*)(?:├── |└── )(?P<name>.+)$", line)
        assert match, f"unparseable README tree line: {line!r}"
        depth = len(match.group("prefix")) // 4
        name = match.group("name")
        is_directory = name.endswith("/")
        name = name.rstrip("/")
        parents[depth:] = [name]
        path = "/".join(parents)
        paths.add(path)
        if not is_directory:
            parents[depth:] = []
    return paths


def assert_task_3_document_contract(adapter: str, readme: str) -> None:
    """The adapter and README expose the same directory-first user contract."""
    for phrase in TASK_3_DOCUMENT_PROMPT_PHRASES:
        assert phrase in adapter, f"missing organizer adapter flow: {phrase}"
        assert phrase in readme, f"missing organizer README flow: {phrase}"
    for phrase in TASK_3_COMPLETE_PROPOSAL_GATE_PHRASES:
        assert phrase in adapter, f"missing organizer adapter confirmation gate: {phrase}"
        assert phrase in readme, f"missing organizer README confirmation gate: {phrase}"
    for example in ("` 1 `", "`1, 3,1`", "`[1,3]`"):
        assert example in adapter, f"missing adapter numeric normalization example: {example}"
        assert example in readme, f"missing README numeric normalization example: {example}"

    complete_tree = re.search(
        r"#### 完整提案确认示例.*?完整目录树：\n\n```text\n(.*?)\n```",
        readme,
        re.DOTALL,
    )
    assert complete_tree, "missing README complete proposal tree example"
    tree = complete_tree.group(1)
    for marker in ("...", "{…}", "其余同模板"):
        assert marker not in tree, f"README tree example uses omission marker: {marker}"

    full_profile = load_yaml(FULL_PROFILE_PATH)
    required_paths = {
        *(item["path"] for item in full_profile["directories"]),
        *(item["path"] for item in full_profile["files"]),
    }
    tree_paths = parse_readme_tree_paths(tree)
    assert required_paths <= tree_paths, (
        f"README complete tree omits full-profile nodes: {sorted(required_paths - tree_paths)}"
    )
    additional_paths = tree_paths - required_paths
    assert additional_paths == DECLARED_EXAMPLE_APPLICATION_PATHS, (
        "README complete tree additions must be exactly the two declared application roots; "
        f"got {sorted(additional_paths)}"
    )
    assert (
        "development/frontend/apps/ai-huoke-web-admin/unreviewed-file"
        not in DECLARED_EXAMPLE_APPLICATION_PATHS
    )

    example = re.search(
        r"#### 完整提案确认示例(?P<body>.*?)\n该契约保存在",
        readme,
        re.DOTALL,
    )
    assert example, "missing bounded README complete proposal example"
    example_body = example.group("body")
    required_order = (
        "完整目录树：",
        "完整迁移/创建映射：",
        "完整文件内容与命令（如有）：",
        "风险与校验：",
        "proposal_id: zpo-0123456789abcdef",
        "1=确认当前 proposal_id",
        "2=返回修改",
        "3=放弃",
    )
    positions = [example_body.index(item) for item in required_order]
    assert positions == sorted(positions), "README final actions appear before required proposal material"
    file_content_start = positions[2]
    file_content_end = positions[3]
    assert "docs/README.md" in example_body[file_content_start:file_content_end], (
        "README complete proposal file contents omit docs/README.md"
    )
    adapter_gate = re.search(r"完整提案门槛：(?P<body>.*?)\n\n", adapter, re.DOTALL)
    assert adapter_gate, "missing bounded adapter complete-proposal gate"
    adapter_order = (
        "完整目录树",
        "完整 migration/creation map",
        "完整 planned file contents/commands",
        "风险与校验",
        "具体 proposal_id",
        "1=确认当前 proposal_id",
        "2=返回修改",
        "3=放弃",
    )
    adapter_positions = [adapter_gate.group("body").index(item) for item in adapter_order]
    assert adapter_positions == sorted(adapter_positions), (
        "adapter final actions appear before required proposal material"
    )


class SchemaValidationError(AssertionError):
    """Raised when the focused JSON Schema subset rejects an instance."""


SCHEMA_KEYWORDS = {
    "additionalProperties",
    "allOf",
    "const",
    "default",
    "description",
    "enum",
    "if",
    "items",
    "maxItems",
    "minLength",
    "minItems",
    "minimum",
    "not",
    "oneOf",
    "pattern",
    "prefixItems",
    "properties",
    "required",
    "then",
    "type",
    "uniqueItems",
}


def assert_supported_schema(schema: dict, path: str = "$") -> None:
    unsupported = set(schema) - SCHEMA_KEYWORDS
    if unsupported:
        raise AssertionError(f"unsupported JSON Schema keywords at {path}: {unsupported}")
    for name, child in schema.get("properties", {}).items():
        assert_supported_schema(child, f"{path}.properties.{name}")
    if "items" in schema:
        assert_supported_schema(schema["items"], f"{path}.items")
    for index, child in enumerate(schema.get("allOf", [])):
        assert_supported_schema(child, f"{path}.allOf[{index}]")
    for keyword in ("if", "then"):
        if keyword in schema:
            assert_supported_schema(schema[keyword], f"{path}.{keyword}")
    if "not" in schema:
        assert_supported_schema(schema["not"], f"{path}.not")
    for index, child in enumerate(schema.get("oneOf", [])):
        assert_supported_schema(child, f"{path}.oneOf[{index}]")
    for index, child in enumerate(schema.get("prefixItems", [])):
        assert_supported_schema(child, f"{path}.prefixItems[{index}]")


def validate_schema(schema: dict, instance: object, path: str = "$") -> None:
    assert_supported_schema(schema, path)

    expected_type = schema.get("type")
    type_checks = {
        "object": lambda value: isinstance(value, dict),
        "array": lambda value: isinstance(value, list),
        "integer": lambda value: isinstance(value, int) and not isinstance(value, bool),
        "string": lambda value: isinstance(value, str),
        "boolean": lambda value: isinstance(value, bool),
        "null": lambda value: value is None,
    }
    if expected_type and not type_checks[expected_type](instance):
        raise SchemaValidationError(f"{path}: expected {expected_type}")
    if "const" in schema and instance != schema["const"]:
        raise SchemaValidationError(f"{path}: expected const {schema['const']!r}")
    if "enum" in schema and instance not in schema["enum"]:
        raise SchemaValidationError(f"{path}: value is not in enum")
    if "minimum" in schema and instance < schema["minimum"]:
        raise SchemaValidationError(f"{path}: value is below minimum")
    if "minLength" in schema and len(instance) < schema["minLength"]:
        raise SchemaValidationError(f"{path}: shorter than minLength")
    if "pattern" in schema and not re.search(schema["pattern"], instance):
        raise SchemaValidationError(f"{path}: does not match pattern")
    if "not" in schema:
        try:
            validate_schema(schema["not"], instance, path)
        except SchemaValidationError:
            pass
        else:
            raise SchemaValidationError(f"{path}: matched forbidden schema")
    if "oneOf" in schema:
        matches = 0
        for branch in schema["oneOf"]:
            try:
                validate_schema(branch, instance, path)
            except SchemaValidationError:
                continue
            matches += 1
        if matches != 1:
            raise SchemaValidationError(f"{path}: expected exactly one oneOf match, got {matches}")

    if isinstance(instance, dict):
        properties = schema.get("properties", {})
        for name in schema.get("required", []):
            if name not in instance:
                raise SchemaValidationError(f"{path}: missing required property {name}")
        if schema.get("additionalProperties") is False:
            extras = set(instance) - set(properties)
            if extras:
                raise SchemaValidationError(f"{path}: unexpected properties {extras}")
        for name, value in instance.items():
            if name in properties:
                validate_schema(properties[name], value, f"{path}.{name}")

    if isinstance(instance, list):
        if len(instance) < schema.get("minItems", 0):
            raise SchemaValidationError(f"{path}: fewer than minItems")
        if "maxItems" in schema and len(instance) > schema["maxItems"]:
            raise SchemaValidationError(f"{path}: more than maxItems")
        if schema.get("uniqueItems") and len(
            {json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) for value in instance}
        ) != len(instance):
            raise SchemaValidationError(f"{path}: duplicate items")
        for index, item_schema in enumerate(schema.get("prefixItems", [])):
            if index < len(instance):
                validate_schema(item_schema, instance[index], f"{path}[{index}]")
        if "items" in schema:
            for index, value in enumerate(instance):
                validate_schema(schema["items"], value, f"{path}[{index}]")

    for branch in schema.get("allOf", []):
        if "if" not in branch:
            validate_schema(branch, instance, path)
            continue
        try:
            validate_schema(branch["if"], instance, path)
        except SchemaValidationError:
            continue
        if "then" in branch:
            validate_schema(branch["then"], instance, path)


def assert_schema_accepts(schema: dict, instance: object) -> None:
    validate_schema(schema, instance)


def assert_schema_rejects(schema: dict, instance: object) -> None:
    try:
        validate_schema(schema, instance)
    except SchemaValidationError:
        return
    raise AssertionError(f"schema accepted invalid instance: {instance!r}")


def guided_question(selection_mode: str, option_count: int, number_start: int = 1) -> dict:
    return {
        "id": "project-location",
        "sequence": 1,
        "question": "项目目录位置、名称和英文标识使用哪组？",
        "why_asked": "路径和项目标识会影响目录提案。",
        "selection_mode": selection_mode,
        "recommended_option_id": "recommended",
        "recommendation_reason": "便于验证数字选项。",
        "options": [
            {
                "id": f"option-{number}",
                "number": number_start + number - 1,
                "label": f"选项 {number}",
                "impact": "测试用选项。",
            }
            for number in range(1, option_count + 1)
        ],
        "answer_hint": "回复数字即可，例如：1",
        "custom_allowed": True,
    }


def main() -> None:
    skill = load_yaml(SKILL_PATH)
    workflows = load_yaml(WORKFLOWS_PATH)
    scenarios = {scenario["id"]: scenario for scenario in load_yaml(SCENARIOS_PATH)["scenarios"]}
    adapter = ADAPTER_PATH.read_text(encoding="utf-8")
    readme = README_PATH.read_text(encoding="utf-8")
    design = DESIGN_PATH.read_text(encoding="utf-8")
    plan = PLAN_PATH.read_text(encoding="utf-8")

    assert_task_3_document_contract(adapter, readme)
    for document_name, document in (("design", design), ("plan", plan)):
        for phrase in (
            "人工裁决 1",
            "人工裁决 2",
            "backend-application",
            "background-worker",
            "scheduled-job",
            "data-sync",
            "canonical role",
        ):
            assert phrase in document, f"missing {phrase!r} in {document_name}"
    assert "原始 `stage_ids[:5]` 断言已被取代" in plan
    assert "scaffold-details` 仅在 `any-scaffold-generate` 时出现" in plan

    assert scenarios["directory-first-new-project"] == {
        "id": "directory-first-new-project",
        "description": "只要求创建工作目录时，先确认目标位置与标识，不询问用途、用户或阶段。",
        "workflow_mode": "new-project",
        "expected_next_question": "project-location",
        "forbidden_blocking_questions": [
            "project-purpose",
            "target-users",
            "project-stage",
        ],
        "expected_changes": [],
    }
    assert scenarios["numeric-question-selection"] == {
        "id": "numeric-question-selection",
        "description": "用户可以只回复当前问题的数字选项。",
        "expected_sequence": 1,
        "expected_selection_mode": "single",
        "expected_answer_hint": "回复数字即可，例如：1",
    }
    assert scenarios["batch-skip-scaffolds"] == {
        "id": "batch-skip-scaffolds",
        "description": "全部应用只建目录时，只需一次批量决定。",
        "scaffold_strategy": "all-skip",
        "expected_question_count": 1,
        "expected_generate": False,
        "expected_status": "skipped",
    }
    assert scenarios["deferred-infrastructure-default"] == {
        "id": "deferred-infrastructure-default",
        "description": "未知基础设施不会阻塞目录提案，也不会生成推测性配置。",
        "expected_recommended_option": "defer-infrastructure",
        "forbidden_components": [
            "database",
            "cache",
            "message-queue",
            "scheduled-jobs",
        ],
    }
    assert scenarios["complete-tree-before-confirmation"] == {
        "id": "complete-tree-before-confirmation",
        "description": "最终确认前必须展示完整目录树，数量摘要不能替代结构。",
        "expected_result": "awaiting-confirmation",
        "require_complete_proposed_structure": True,
        "forbidden_rendering": ["其余目录同模板", "..."],
    }
    assert scenarios["complete-tree-before-migration"] == {
        "id": "complete-tree-before-migration",
        "description": "存量项目迁移提案也必须在数字操作前展示完整目录树。",
        "expected_result": "migration-proposed",
        "expected_tree_source": "proposed_structure",
        "expected_code_fence": "text",
        "abridgement_forbidden": True,
        "expected_numeric_actions": {
            1: "confirm-current-proposal",
            2: "revise-current-proposal",
            3: "abandon-current-proposal",
        },
    }
    assert scenarios["strict-proposal-render-order"] == {
        "id": "strict-proposal-render-order",
        "description": "可执行提案的用户可见素材必须全部出现后，最后才显示 1/2/3。",
        "expected_user_facing_sequence": USER_FACING_PROPOSAL_SEQUENCE,
        "proposal_actions_field": "proposal_actions",
        "forbidden_early_action_fields": ["summary", "follow_ups"],
    }
    assert scenarios["multiple-proposal-ambiguity"] == {
        "id": "multiple-proposal-ambiguity",
        "description": "同时存在两个仍可识别的提案时，纯数字 1 不得选择任一提案。",
        "numeric_reply": "1",
        "identifiable_proposal_count": 2,
        "expected_result": "needs-input",
        "expected_selected_proposal": None,
        "expected_writes": 0,
    }

    assert skill["version"] == "6.0.0"
    assert "project_root" not in skill["input_schema"]["required"]

    update = skill["input_schema"]["properties"]["recommendation_updates"]["items"]
    assert update["properties"]["selected_option_numbers"]["items"]["type"] == "integer"

    inputs = skill["input_schema"]
    selective_ids = inputs["properties"]["scaffold_application_ids"]
    assert selective_ids["minItems"] == 1
    assert selective_ids["uniqueItems"] is True
    selective_guard = inputs["allOf"][0]
    assert selective_guard["if"]["properties"]["scaffold_strategy"]["const"] == "selective"
    assert selective_guard["then"]["required"] == ["scaffold_application_ids"]
    assert_schema_rejects(inputs, {"mode": "initialize", "context": "test", "scaffold_strategy": "selective"})
    assert_schema_rejects(
        inputs,
        {
            "mode": "initialize",
            "context": "test",
            "scaffold_strategy": "selective",
            "scaffold_application_ids": [],
        },
    )
    assert_schema_accepts(
        inputs,
        {
            "mode": "initialize",
            "context": "test",
            "scaffold_strategy": "selective",
            "scaffold_application_ids": ["example-app"],
        },
    )

    question = skill["output_schema"]["properties"]["guided_question"]["oneOf"][0]
    assert {"sequence", "selection_mode", "answer_hint"}.issubset(question["required"])
    assert question["properties"]["sequence"]["type"] == "integer"
    assert question["properties"]["sequence"]["minimum"] == 1
    assert question["properties"]["selection_mode"]["enum"] == ["single", "multiple"]

    option = question["properties"]["options"]["items"]
    assert "number" in option["required"]
    assert option["properties"]["number"]["type"] == "integer"
    assert option["properties"]["number"]["minimum"] == 1
    assert question["properties"]["options"]["minItems"] == 2
    assert question["properties"]["options"]["maxItems"] == 8
    option_limits = question["allOf"]
    assert option_limits[0]["if"]["properties"]["selection_mode"]["const"] == "single"
    assert option_limits[0]["then"]["properties"]["options"]["maxItems"] == 4
    assert option_limits[1]["if"]["properties"]["selection_mode"]["const"] == "multiple"
    assert option_limits[1]["then"]["properties"]["options"]["maxItems"] == 8
    assert_schema_rejects(question, guided_question("single", 5))
    assert_schema_accepts(question, guided_question("single", 4))
    assert_schema_accepts(question, guided_question("multiple", 8))
    assert_schema_rejects(question, {**guided_question("single", 2), "sequence": 0})
    assert_schema_rejects(question, guided_question("single", 2, number_start=0))

    stages = workflows["new_project_stages"]
    stage_ids = [stage["id"] for stage in stages]
    assert stage_ids[:4] == [
        "project-location",
        "structure-profile",
        "applications",
        "scaffold-strategy",
    ]
    scaffold_details_index = stage_ids.index("scaffold-details")
    infrastructure_index = stage_ids.index("infrastructure")
    assert stages[scaffold_details_index]["condition"] == "any-scaffold-generate"
    assert scaffold_details_index == stage_ids.index("scaffold-strategy") + 1
    assert infrastructure_index == scaffold_details_index + 1
    assert not {"project-purpose", "target-users", "project-stage"} & set(stage_ids)

    assert workflows["scaffolding"]["decision_scope"] == "batch-first"
    assert workflows["scaffolding"]["default_recommendation"] == "all-skip"
    assert workflows["infrastructure"]["default_recommendation"] == "defer-infrastructure"
    rendering = workflows["rendering"]
    assert rendering["complete_tree_required"] is True
    assert rendering["results"] == ["awaiting-confirmation", "migration-proposed"]
    assert rendering["tree_source"] == "proposed_structure"
    assert rendering["tree_code_fence"] == "text"
    assert rendering["abridgement_forbidden"] is True
    assert rendering["numeric_proposal_actions"] == {
        1: "confirm-current-proposal",
        2: "revise-current-proposal",
        3: "abandon-current-proposal",
    }
    assert rendering["user_facing_sequence"] == USER_FACING_PROPOSAL_SEQUENCE
    assert rendering["proposal_actions_contract"] == {
        "output_field": "proposal_actions",
        "render_position": "last",
        "forbidden_in_earlier_fields": True,
        "earlier_fields_include": ["summary", "follow_ups"],
        "object_key_order_is_not_render_order": True,
    }
    assert rendering["numeric_reply_ambiguity"] == {
        "requires_exactly_one_current_proposal": True,
        "multiple_identifiable_proposals_result": "needs-input",
        "select_proposal_on_ambiguity": False,
        "writes_on_ambiguity": "forbidden",
    }

    output_properties = skill["output_schema"]["properties"]
    proposal_actions = output_properties["proposal_actions"]
    assert proposal_actions["type"] == "array"
    assert proposal_actions["maxItems"] == 3
    assert proposal_actions["uniqueItems"] is True
    assert proposal_actions["description"].startswith(
        "提案数字操作的唯一输出字段"
    )
    expected_actions = [
        {"number": 1, "action": "confirm-current-proposal", "label": "确认当前 proposal_id"},
        {"number": 2, "action": "revise-current-proposal", "label": "返回修改"},
        {"number": 3, "action": "abandon-current-proposal", "label": "放弃"},
    ]
    action_variants = proposal_actions["items"]["oneOf"]
    assert len(action_variants) == 3
    for variant, expected in zip(action_variants, expected_actions):
        assert set(variant["required"]) == {"number", "action", "label"}
        assert variant["additionalProperties"] is False
        assert {
            name: definition["const"]
            for name, definition in variant["properties"].items()
        } == expected
    action_output_contract = {
        "type": "object",
        "properties": {
            "result": output_properties["result"],
            "proposal_actions": proposal_actions,
        },
        "required": ["result", "proposal_actions"],
        "allOf": skill["output_schema"]["allOf"],
        "additionalProperties": False,
    }
    assert_schema_accepts(
        action_output_contract,
        {"result": "awaiting-confirmation", "proposal_actions": expected_actions},
    )
    assert_schema_accepts(
        action_output_contract,
        {"result": "needs-input", "proposal_actions": []},
    )
    assert_schema_rejects(
        action_output_contract,
        {"result": "awaiting-confirmation", "proposal_actions": expected_actions[:2]},
    )
    assert_schema_rejects(
        action_output_contract,
        {
            "result": "migration-proposed",
            "proposal_actions": [
                {**expected_actions[0], "action": "revise-current-proposal"},
                expected_actions[1],
                expected_actions[2],
            ],
        },
    )
    assert_schema_rejects(
        action_output_contract,
        {
            "result": "awaiting-confirmation",
            "proposal_actions": [expected_actions[0], expected_actions[0], expected_actions[2]],
        },
    )
    assert_schema_rejects(
        action_output_contract,
        {"result": "awaiting-confirmation", "proposal_actions": list(reversed(expected_actions))},
    )
    assert_schema_rejects(
        action_output_contract,
        {"result": "needs-input", "proposal_actions": expected_actions},
    )
    assert "proposal_actions" in skill["output_schema"]["required"]
    assert "不得包含提案操作文案" in output_properties["follow_ups"]["description"]
    assert workflows["question_policy"]["enforcement_mode"] == "prompt-contract"
    assert workflows["question_policy"]["forward_test_required"] is True

    backend_semantics = {
        item["id"]: item for item in workflows["application_semantics"]["backend"]
    }
    assert set(backend_semantics) == set(BACKEND_TYPE_CONTRACT)
    for application_type, expected in BACKEND_TYPE_CONTRACT.items():
        semantic = backend_semantics[application_type]
        assert semantic["canonical_role"] == expected["role"]
        assert semantic["path_patterns"] == expected["path_patterns"]
    catalog_selection = workflows["application_semantics"]["catalog_selection"]
    assert catalog_selection == {
        "maximum_question_options": 8,
        "select_relevant_for_context": True,
        "show_entire_catalog": False,
    }
    monolith = backend_semantics["backend-monolith"]
    assert monolith["label"] == "单体后端"
    assert "承载业务能力" in monolith["description"]
    assert "不是 API Gateway 或 BFF" in monolith["description"]
    assert monolith["path_patterns"] == [
        "development/backend/apps/<project-slug>",
        "development/backend/apps/<project-slug>-api",
    ]
    assert "网关边界" in backend_semantics["api-gateway"]["description"]
    assert "不等同业务单体" in backend_semantics["api-gateway"]["description"]
    assert "面向特定前端的聚合层" in backend_semantics["bff"]["description"]
    assert "不等同业务单体" in backend_semantics["bff"]["description"]
    assert all(
        "单一后端 API" not in item["label"] for item in backend_semantics.values()
    )

    application_type_enum = inputs["properties"]["applications"]["items"]["properties"][
        "application_type"
    ]["enum"]
    assert application_type_enum == list(BACKEND_TYPE_CONTRACT)
    valid_input_backend_application = {
        "id": "ai-huoke-api",
        "side": "backend",
        "name": "ai-huoke-api",
        "application_type": "backend-monolith",
        "role": "单体后端",
        "existing": False,
        "scaffold_decision": "skip",
        "specifications": [],
    }
    valid_input_with_backend = {
        "mode": "initialize",
        "context": "test",
        "applications": [valid_input_backend_application],
    }
    assert_schema_accepts(inputs, valid_input_with_backend)
    for missing_field in ("application_type", "role"):
        assert_schema_rejects(
            inputs,
            {
                **valid_input_with_backend,
                "applications": [
                    {
                        key: value
                        for key, value in valid_input_backend_application.items()
                        if key != missing_field
                    }
                ],
            },
        )

    application_properties = inputs["properties"]["applications"]["items"]["properties"]
    assert application_properties["responsibility"] == {
        "type": "string",
        "minLength": 1,
    }
    assert application_properties["terminal"] == {
        "type": "string",
        "minLength": 1,
    }

    positive_backend_applications = (
        ("backend-monolith", "单体后端", "ai-huoke-api", {}),
        (
            "backend-application",
            "独立后端应用",
            "ai-huoke-orders",
            {"responsibility": "orders"},
        ),
        ("api-gateway", "API 网关", "ai-huoke-gateway", {}),
        ("bff", "BFF", "ai-huoke-web-bff", {"terminal": "web"}),
        ("background-worker", "后台任务", "ai-huoke-worker", {}),
        ("scheduled-job", "定时任务", "ai-huoke-scheduler", {}),
        ("data-sync", "数据同步", "ai-huoke-data-sync", {}),
        ("data-sync", "数据同步", "ai-huoke-data-sync-job", {}),
    )
    for application_type, role, name, parameter_fields in positive_backend_applications:
        assert_schema_accepts(
            inputs,
            {
                "mode": "reorganize",
                "context": "existing application with unknown technology stack",
                "scaffold_strategy": "all-skip",
                "applications": [
                    {
                        "id": name,
                        "side": "backend",
                        "name": name,
                        "application_type": application_type,
                        "role": role,
                        **parameter_fields,
                        "existing": True,
                        "scaffold_decision": "skip",
                        "specifications": [],
                    }
                ],
            },
        )

    data_sync_input_base = {
        "mode": "initialize",
        "context": "new data-sync application naming",
        "applications": [
            {
                "id": "data-sync",
                "side": "backend",
                "name": "ai-huoke-importer",
                "application_type": "data-sync",
                "role": "数据同步",
                "existing": False,
                "scaffold_decision": "skip",
                "specifications": [],
            }
        ],
    }
    assert_schema_rejects(inputs, data_sync_input_base)
    for data_sync_name in ("ai-huoke-data-sync", "ai-huoke-data-sync-job"):
        assert_schema_accepts(
            inputs,
            {
                **data_sync_input_base,
                "applications": [
                    {**data_sync_input_base["applications"][0], "name": data_sync_name}
                ],
            },
        )
    assert_schema_accepts(
        inputs,
        {
            **data_sync_input_base,
            "applications": [{**data_sync_input_base["applications"][0], "existing": True}],
        },
    )

    for application_type, target_field, target_value, name in (
        ("backend-application", "responsibility", "orders", "ai-huoke-orders"),
        ("bff", "terminal", "web", "ai-huoke-web-bff"),
    ):
        canonical_role = BACKEND_TYPE_CONTRACT[application_type]["role"]
        valid_application = {
            "id": name,
            "side": "backend",
            "name": name,
            "application_type": application_type,
            "role": canonical_role,
            target_field: target_value,
            "existing": False,
            "scaffold_decision": "skip",
            "specifications": [],
        }
        assert_schema_accepts(
            inputs,
            {"mode": "initialize", "context": "parameterized backend", "applications": [valid_application]},
        )
        assert_schema_rejects(
            inputs,
            {
                "mode": "initialize",
                "context": "parameterized backend missing only its target field",
                "applications": [
                    {key: value for key, value in valid_application.items() if key != target_field}
                ],
            },
        )
        assert_schema_rejects(
            inputs,
            {
                "mode": "initialize",
                "context": "parameterized backend has an empty target field",
                "applications": [{**valid_application, target_field: ""}],
            },
        )

    assert_schema_rejects(
        inputs,
        {
            "mode": "initialize",
            "context": "frontend cannot carry a backend application type",
            "applications": [
                {
                    "id": "ai-huoke-web-admin",
                    "side": "frontend",
                    "application_type": "backend-monolith",
                }
            ],
        },
    )
    for application_type, wrong_role in (
        ("backend-monolith", "API 网关"),
        ("api-gateway", "单体后端"),
    ):
        assert_schema_rejects(
            inputs,
            {
                "mode": "initialize",
                "context": "backend type and role must agree",
                "applications": [
                    {
                        "id": "ai-huoke-api",
                        "side": "backend",
                        "application_type": application_type,
                        "role": wrong_role,
                    }
                ],
            },
        )
    for application_type in BACKEND_TYPE_CONTRACT:
        parameter_fields = {
            "backend-application": {"responsibility": "component"},
            "bff": {"terminal": "web"},
        }.get(application_type, {})
        assert_schema_rejects(
            inputs,
            {
                "mode": "initialize",
                "context": "every backend type must use its canonical role",
                "applications": [
                    {
                        "id": "ai-huoke-component",
                        "side": "backend",
                        "application_type": application_type,
                        "role": "错误职责",
                        **parameter_fields,
                    }
                ],
            },
        )

    application_plan = skill["output_schema"]["properties"]["application_plan"]["items"]
    assert application_plan["properties"]["application_type"]["enum"] == application_type_enum
    valid_backend_application_plan = {
        "id": "ai-huoke-api",
        "side": "backend",
        "name": "ai-huoke-api",
        "path": "development/backend/apps/ai-huoke-api",
        "application_type": "backend-monolith",
        "role": "单体后端",
        "existing": False,
        "specifications": [],
        "source": "guided-answer",
    }
    assert_schema_accepts(application_plan, valid_backend_application_plan)
    for missing_field in ("application_type", "role"):
        assert_schema_rejects(
            application_plan,
            {
                key: value
                for key, value in valid_backend_application_plan.items()
                if key != missing_field
            },
        )
    application_plan_properties = application_plan["properties"]
    assert application_plan_properties["responsibility"] == {
        "type": "string",
        "minLength": 1,
    }
    assert application_plan_properties["terminal"] == {
        "type": "string",
        "minLength": 1,
    }
    for application_type, role, name, parameter_fields in positive_backend_applications:
        assert_schema_accepts(
            application_plan,
            {
                "id": name,
                "side": "backend",
                "name": name,
                "path": f"development/backend/apps/{name}",
                "application_type": application_type,
                "role": role,
                **parameter_fields,
                "existing": True,
                "specifications": [],
                "source": "readonly-audit",
            },
        )
    data_sync_plan_base = {
        "id": "data-sync",
        "side": "backend",
        "name": "ai-huoke-importer",
        "path": "development/backend/apps/ai-huoke-importer",
        "application_type": "data-sync",
        "role": "数据同步",
        "existing": False,
        "specifications": [],
        "source": "guided-answer",
    }
    assert_schema_rejects(application_plan, data_sync_plan_base)
    for data_sync_name in ("ai-huoke-data-sync", "ai-huoke-data-sync-job"):
        assert_schema_accepts(
            application_plan,
            {
                **data_sync_plan_base,
                "name": data_sync_name,
                "path": f"development/backend/apps/{data_sync_name}",
            },
        )
    assert_schema_accepts(application_plan, {**data_sync_plan_base, "existing": True})
    for application_type, target_field, target_value, name in (
        ("backend-application", "responsibility", "orders", "ai-huoke-orders"),
        ("bff", "terminal", "web", "ai-huoke-web-bff"),
    ):
        valid_plan_item = {
            "id": name,
            "side": "backend",
            "name": name,
            "path": f"development/backend/apps/{name}",
            "application_type": application_type,
            "role": BACKEND_TYPE_CONTRACT[application_type]["role"],
            target_field: target_value,
            "existing": False,
            "specifications": [],
            "source": "guided-answer",
        }
        assert_schema_accepts(application_plan, valid_plan_item)
        assert_schema_rejects(
            application_plan,
            {key: value for key, value in valid_plan_item.items() if key != target_field},
        )
        assert_schema_rejects(
            application_plan,
            {**valid_plan_item, target_field: ""},
        )
    assert_schema_rejects(
        application_plan,
        {
            "id": "ai-huoke-web-admin",
            "side": "frontend",
            "name": "ai-huoke-web-admin",
            "path": "development/frontend/apps/ai-huoke-web-admin",
            "application_type": "backend-monolith",
            "existing": False,
            "source": "guided-answer",
        },
    )
    for application_type, wrong_role in (
        ("backend-monolith", "API 网关"),
        ("api-gateway", "单体后端"),
    ):
        assert_schema_rejects(
            application_plan,
            {
                "id": "ai-huoke-api",
                "side": "backend",
                "name": "ai-huoke-api",
                "path": "development/backend/apps/ai-huoke-api",
                "application_type": application_type,
                "role": wrong_role,
                "existing": False,
                "source": "guided-answer",
            },
        )
    for application_type in BACKEND_TYPE_CONTRACT:
        parameter_fields = {
            "backend-application": {"responsibility": "component"},
            "bff": {"terminal": "web"},
        }.get(application_type, {})
        assert_schema_rejects(
            application_plan,
            {
                "id": "ai-huoke-component",
                "side": "backend",
                "name": "ai-huoke-component",
                "path": "development/backend/apps/ai-huoke-component",
                "application_type": application_type,
                "role": "错误职责",
                **parameter_fields,
                "existing": False,
                "source": "guided-answer",
            },
        )

    numeric_rules = workflows["question_policy"]["rules"]
    numeric_runtime_rules = (
        "同一 guided_question 的 option number 必须唯一并按 1..N 连续。",
        "sequence 从 1 开始，并在同一任务的后续轮次严格递增。",
        "数字答复只映射最新且唯一未解决问题；无法唯一定位时返回 needs-input。",
    )
    for rule in numeric_runtime_rules:
        assert rule in numeric_rules, f"missing numeric runtime rule: {rule}"

    required = (
        "项目用途、目标用户和阶段不阻塞目录提案",
        "回复数字即可",
        "全部只创建目录",
        "暂不确认基础设施",
        "完整目录树",
        "数量统计不能替代完整目录树",
        "option number 必须唯一并按 1..N 连续",
        "后续轮次严格递增",
        "最新且唯一未解决问题",
        "调用模型执行",
        "完整 migration/creation map",
        "完整 planned file contents/commands",
        "具体 proposal_id",
        "proposal_actions 作为最后一段",
        "不得依赖 JSON/YAML object 的键顺序",
        "follow_ups 不得包含提案操作文案",
        "同时存在多个仍可识别的提案",
        "不得选择任一提案",
    )
    for phrase in required:
        assert phrase in skill["prompt"], f"missing organizer rule: {phrase}"
    assert (
        "用户主动提供的项目用途、目标用户和阶段作为可选背景保留；缺失时不得询问"
        in skill["prompt"]
    )
    assert "检查项目目标、用户、阶段、命名" not in skill["prompt"]

    semantic_contract = (
        "backend-monolith",
        "backend-application",
        "API Gateway",
        "BFF",
        "background-worker",
        "scheduled-job",
        "data-sync",
        "canonical role",
        "一般独立服务或微服务",
        "每轮最多 8 个相关选项",
        "禁止使用“单一后端 API”代表单体",
        "application_type=backend-monolith",
        "role=单体后端",
        "单体是部署和业务边界，不是语言",
        "scaffold_strategy=all-skip",
        "不得询问或推断 Go、Python、Node.js",
        "任何后端 application_type 都不得用于推断技术语言",
    )
    for source_name, source in (
        ("Skill", skill["prompt"]),
        ("adapter", adapter),
        ("README", readme),
    ):
        for phrase in semantic_contract:
            assert phrase in source, f"missing backend semantics in {source_name}: {phrase}"
        assert "单一后端 API" not in source.replace(
            "禁止使用“单一后端 API”代表单体", ""
        ), f"ambiguous backend label remains in {source_name}"

    assert "Go 单体后端" not in readme
    for source_name, source in (
        ("reference", WORKFLOWS_PATH.read_text(encoding="utf-8")),
        ("README", readme),
        ("Skill prompt", skill["prompt"]),
    ):
        for naming_form in (
            "<project-slug>-data-sync",
            "<project-slug>-data-sync-job",
            "ai-huoke-data-sync-job",
        ):
            assert naming_form in source, f"missing data-sync naming form in {source_name}: {naming_form}"
    assert "两种清晰形式" in readme

    print("zx-project-organizer directory-first v6 contract: ok")


if __name__ == "__main__":
    main()
