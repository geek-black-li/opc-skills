# Project Organizer Directory-First Questions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `zx-project-organizer`'s product-discovery-heavy initialization wizard with a directory-first, numeric, conditional question flow that always displays the complete proposed tree before confirmation.

**Architecture:** Keep the existing proposal hash and apply safety gate. Make `guided-project-workflows.yaml` the single authority for question relevance, order, numeric selection, batch application/scaffold decisions, and final rendering; mirror its schema in `skill.yaml`, route natural numeric replies in the Codex adapter, and lock the behavior with a focused contract test plus scenario fixtures.

**Tech Stack:** Portable YAML Skill contracts, Markdown adapter/documentation, Python 3 with PyYAML contract tests.

## Global Constraints

- Project purpose, target users, and stage are optional background and never block a directory proposal.
- Confirm project location and identity before structure, applications, scaffolding, infrastructure, or Git.
- Questions have increasing numeric sequence values; options have numeric aliases and support numeric single/multiple selection.
- Numeric input applies only to the latest unresolved question or currently displayed proposal.
- Application discovery is consolidated; scaffold policy is batch-first and drills down only for generated applications.
- Infrastructure recommendation is `暂不确认基础设施`; no infrastructure path or config is inferred from MVP, AI, purpose, or target users.
- Every `awaiting-confirmation` or `migration-proposed` user-facing response displays the complete unabridged `proposed_structure` before confirmation actions.
- Existing custom-structure exactness, proposal hashing, apply confirmation, Git opt-in, provider-owned specifications, and existing-application protection remain unchanged.
- Preserve unrelated user changes. Do not commit or push until the user explicitly requests it.

## 后续人工裁决注记

- **人工裁决 1**：原始 `stage_ids[:5]` 断言已被取代。接受的条件顺序是前四项固定为
  `project-location`、`structure-profile`、`applications`、`scaffold-strategy`；
  `scaffold-details` 仅在 `any-scaffold-generate` 时出现，并紧随 `scaffold-strategy`，`infrastructure` 位于其后。
- **人工裁决 2**：继续显式区分 monolith、API Gateway、BFF，同时把后端稳定 taxonomy 扩展为
  `backend-monolith`、`backend-application`、`api-gateway`、`bff`、`background-worker`、
  `scheduled-job`、`data-sync`。每类必须声明唯一 canonical role 与路径语义；`backend-application`
  覆盖一般独立服务或微服务，避免把专用类型当作架构穷举。应用问题最多 8 个选项，按上下文选相关项，
  技术栈未知或 `all-skip` 时不推断语言。
- **第二轮修正**：用户可见的可执行提案必须严格按“完整树 → 完整 migration/creation map →
  完整 planned file contents/commands → risks + validation → 具体 proposal_id → 最后的 proposal_actions”渲染，
  不依赖 JSON/YAML object 键顺序。`follow_ups` 不得承载提案动作。多个仍可识别提案下的纯数字 `1`
  必须拒绝选择并保持零写入。

---

### Task 1: Add Failing Directory-First Contract Tests

**Files:**
- Create: `tests/test-project-organizer-directory-first.py`
- Modify: `tests/fixtures/project-organizer-scenarios.yaml`

**Interfaces:**
- Consumes: current `skill.yaml`, `guided-project-workflows.yaml`, Codex adapter, and scenario fixtures.
- Produces: RED assertions for Skill version 6, numeric schemas, directory-first stage order, batch scaffolding, deferred infrastructure, full-tree rendering, and numeric proposal actions.

- [ ] **Step 1: Extend scenario fixtures with observed and desired behavior**

Add these scenario IDs and exact expectations:

```yaml
  - id: directory-first-new-project
    description: "只要求创建工作目录时，先确认目标位置与标识，不询问用途、用户或阶段。"
    workflow_mode: new-project
    expected_next_question: project-location
    forbidden_blocking_questions:
      - project-purpose
      - target-users
      - project-stage
    expected_changes: []

  - id: numeric-question-selection
    description: "用户可以只回复当前问题的数字选项。"
    expected_sequence: 1
    expected_selection_mode: single
    expected_answer_hint: "回复数字即可，例如：1"

  - id: batch-skip-scaffolds
    description: "全部应用只建目录时，只需一次批量决定。"
    scaffold_strategy: all-skip
    expected_question_count: 1
    expected_generate: false
    expected_status: skipped

  - id: deferred-infrastructure-default
    description: "未知基础设施不会阻塞目录提案，也不会生成推测性配置。"
    expected_recommended_option: defer-infrastructure
    forbidden_components:
      - database
      - cache
      - message-queue
      - scheduled-jobs

  - id: complete-tree-before-confirmation
    description: "最终确认前必须展示完整目录树，数量摘要不能替代结构。"
    expected_result: awaiting-confirmation
    require_complete_proposed_structure: true
    forbidden_rendering:
      - "其余目录同模板"
      - "..."
```

