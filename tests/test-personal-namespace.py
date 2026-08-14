#!/usr/bin/env python3

from pathlib import Path
import re
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]
CUSTOM_PATTERN = r"^zx-[a-z0-9]+-[a-z0-9]+(?:-[a-z0-9]+)?$"
CUSTOM_FORMAT = "zx-<category>-<function>"
CORE_CATEGORY_TOKENS = {
    "01-product": "product",
    "02-ui-design": "ui",
    "03-fullstack-arch-dev": "dev",
    "04-test-quality": "test",
    "05-ops-release": "ops",
    "06-project-manage": "project",
}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(relative_path: str):
    with (ROOT / relative_path).open(encoding="utf-8") as stream:
        return yaml.safe_load(stream)


manifest = load_yaml("skill-manifest.yaml")
validation = manifest["validation"]
if validation.get("custom_skill_id_pattern") != CUSTOM_PATTERN:
    fail("manifest does not enforce the concise custom Skill id grammar")
if validation.get("custom_skill_id_format") != CUSTOM_FORMAT:
    fail("manifest does not declare zx-<category>-<function> as the custom id format")
if validation.get("custom_skill_function_max_words") != 2:
    fail("manifest does not limit custom Skill functions to two words")
if "zx-" not in validation.get("external_forbidden_id_prefixes", []):
    fail("manifest does not reserve zx- against external adapter ids")
custom_id_regex = re.compile(CUSTOM_PATTERN)
for valid_id in ("zx-ui-spec", "zx-ui-page-check", "zx-project-organizer"):
    if not custom_id_regex.fullmatch(valid_id):
        fail(f"custom id grammar rejects valid concise id: {valid_id}")
for invalid_id in ("zx-ui", "ui-spec", "zx-ui-design-spec-extractor"):
    if custom_id_regex.fullmatch(invalid_id):
        fail(f"custom id grammar accepts invalid id: {invalid_id}")

category_tokens = {
    category["id"]: category.get("skill_token")
    for category in manifest["categories"]
}
for category_id, expected_token in CORE_CATEGORY_TOKENS.items():
    if category_tokens.get(category_id) != expected_token:
        fail(f"manifest category {category_id} does not use token {expected_token}")
tokens = [token for token in category_tokens.values() if token]
if len(tokens) != len(set(tokens)):
    fail("manifest category skill_token values are not unique")

creator = load_yaml("builtin/skill-creator.yaml")
creator_skill_id = creator["input_schema"]["properties"]["skill_id"]
if creator_skill_id.get("pattern") != CUSTOM_PATTERN:
    fail("skill-creator input does not require a zx- id")
if "custom_skill_id_pattern" not in creator["prompt"]:
    fail("skill-creator does not validate the manifest custom id rule")
if creator["version"].split(".", 1)[0] != "3":
    fail("skill-creator does not declare the breaking concise naming contract")
for phrase in (CUSTOM_FORMAT, "skill_token", "功能段优先使用一个通俗单词"):
    if phrase not in creator["prompt"]:
        fail(f"skill-creator is missing concise naming guidance: {phrase}")

self_improve = load_yaml("builtin/skill-selfimprove.yaml")
create_branch = self_improve["output_schema"]["oneOf"][1]
self_improve_skill_id = create_branch["properties"]["creator_parameters"]["properties"]["skill_id"]
if self_improve_skill_id.get("pattern") != CUSTOM_PATTERN:
    fail("skill-selfimprove does not return concise creator ids")
if CUSTOM_FORMAT not in self_improve["prompt"]:
    fail("skill-selfimprove does not propose the concise naming format")

editor = load_yaml("builtin/skill-editor.yaml")
if "custom_skill_id_pattern" not in editor["prompt"]:
    fail("skill-editor does not enforce zx- when forking to custom")
if CUSTOM_FORMAT not in editor["prompt"]:
    fail("skill-editor does not enforce the concise naming format")

