#!/usr/bin/env python3

from pathlib import Path
import re
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]
CUSTOM_PATTERN = r"^zx-[a-z0-9]+(?:-[a-z0-9]+)*$"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(relative_path: str):
    with (ROOT / relative_path).open(encoding="utf-8") as stream:
        return yaml.safe_load(stream)


manifest = load_yaml("skill-manifest.yaml")
validation = manifest["validation"]
if validation.get("custom_skill_id_pattern") != CUSTOM_PATTERN:
    fail("manifest does not require the zx- namespace for custom Skill ids")
if "zx-" not in validation.get("external_forbidden_id_prefixes", []):
    fail("manifest does not reserve zx- against external adapter ids")

creator = load_yaml("builtin/skill-creator.yaml")
creator_skill_id = creator["input_schema"]["properties"]["skill_id"]
if creator_skill_id.get("pattern") != CUSTOM_PATTERN:
    fail("skill-creator input does not require a zx- id")
if "custom_skill_id_pattern" not in creator["prompt"]:
    fail("skill-creator does not validate the manifest custom id rule")
if creator["version"].split(".", 1)[0] != "2":
    fail("skill-creator does not declare the breaking namespace contract")

self_improve = load_yaml("builtin/skill-selfimprove.yaml")
create_branch = self_improve["output_schema"]["oneOf"][1]
self_improve_skill_id = create_branch["properties"]["creator_parameters"]["properties"]["skill_id"]
if self_improve_skill_id.get("pattern") != CUSTOM_PATTERN:
    fail("skill-selfimprove does not return zx- creator parameters")

editor = load_yaml("builtin/skill-editor.yaml")
if "custom_skill_id_pattern" not in editor["prompt"]:
    fail("skill-editor does not enforce zx- when forking to custom")

external_import = load_yaml("builtin/skill-import-external.yaml")
if "external_forbidden_id_prefixes" not in external_import["prompt"]:
    fail("external import does not protect the reserved zx- prefix")
if "custom_skill_id_pattern" not in external_import["prompt"]:
    fail("customized import does not generate a zx- id")

adapter = (ROOT / "adapters/codex/zx-skills/SKILL.md").read_text(encoding="utf-8")
if "zx-<domain>-<capability>" not in adapter:
    fail("Codex entrypoint does not auto-generate namespaced ids")

readme = (ROOT / "README.md").read_text(encoding="utf-8")
for expected in (
    "个人 Skill 命名空间",
    "zx-product-*",
    "zx-testing-*",
    "skills-external` 的正式适配 ID 不得使用 `zx-`",
    "应执行一次显式迁移",
):
    if expected not in readme:
        fail(f"README is missing namespace guidance: {expected}")

for readme_path in sorted((ROOT / "skills-custom").glob("*/_readme.md")):
    content = readme_path.read_text(encoding="utf-8")
    if "`zx-`" not in content:
        fail(f"{readme_path.relative_to(ROOT)} does not mention the custom namespace")

for readme_path in sorted((ROOT / "skills-external").glob("*/_readme.md")):
    content = readme_path.read_text(encoding="utf-8")
    if "不得占用 `zx-`" not in content:
        fail(f"{readme_path.relative_to(ROOT)} does not reserve the custom namespace")

for skill_path in sorted((ROOT / "skills-custom").glob("*/**/skill.y*ml")):
    skill = load_yaml(str(skill_path.relative_to(ROOT)))
    if not re.fullmatch(CUSTOM_PATTERN, skill["id"]):
        fail(f"custom Skill id is outside the zx- namespace: {skill_path.relative_to(ROOT)}")

for skill_path in sorted((ROOT / "skills-external").glob("*/**/skill.y*ml")):
    skill = load_yaml(str(skill_path.relative_to(ROOT)))
    if skill["id"].startswith("zx-"):
        fail(f"external adapter id uses reserved zx- prefix: {skill_path.relative_to(ROOT)}")

print("ZXSkills personal namespace tests passed.")