- [ ] **Step 2: Create the focused contract test**

The new Python test must assert:

```python
assert skill["version"] == "6.0.0"
assert "project_root" not in skill["input_schema"]["required"]

update = skill["input_schema"]["properties"]["recommendation_updates"]["items"]
assert update["properties"]["selected_option_numbers"]["items"]["type"] == "integer"

question = skill["output_schema"]["properties"]["guided_question"]["oneOf"][0]
assert {"sequence", "selection_mode", "answer_hint"}.issubset(question["required"])
assert question["properties"]["sequence"]["type"] == "integer"
assert question["properties"]["selection_mode"]["enum"] == ["single", "multiple"]

option = question["properties"]["options"]["items"]
assert "number" in option["required"]
assert option["properties"]["number"]["type"] == "integer"

stages = workflows["new_project_stages"]
stage_ids = [stage["id"] for stage in stages]
assert stage_ids[:4] == [
    "project-location",
    "structure-profile",
    "applications",
    "scaffold-strategy",
]
assert stages[4]["id"] == "scaffold-details"
assert stages[4]["condition"] == "any-scaffold-generate"
assert stages[5]["id"] == "infrastructure"
assert not {"project-purpose", "target-users", "project-stage"} & set(stage_ids)

assert workflows["scaffolding"]["decision_scope"] == "batch-first"
assert workflows["scaffolding"]["default_recommendation"] == "all-skip"
assert workflows["infrastructure"]["default_recommendation"] == "defer-infrastructure"
assert workflows["rendering"]["complete_tree_required"] is True
```

Also assert the main Skill prompt and adapter contain these exact phrases:

```python
required = (
    "项目用途、目标用户和阶段不阻塞目录提案",
    "回复数字即可",
    "全部只创建目录",
    "暂不确认基础设施",
    "完整目录树",
    "数量统计不能替代完整目录树",
)
```

- [ ] **Step 3: Run RED tests and confirm the expected failures**

Run:

```bash
python3 tests/test-project-organizer-directory-first.py
python3 tests/test-project-organizer-contract.py
```

Expected: the new test fails because version 6, numeric fields, `project-location`, batch scaffolding, deferred infrastructure, and rendering rules do not yet exist. The existing test still passes before production changes.

---

### Task 2: Implement the Directory-First Workflow Contract

**Files:**
- Modify: `skills-custom/06-project-manage/zx-project-organizer/references/guided-project-workflows.yaml`
- Modify: `skills-custom/06-project-manage/zx-project-organizer/skill.yaml`
- Modify: `tests/test-project-organizer-contract.py`

**Interfaces:**
- Consumes: RED assertions from Task 1 and the existing `zpo-*` proposal/apply contract.
- Produces: Skill version `6.0.0`, numeric guided questions, directory-first stage routing, batch scaffold policy, deferred infrastructure recommendation, and mandatory complete-tree rendering.

- [ ] **Step 1: Upgrade the reference workflow**

Set `guided-project-workflows.yaml` to version `2.0.0` and add:

```yaml
question_policy:
  numeric_selection: true
  sequence_starts_at: 1
  single_option_count:
    minimum: 2
    maximum: 4
  multi_option_count:
    minimum: 2
    maximum: 8
  numeric_reply_scope: latest-unresolved-question
  required_fields:
    - id
    - sequence
    - question
    - why_asked
    - selection_mode
    - recommended_option_id
    - recommendation_reason
    - options
    - answer_hint
    - custom_allowed
  option_required_fields:
    - id
    - number
    - label
    - impact
```

Replace `new_project_stages` with the directory-first order:

