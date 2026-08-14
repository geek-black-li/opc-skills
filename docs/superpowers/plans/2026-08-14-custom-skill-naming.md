# Custom Skill Naming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce concise, readable custom Skill IDs in the form `zx-<category>-<function>` and rename the two pending UI Skills to `zx-ui-spec` and `zx-ui-check`.

**Architecture:** Store category tokens and the ID grammar in `skill-manifest.yaml` as the single naming authority. Make every custom-Skill producer validate the same contract, then verify it with repository tests that scan actual custom Skills and cross-check category tokens.

**Tech Stack:** Portable YAML Skill contracts, Markdown guidance, Python 3/PyYAML contract tests.

## Global Constraints

- `zx-` is the fixed prefix for all custom Skills.
- The category segment is a short manifest-owned token: `product`, `ui`, `dev`, `test`, `ops`, or `project` for the six core categories.
- The function segment uses one common word when possible and at most two lowercase hyphen-separated words.
- Folder name and YAML `id` must be identical.
- Builtin and original external Skill IDs do not use this custom naming rule.
- Preserve unrelated user changes and do not commit or push unless explicitly requested.

---

### Task 1: Add Failing Naming Contract Tests

**Files:**
- Modify: `tests/test-personal-namespace.py`
- Modify: `tests/test-dynamic-categories.py`

**Interfaces:**
- Consumes: current namespace and dynamic-category contracts.
- Produces: assertions for category tokens, concise function segments, producer consistency, folder/ID equality, and the two UI Skill names.

- [x] Add assertions for the new manifest grammar and six core token mappings.
- [x] Assert creator, Self-Improve, editor, external import, adapter, template, and README reference `zx-<category>-<function>`.
- [x] Assert dynamic categories require a one-word `skill_token`.
- [x] Assert `zx-ui-spec` and `zx-ui-check` exist and old long paths do not.
- [x] Run both tests and verify they fail because the new contract is absent.

### Task 2: Implement the Central Naming Contract

**Files:**
- Modify: `skill-manifest.yaml`
- Modify: `builtin/skill-creator.yaml`
- Modify: `builtin/skill-selfimprove.yaml`
- Modify: `builtin/skill-editor.yaml`
- Modify: `builtin/skill-import-external.yaml`
- Modify: `adapters/codex/zx-skills/SKILL.md`
- Modify: `skill-template.yaml`

**Interfaces:**
- Consumes: the failing tests from Task 1.
- Produces: one shared naming grammar and matching custom-Skill creation/fork/import proposal behavior.

- [x] Add unique `skill_token` values to manifest categories and require the token for extensions.
- [x] Change the custom ID pattern to require category plus one- or two-word function.
- [x] Make creator validate that the ID category token matches the chosen category and recommend a concise ID when input is invalid.
- [x] Apply the same rule to Self-Improve proposals, editor forks, external custom adaptations, and the Codex entrypoint.
- [x] Update the template comment and examples.
- [x] Run namespace and dynamic-category tests until both pass.

### Task 3: Rename the Pending UI Skills

**Files:**
- Rename: `skills-custom/02-ui-design/zx-ui-design-spec-extractor/` to `skills-custom/02-ui-design/zx-ui-spec/`
- Rename: `skills-custom/02-ui-design/zx-ui-implementation-conformance-audit/` to `skills-custom/02-ui-design/zx-ui-check/`
- Modify: both renamed `skill.yaml` files.

**Interfaces:**
- Consumes: category token `ui` and functions `spec`/`check`.
- Produces: readable folder names, IDs, Chinese names, trigger keywords, and prompts without stale long identifiers.

- [x] Rename both directories without touching their workflow behavior.
- [x] Update IDs to `zx-ui-spec` and `zx-ui-check`.
- [x] Update display names to `ZX UI 规范整理` and `ZX UI 页面检查`.
- [x] Remove stale old IDs and overly technical names from triggers and prompts.
- [x] Parse both YAML files and run the naming tests.

### Task 4: Update User Guidance and Verify

**Files:**
- Modify: `README.md`
- Verify: all repository tests and scoped YAML files.

**Interfaces:**
- Consumes: completed naming contract and renamed Skills.
- Produces: user-facing naming table, examples, migration guidance, and verification evidence.

- [x] Replace `domain/capability` guidance with fixed `category/function` terminology and the six core mappings.
- [x] Document common short function examples such as `spec`, `check`, `plan`, `review`, `test`, and `deploy`.
- [x] Run namespace, dynamic category, organizer, Self-Improve, proposal ID, reminder, YAML parse, and `git diff --check` validations.
- [x] Confirm no old UI Skill path or ID remains and no unrelated file is staged.
