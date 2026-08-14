#!/usr/bin/env python3

from pathlib import Path
import re
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(relative_path: str):
    with (ROOT / relative_path).open(encoding="utf-8") as stream:
        return yaml.safe_load(stream)


manifest = load_yaml("skill-manifest.yaml")
extension = manifest.get("category_extension")
if not isinstance(extension, dict):
    fail("manifest does not define category_extension")

expected_extension = {
    "enabled": True,
    "reserved_core_numbers": ["01", "02", "03", "04", "05", "06"],
    "first_extension_number": 7,
    "max_category_number": 99,
    "number_policy": "next-unused",
    "slug_pattern": "^[a-z0-9]+(?:-[a-z0-9]+)*$",
    "id_pattern": "^(?:0[7-9]|[1-9][0-9])-[a-z0-9]+(?:-[a-z0-9]+)*$",
    "mirrored_roots": ["skills-custom", "skills-external"],
    "readme_template": "category-readme-template.md",
}
for key, expected in expected_extension.items():
    if extension.get(key) != expected:
        fail(f"category_extension.{key} is not {expected!r}")

required_proposal_fields = [
    "slug",
    "skill_token",
    "name",
    "scope",
    "includes",
    "excludes",
    "rationale",
]
if extension.get("required_proposal_fields") != required_proposal_fields:
    fail("category_extension.required_proposal_fields is incomplete")
if extension.get("skill_token_pattern") != "^[a-z0-9]+$":
    fail("dynamic category skill_token is not restricted to one lowercase word")

category_ids = [category["id"] for category in manifest["categories"]]
if len(category_ids) != len(set(category_ids)):
    fail("manifest category ids are not unique")
if category_ids[:6] != [
    "01-product",
    "02-ui-design",
    "03-fullstack-arch-dev",
    "04-test-quality",
    "05-ops-release",
    "06-project-manage",
]:
    fail("the six core categories changed order")

extension_id_pattern = re.compile(extension["id_pattern"])
if not extension_id_pattern.fullmatch("07-ai-data"):
    fail("extension id pattern rejects a valid 07+ category")
for invalid_id in ("06-ai-data", "7-ai-data", "07-AI-data"):
    if extension_id_pattern.fullmatch(invalid_id):
        fail(f"extension id pattern accepts invalid category id: {invalid_id}")

for category_id in category_ids:
    for root_name in extension["mirrored_roots"]:
        category_readme = ROOT / root_name / category_id / "_readme.md"
        if not category_readme.is_file():
            fail(f"registered category is missing mirrored readme: {category_readme.relative_to(ROOT)}")
        category_readme_text = category_readme.read_text(encoding="utf-8")
        if "Skill" not in category_readme_text:
            fail(f"category readme does not describe Skill scope: {category_readme.relative_to(ROOT)}")
        if re.search(r"\{\{[^}]+\}\}", category_readme_text):
            fail(f"category readme contains unresolved placeholders: {category_readme.relative_to(ROOT)}")

template_path = ROOT / extension["readme_template"]
if not template_path.is_file():
    fail("category readme template is missing")
template = template_path.read_text(encoding="utf-8")
for placeholder in (
    "{{origin_label}}",
    "{{category_id}}",
    "{{skill_token}}",
    "{{category_name}}",
    "{{scope}}",
    "{{includes}}",
    "{{excludes}}",
    "{{id_rule}}",
):
    if placeholder not in template:
        fail(f"category readme template is missing {placeholder}")

creator = load_yaml("builtin/skill-creator.yaml")
new_category = creator["input_schema"]["properties"].get("new_category")
if not isinstance(new_category, dict):
    fail("skill-creator does not accept new_category")
for field in required_proposal_fields:
    if field not in new_category["properties"] or field not in new_category["required"]:
        fail(f"skill-creator new_category is missing required field {field}")
for phrase in ("category_extension", "mirrored_roots", "category-readme-template.md", "回滚"):
    if phrase not in creator["prompt"]:
        fail(f"skill-creator does not implement category transaction rule: {phrase}")

self_improve = load_yaml("builtin/skill-selfimprove.yaml")
create_branch = self_improve["output_schema"]["oneOf"][1]
self_new_category = create_branch["properties"]["creator_parameters"]["properties"].get("new_category")
if not isinstance(self_new_category, dict):
    fail("skill-selfimprove cannot propose new_category")
if "不创建分类" not in self_improve["prompt"]:
    fail("skill-selfimprove does not preserve its read-only category boundary")

editor = load_yaml("builtin/skill-editor.yaml")
editor_new_category = editor["input_schema"]["properties"].get("new_category")
if not isinstance(editor_new_category, dict):
    fail("skill-editor does not accept new_category")
for field in required_proposal_fields:
    if field not in editor_new_category.get("properties", {}) or field not in editor_new_category.get("required", []):
        fail(f"skill-editor new_category is missing required field {field}")
if "category_extension" not in editor["prompt"] or "mirrored_roots" not in editor["prompt"]:
    fail("skill-editor fork-to-custom does not support dynamic categories")

external_import = load_yaml("builtin/skill-import-external.yaml")
external_new_category = external_import["input_schema"]["properties"].get("new_category")
if not isinstance(external_new_category, dict):
    fail("external import does not accept a confirmed new_category proposal")
category_assessment = external_import["output_schema"]["properties"].get("category_assessment")
if not isinstance(category_assessment, dict):
    fail("external import does not return a structured category_assessment")
assessment_properties = category_assessment.get("properties", {})
assessment_results = assessment_properties.get("result", {}).get("enum", [])
for result in ("matched-existing", "proposed-new"):
    if result not in assessment_results:
        fail(f"external category_assessment cannot report {result}")
assessment_new_category = assessment_properties.get("new_category")
if not isinstance(assessment_new_category, dict):
    fail("external category_assessment does not expose new_category")
for field in required_proposal_fields:
    if field not in assessment_new_category.get("properties", {}) or field not in assessment_new_category.get("required", []):
        fail(f"external category_assessment new_category is missing field {field}")
for phrase in ("stage 阶段不得创建分类", "category_extension", "mirrored_roots", "回滚"):
    if phrase not in external_import["prompt"]:
        fail(f"external import does not enforce category lifecycle: {phrase}")
if "category_assessment" not in external_import["prompt"]:
    fail("external import prompt does not require structured category output")

adapter = (ROOT / "adapters/codex/zx-skills/SKILL.md").read_text(encoding="utf-8")
if "动态分类" not in adapter or "07-" not in adapter:
    fail("Codex entrypoint does not route dynamic categories")

readme = (ROOT / "README.md").read_text(encoding="utf-8")
for expected in (
    "扩展业务分类",
    "07-ai-data",
    "next-unused",
    "分类创建失败",
    "skills-custom/07-ai-data/_readme.md",
    "skills-external/07-ai-data/_readme.md",
):
    if expected not in readme:
        fail(f"README is missing dynamic category guidance: {expected}")

print("ZXSkills dynamic category tests passed.")