```yaml
new_project_stages:
  - id: project-location
    collects: [project_root, display_name, project_slug]
    question: "项目目录位置、名称和英文标识使用哪组？"
  - id: structure-profile
    collects: [structure_profile]
    question: "项目采用 ZX 完整交付、自适应还是自定义结构？"
  - id: applications
    collects: [applications]
    selection_mode: multiple
    question: "本次创建哪些前端和后端应用目录？"
  - id: scaffold-strategy
    condition: applications-confirmed
    collects: [scaffold_strategy, scaffold_application_ids]
    question: "这些应用如何处理代码骨架？"
  - id: scaffold-details
    condition: any-scaffold-generate
    collects: [scaffold_details]
    question: "请确认选择生成的应用所需技术栈和运行命令。"
  - id: infrastructure
    collects: [infrastructure-decision]
    question: "本次是否创建已确认的基础设施配置？"
    recommended_option_id: defer-infrastructure
  - id: initialize-git
    collects: [initialize_git]
    question: "是否把 Git 初始化纳入本次提案？"
```

Add explicit optional-background, scaffolding, infrastructure, and rendering contracts:

```yaml
optional_background:
  non_blocking_fields: [purpose, target_users, stage]
  missing_policy: omit-or-record-unknown
  inference_forbidden: true

scaffolding:
  decision_scope: batch-first
  default_recommendation: all-skip
  strategies: [all-skip, all-generate, selective]
  selective_follow_up: numeric-application-multiselect

infrastructure:
  default_recommendation: defer-infrastructure
  infer_from_project_stage: false
  infer_from_project_purpose: false
  deferred_creates_nothing: true

rendering:
  complete_tree_required: true
  results: [awaiting-confirmation, migration-proposed]
  tree_source: proposed_structure
  tree_code_fence: text
  abridgement_forbidden: true
  numeric_proposal_actions:
    1: confirm-current-proposal
    2: revise-current-proposal
    3: abandon-current-proposal
```

- [ ] **Step 2: Upgrade the main Skill input/output schema**

In `skill.yaml`:

- bump `version` from `5.0.0` to `6.0.0`;
- remove `project_root` from top-level `required` during propose, but require it in prompt before any executable proposal or apply;
- add `scaffold_strategy` with enum `all-skip`, `all-generate`, `selective`;
- add `scaffold_application_ids` as an array of application IDs;
- add `selected_option_numbers` to `recommendation_updates` as a unique integer array with minimum `1`;
- add `sequence`, `selection_mode`, and `answer_hint` to `guided_question` required fields;
- add integer `number` to option required fields;
- allow guided option arrays up to 8 only when `selection_mode=multiple`, while single-choice questions remain at most 4.

Use JSON Schema `if/then` rules so `scaffold_strategy=selective` requires `scaffold_application_ids`, and `selection_mode=multiple` allows `maxItems: 8`.

- [ ] **Step 3: Replace the linear prompt rules with relevance-driven rules**

Remove or replace prompt sentences that require:

```text
new-project 依次完善项目用途、目标用户、阶段...
每次只询问一个应用的代码骨架决定...
逐应用确认是否生成可运行代码骨架...
```

Add exact positive contracts:

```text
项目用途、目标用户和阶段不阻塞目录提案；用户未主动提供时不得询问或猜测。
问题顺序从项目位置与标识开始，只询问会改变路径、文件、代码生成、基础设施配置或 Git 状态的决定。
每个 guided_question 显示“问题 <sequence>”，每个选项显示 number；单选可回复一个数字，多选可回复逗号分隔数字。
数字只映射当前任务中最新未解决问题；无法唯一定位时返回 needs-input。
应用目录一次收集前端和后端清单，不拆成前端存在性、前端列表、后端存在性和后端列表四个固定问题。
代码骨架先询问批量策略；全部只创建目录时一次把所有新应用记为 generate=false、status=skipped。
基础设施推荐暂不确认基础设施；不得根据 MVP、AI、用途或目标用户推荐数据库、缓存、消息队列或定时任务。
awaiting-confirmation 或 migration-proposed 的用户答复必须直接展示 proposed_structure 的完整目录树；数量统计不能替代完整目录树。
```

Preserve the existing per-application safety rule only for applications selected for generation and preserve `existing_application_policy=never-regenerate`.

- [ ] **Step 4: Update the legacy organizer contract assertions**

Change the expected Skill/reference versions to `6.0.0`/`2.0.0`; replace legacy prompt assertions for purpose-first and one-application-at-a-time behavior with the new directory-first phrases. Keep all proposal hash, full-profile, custom tree, Git, provider-owned specification, and existing-application assertions unchanged.

- [ ] **Step 5: Run GREEN contract tests**

Run:

```bash
python3 tests/test-project-organizer-directory-first.py
python3 tests/test-project-organizer-contract.py
python3 tests/test-proposal-id.py
```

