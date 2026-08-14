# ZX Project Organizer Guided Initialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `zx-project-organizer` to guide new-project initialization and existing-project reorganization, recommend but never auto-confirm choices, model independent frontend/backend applications, and optionally generate per-application runnable scaffolds.

**Architecture:** Keep the portable YAML Skill as the execution contract, move the detailed wizard and application naming rules into a versioned reference YAML, and preserve the proposal/apply hash gate. Contract tests and scenario fixtures define the behavior before the Skill, reference profile, Codex adapter, and README are updated.

**Tech Stack:** YAML, Markdown, Python 3 contract tests, PyYAML, POSIX shell validation.

## Global Constraints

- All application folders are lowercase and hyphen-separated.
- Frontend names use `<project-slug>-<terminal>`; `wx-mini` and `uniapp` are accepted terminal aliases.
- One backend application may use `<project-slug>` or `<project-slug>-api`; multiple applications use `<project-slug>-<responsibility>`.
- Do not create `services`, `packages`, `libs`, or `shared-code` application containers.
- Applications share no source code; API, RPC, and message specifications stay with the provider application.
- Recommendations remain proposed until explicitly accepted.
- Scaffold generation is decided per application and never overwrites an existing application.
- No write, move, Git initialization, or scaffold command runs before exact proposal confirmation.
- Preserve unrelated user-owned worktree changes.

---

### Task 1: Extend Organizer Contract Tests

**Files:**
- Modify: `tests/test-project-organizer-contract.py`
- Modify: `tests/fixtures/project-organizer-scenarios.yaml`

**Interfaces:**
- Consumes: current v4 organizer schemas and proposal/apply contract.
- Produces: executable assertions for v5 guided workflows, recommendation state, independent applications, scaffold selection, provider-owned specifications, and existing-project safety.

- [ ] **Step 1: Write failing contract assertions**

Add assertions for v5 input/output fields, a guided-workflow reference, `frontend/apps` and `backend/apps`, forbidden shared-code folders, per-app scaffolding, and new/existing scenarios.

- [ ] **Step 2: Run the contract test and verify failure**

Run: `python3 tests/test-project-organizer-contract.py`

Expected: FAIL because the organizer is still version `4.0.0` and the new fields/reference do not exist.

- [ ] **Step 3: Commit the failing-test contract when implementation follows in the same change series**

Stage only the two test files; do not include unrelated untracked Skill directories.

### Task 2: Add the Guided Workflow Reference and v5 Skill Contract

**Files:**
- Create: `skills-custom/06-project-manage/zx-project-organizer/references/guided-project-workflows.yaml`
- Modify: `skills-custom/06-project-manage/zx-project-organizer/skill.yaml`

**Interfaces:**
- Consumes: confirmed design in `docs/superpowers/specs/2026-08-14-project-organizer-guided-initialization-design.md`.
- Produces: `workflow_mode`, project/application facts, guided question output, recommendation register, application plan, scaffold plan, migration safety rules, and proposal-bound execution data.

- [ ] **Step 1: Define versioned wizard stages and naming policy**

Create a strict YAML reference covering mode detection, ordered new/existing stages, the question contract, terminal aliases, backend naming, provider-owned specifications, scaffold follow-ups, and forbidden folders.

- [ ] **Step 2: Update the Skill schema and prompt**

Bump the Skill to `5.0.0`; add structured inputs and outputs; require one question at a time; keep recommendations proposed; bind all new data to canonical proposal payloads; prohibit existing-app regeneration.

- [ ] **Step 3: Run the contract test**

Run: `python3 tests/test-project-organizer-contract.py`

Expected: remaining failures only for profile, adapter, README, or fixtures not yet updated.

### Task 3: Update the Full Delivery Application Containers

**Files:**
- Modify: `skills-custom/06-project-manage/zx-project-organizer/references/zx-full-delivery-structure.yaml`
- Modify: `tests/test-project-organizer-contract.py`

**Interfaces:**
- Consumes: v5 application plan.
- Produces: version `2.0.0` full-delivery base structure containing `development/frontend/apps` and `development/backend/apps`, plus narrowly allowed confirmed application extensions.

- [ ] **Step 1: Assert the new base directory set**

Change the expected profile count from 37 to 39 and require both `apps` paths while forbidding the four shared-code container names.

- [ ] **Step 2: Update the profile**

Add the two stable application containers and policy text that only confirmed application/specification paths may extend the exact base.

- [ ] **Step 3: Run the contract test**

Run: `python3 tests/test-project-organizer-contract.py`

Expected: PASS for the Skill/profile contract.

### Task 4: Update Codex Entry and Repository Guidance

**Files:**
- Modify: `adapters/codex/zx-skills/SKILL.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: v5 guided organizer commands and output states.
- Produces: discoverable natural-language usage for new-project initialization, existing-project reorganization, recommendation handling, and selective runnable scaffolds.

- [ ] **Step 1: Add failing documentation assertions**

Extend the contract test with exact phrases for new/existing mode, recommended options, application names, provider-owned specifications, and per-app scaffold confirmation.

- [ ] **Step 2: Update the Codex adapter**

Route requests such as “引导我创建一个全新项目” and “引导我整理现有项目”; preserve one-question-at-a-time and proposal confirmation rules.

- [ ] **Step 3: Update README examples**

Document the full conversation flow, directory examples, naming table, scaffold choice, existing-project migration gate, and prohibition on shared source folders.

- [ ] **Step 4: Run the contract test**

Run: `python3 tests/test-project-organizer-contract.py`

Expected: PASS.

### Task 5: Run Repository Validation

**Files:**
- Verify only; fix scoped failures in files from Tasks 1-4.

**Interfaces:**
- Consumes: completed v5 implementation.
- Produces: evidence that YAML, manifest discovery, namespace policy, dynamic categories, confirmation gates, documentation checks, and whitespace are valid.

- [ ] **Step 1: Run focused and repository tests**

Run the organizer contract, proposal ID, self-improve gate, dynamic categories, personal namespace, reminder tests, and scoped manifest validation.

- [ ] **Step 2: Parse every repository YAML file**

Use Python with `yaml.safe_load` over tracked and scoped new YAML files; report any invalid file without modifying unrelated work.

- [ ] **Step 3: Check diffs and worktree scope**

Run `git diff --check`, inspect `git diff --stat`, and confirm unrelated untracked Skill directories remain untouched and unstaged.

- [ ] **Step 4: Commit the implementation when explicitly requested**

Do not push automatically. Stage only organizer v5, its references/tests, the adapter, README, and the approved design/plan documents.