external_import = load_yaml("builtin/skill-import-external.yaml")
if "external_forbidden_id_prefixes" not in external_import["prompt"]:
    fail("external import does not protect the reserved zx- prefix")
if "custom_skill_id_pattern" not in external_import["prompt"]:
    fail("customized import does not generate a zx- id")
if CUSTOM_FORMAT not in external_import["prompt"]:
    fail("customized import does not generate a concise custom id")

adapter = (ROOT / "adapters/codex/opc-skills/SKILL.md").read_text(encoding="utf-8")
if CUSTOM_FORMAT not in adapter:
    fail("Codex entrypoint does not auto-generate namespaced ids")

readme = (ROOT / "README.md").read_text(encoding="utf-8")
for expected in (
    "个人 Skill 命名空间",
    "zx-product-*",
    "zx-test-*",
    "zx-ui-spec",
    "zx-ui-check",
    CUSTOM_FORMAT,
    "skills-external` 的正式适配 ID 不得使用 `zx-`",
    "应执行一次显式迁移",
):
    if expected not in readme:
        fail(f"README is missing namespace guidance: {expected}")

for readme_path in sorted((ROOT / "skills-custom").glob("*/_readme.md")):
    content = readme_path.read_text(encoding="utf-8")
    category_id = readme_path.parent.name
    expected_token = category_tokens.get(category_id)
    expected_format = f"`zx-{expected_token}-<function>`"
    if expected_format not in content:
        fail(f"{readme_path.relative_to(ROOT)} does not document {expected_format}")

for readme_path in sorted((ROOT / "skills-external").glob("*/_readme.md")):
    content = readme_path.read_text(encoding="utf-8")
    if "不得占用 `zx-`" not in content:
        fail(f"{readme_path.relative_to(ROOT)} does not reserve the custom namespace")

for skill_path in sorted((ROOT / "skills-custom").glob("*/**/skill.y*ml")):
    skill = load_yaml(str(skill_path.relative_to(ROOT)))
    if not re.fullmatch(CUSTOM_PATTERN, skill["id"]):
        fail(f"custom Skill id is outside the zx- namespace: {skill_path.relative_to(ROOT)}")
    if skill_path.parent.name != skill["id"]:
        fail(f"custom Skill folder and id differ: {skill_path.relative_to(ROOT)}")
    expected_token = category_tokens.get(skill["category"])
    actual_token = skill["id"].split("-")[1]
    if expected_token != actual_token:
        fail(
            f"custom Skill category token mismatch: {skill_path.relative_to(ROOT)} "
            f"uses {actual_token}, expected {expected_token}"
        )

expected_ui_skills = {
    "zx-ui-spec": "ZX UI 规范整理",
    "zx-ui-check": "ZX UI 页面检查",
}
for skill_id, expected_name in expected_ui_skills.items():
    path = ROOT / "skills-custom" / "02-ui-design" / skill_id / "skill.yaml"
    if not path.is_file():
        fail(f"renamed UI Skill is missing: {path.relative_to(ROOT)}")
    skill = load_yaml(str(path.relative_to(ROOT)))
    if skill["id"] != skill_id or skill["name"] != expected_name:
        fail(f"renamed UI Skill metadata is incorrect: {path.relative_to(ROOT)}")

for old_path in (
    "skills-custom/02-ui-design/zx-ui-design-spec-extractor",
    "skills-custom/02-ui-design/zx-ui-implementation-conformance-audit",
):
    if (ROOT / old_path).exists():
        fail(f"old verbose UI Skill path still exists: {old_path}")

for skill_path in sorted((ROOT / "skills-external").glob("*/**/skill.y*ml")):
    skill = load_yaml(str(skill_path.relative_to(ROOT)))
    if skill["id"].startswith("zx-"):
        fail(f"external adapter id uses reserved zx- prefix: {skill_path.relative_to(ROOT)}")

print("ZXSkills personal namespace tests passed.")