Expected: all pass.

---

### Task 3: Route Numeric Replies and Update User Guidance

**Files:**
- Modify: `adapters/codex/zx-skills/SKILL.md`
- Modify: `README.md`
- Test: `tests/test-project-organizer-directory-first.py`

**Interfaces:**
- Consumes: numeric question and rendering contracts from Task 2.
- Produces: natural-language routing for `1`, `1,3,5`, and final proposal actions without weakening `proposal_id` confirmation.

- [ ] **Step 1: Add adapter numeric routing**

Document these rules in the Codex adapter:

```text
- 用户只回复数字时，只映射当前任务中最新且唯一的 guided_question。
- 单选数字转换为 selected_option_numbers=[n]；多选逗号数字转换为有序去重数组。
- 数字不存在、问题已经解决、上下文缺失或存在多个未解决问题时返回 needs-input，不猜测。
- 最终提案已经完整展示时，1=确认当前 proposal_id，2=返回修改，3=放弃；内部仍按原 proposal payload 构造 apply 参数。
- 没有可唯一定位的 proposal_id 或哈希不匹配时，数字 1 不构成执行授权。
```

Replace adapter text that says “逐应用确认代码骨架” with batch-first handling and require full-tree rendering before the final actions.

- [ ] **Step 2: Rewrite the README workflow and example**

Update the new-project guide to show:

```text
问题 1：项目目录位置、名称和英文标识使用哪组？
1. 使用推荐位置和标识（推荐）
2. 使用当前目录
3. 自定义
回复数字即可，例如：1
```

Document the six directory-first decision categories, optional/conditional questions, batch scaffold options, deferred infrastructure recommendation, and complete-tree confirmation format. Remove statements that purpose/users/stage and per-application skip decisions are mandatory.

- [ ] **Step 3: Extend adapter/document assertions**

In `tests/test-project-organizer-directory-first.py`, assert the adapter and README both contain:

```python
for phrase in (
    "回复数字即可",
    "1=确认当前",
    "暂不确认基础设施",
    "完整目录树",
    "全部只创建目录",
):
    assert phrase in adapter
    assert phrase in readme
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
python3 tests/test-project-organizer-directory-first.py
python3 tests/test-project-organizer-contract.py
```

Expected: both pass.

---

### Task 4: Verify Regression Safety and Forward Behavior

**Files:**
- Verify: all modified files
- Verify: `tests/test-*.py`, `tests/test-*.sh`, `tests/test-configure-codex-reminder.ps1`

**Interfaces:**
- Consumes: completed directory-first Skill and actual baseline failure from thread `019ffe40-d3bf-76c2-b96e-2badc88040a0`.
- Produces: repository-wide test evidence and one fresh-context forward-test report.

- [ ] **Step 1: Run the full repository test suite**

Run:

```bash
set -euo pipefail
for test_file in tests/test-*.py; do python3 "$test_file"; done
for test_file in tests/test-*.sh; do bash "$test_file"; done
pwsh -NoProfile -File tests/test-configure-codex-reminder.ps1
```

Expected: all tests pass.

- [ ] **Step 2: Parse every YAML file and check whitespace**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import yaml
paths = [p for p in Path('.').rglob('*.yaml') if '.git' not in p.parts]
for path in paths:
    yaml.safe_load(path.read_text(encoding='utf-8'))
print(f'YAML parse: {len(paths)} files passed')
PY
git diff --check
```

Expected: YAML parse succeeds and `git diff --check` prints no errors.

- [ ] **Step 3: Forward-test in a fresh context**

Give a fresh agent only the revised Skill path and this user request:

```text
使用 zx-project-organizer 帮我创建一个 AI 获客项目工作目录。我现在只知道项目名称，不确定业务定位、目标用户、技术栈和基础设施。
```

The first response must ask numbered `project-location`, recommend a safe location/slug combination, accept a numeric reply, and must not ask purpose, target users, or stage. Continue with numeric selections for full delivery, a Web admin plus monolith backend, all-skip scaffolding, deferred infrastructure, and no Git. The final response must display the complete unabridged tree before numeric proposal actions and must perform no writes.

- [ ] **Step 4: Review final diff and hand off**

Run:

```bash
git status --short
git diff --stat
git diff --check
```

Confirm only the approved spec, implementation plan, organizer Skill/reference, adapter, README, fixtures, and tests changed. Report that commit/push remains pending unless explicitly requested.
