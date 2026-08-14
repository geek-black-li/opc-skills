# OPCSkills Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将项目品牌迁移为 `OPCSkills`，提供 `$opc-skills` 主入口与 `$zx-skills` 兼容入口，建立 GitHub Public 主仓库，并把本地目录安全改名为 `OPCSkills`。

**Architecture:** `adapters/codex/opc-skills` 是唯一完整路由实现，`adapters/codex/zx-skills` 只做旧名转交；POSIX 与 PowerShell 安装器对两个受管入口执行同样的预检、安装、状态和卸载契约。仓库内迁移先完成并通过回归，再创建 GitHub 仓库、切换双远程，最后改本地目录并重装入口。

**Tech Stack:** Markdown，通用 YAML，Bash，PowerShell，Python 3 + PyYAML，Git，GitHub CLI 2.97.0。

## Global Constraints

- 项目品牌固定为 `OPCSkills`；GitHub 仓库固定为 Public `geek-black-li/opc-skills`。
- 主入口固定为 `$opc-skills`；`$zx-skills` 作为兼容入口保留，不复制主路由 Prompt。
- 个人 Skill ID 继续使用 `zx-<category>-<function>`；`zxsi-*`、`zpo-*` 和哈希算法不变。
- 提醒片段管理标记继续使用 `zx-skills-reminder`，但标题、提示命令和状态文案改为 OPCSkills / `$opc-skills`。
- `skills-temp-inbox` 始终被 Manifest 排除；第三方 Skill 仍须先隔离、再评估、后确认。
- GitHub 为 `origin`，Gitee `https://gitee.com/geek_black_li/zx-skills.git` 改名为 `gitee`；本次做一次迁移前备份推送，之后不自动同步。
- GitHub 命令仅在进程环境中设置 `HTTPS_PROXY=http://127.0.0.1:7890` 和 `HTTP_PROXY=http://127.0.0.1:7890`；不将代理或凭据写入仓库。
- 本地改名目标固定为 `/Users/black_li/Desktop/01 工作/其他/产品/OPCSkills`；目标已存在时立即停止，不合并、不覆盖。
- 保留任务范围外的用户文件；不改写 Git 历史，不删除 Gitee 仓库，不改名业务 Skill。

---

## File Map

| File | Responsibility |
| --- | --- |
| `tests/test-opc-branding.py` | 锁定 OPCSkills 品牌、主/兼容入口和稳定 `zx-*` 协议边界 |
| `adapters/codex/opc-skills/SKILL.md` | 承载唯一完整的 Codex 意图路由和安全门禁 |
| `adapters/codex/opc-skills/agents/openai.yaml` | 展示 OPCSkills 主入口名称、简介和默认 Prompt |
| `adapters/codex/zx-skills/SKILL.md` | 声明旧入口并转交主适配器，不复制路由逻辑 |
| `adapters/codex/zx-skills/agents/openai.yaml` | 展示兼容入口和迁移提示 |
| `tests/test-install-codex.sh` | 验证 POSIX 双入口的新装、旧版升级、状态、冲突保护和卸载 |
| `tests/test-install-codex.ps1` | 验证 PowerShell 安装器与 POSIX 安装器同契约 |
| `scripts/install-codex.sh` | 在用户 Skill 目录管理 `opc-skills` 和 `zx-skills` 两个链接 |
| `scripts/install-codex.ps1` | Windows/macOS PowerShell 双入口安装、检查与卸载 |
| `skill-manifest.yaml` | 声明 `opc-skills` 仓库标识，保持发现和 ID 协议不变 |
| `builtin/*.yaml` | 把仓库名、作者与主调用命令迁移为 OPCSkills |
| `skills-custom/02-ui-design/*/skill.yaml` | 更新属于仓库品牌的作者/说明，保留 `zx-ui-*` ID |
| `templates/codex-agents-reminder.md` | 保留旧管理标记，使用 OPCSkills 标题和 `$opc-skills` 提醒 |
| `scripts/configure-codex-reminder.*` | 保留旧标记识别/卸载能力，更新用户文案 |
| `tests/test-configure-codex-reminder.*` | 验证旧标记不变且新提醒命令生效 |
| `README.md` | 作为 GitHub 主入口的安装、使用、兼容、双远程和风险说明 |
| `tests/test-*.py` | 将只读主适配器的断言路径改到 `opc-skills`，保留兼容入口专项断言 |

### Task 1: Lock the Brand and Compatibility Contract

**Files:**
- Create: `tests/test-opc-branding.py`

**Interfaces:**
- Consumes: 已确认设计中的品牌边界、入口边界和稳定协议列表。
- Produces: 后续所有任务共用的静态契约测试 `python3 tests/test-opc-branding.py`。

- [ ] **Step 1: Write the failing brand-boundary test**

  创建测试，实际解析 YAML 并断言：

  ```python
  #!/usr/bin/env python3
  from pathlib import Path
  import re
  import yaml

  ROOT = Path(__file__).resolve().parents[1]

  def read(path: str) -> str:
      return (ROOT / path).read_text(encoding="utf-8")

  manifest = yaml.safe_load(read("skill-manifest.yaml"))
  assert manifest["repository"]["id"] == "opc-skills"
  assert manifest["repository"]["name"] == "OPCSkills"

  primary = read("adapters/codex/opc-skills/SKILL.md")
  compat = read("adapters/codex/zx-skills/SKILL.md")
  assert re.search(r"^name: opc-skills$", primary, re.MULTILINE)
  assert "$opc-skills" in primary
  assert "adapters/codex/opc-skills/SKILL.md" in compat
  assert re.search(r"^name: zx-skills$", compat, re.MULTILINE)
  assert "## 第三方 Skill" not in compat

  reminder = read("templates/codex-agents-reminder.md")
  assert "<!-- zx-skills-reminder:start -->" in reminder
  assert "$opc-skills 总结一下当前链路" in reminder

  assert manifest["validation"]["custom_skill_id_format"] == "zx-<category>-<function>"
  for stable_prefix in ("zxsi-", "zpo-"):
      assert stable_prefix in read("scripts/compute-proposal-id.py")
  for path in (ROOT / "skills-custom").glob("*/**/skill.y*ml"):
      skill = yaml.safe_load(path.read_text(encoding="utf-8"))
      assert skill["id"].startswith("zx-")
  ```

- [ ] **Step 2: Run the new test and verify the intended RED state**

  Run: `python3 tests/test-opc-branding.py`

  Expected: FAIL because `skill-manifest.yaml` still uses `zxskills` and the `opc-skills` adapter does not yet exist.

- [ ] **Step 3: Commit only the RED contract test**

  ```bash
  git add tests/test-opc-branding.py
  git commit -m "test: define OPCSkills migration contract"
  ```

### Task 2: Establish the Main Adapter and Thin Compatibility Alias

**Files:**
- Create: `adapters/codex/opc-skills/SKILL.md`
- Create: `adapters/codex/opc-skills/agents/openai.yaml`
- Modify: `adapters/codex/zx-skills/SKILL.md`
- Modify: `adapters/codex/zx-skills/agents/openai.yaml`
- Modify: `tests/test-personal-namespace.py`
- Modify: `tests/test-dynamic-categories.py`
- Modify: `tests/test-project-organizer-contract.py`
- Modify: `tests/test-project-organizer-directory-first.py`
- Modify: `tests/test-selfimprove-confirmation.py`

**Interfaces:**
- Consumes: Task 1 中的主入口/兼容入口契约。
- Produces: 完整主适配器 `opc-skills`，以及只读取并转交该文件的 `zx-skills` 别名。

- [ ] **Step 1: Point behavior tests at the future primary adapter**

  把五个 Python 测试中的适配器路径统一改为：

  ```python
  ADAPTER_PATH = ROOT / "adapters" / "codex" / "opc-skills" / "SKILL.md"
  ```

  对于当前直接赋值为 `adapter` 的测试，使用：

  ```python
  adapter = (ROOT / "adapters/codex/opc-skills/SKILL.md").read_text(encoding="utf-8")
  ```

- [ ] **Step 2: Run one focused test and verify it fails on the missing primary adapter**

  Run: `python3 tests/test-selfimprove-confirmation.py`

  Expected: FAIL with `FileNotFoundError` for `adapters/codex/opc-skills/SKILL.md`.

- [ ] **Step 3: Create the primary adapter from the current proven router**

  Copy the current complete `zx-skills/SKILL.md`, then make these exact primary-entry substitutions while preserving all `zx-*` Skill IDs, `zxsi-*` and `zpo-*` protocol text:

  ```yaml
  ---
  name: opc-skills
  description: Use when the user explicitly invokes OPCSkills to execute a formal local skill, import or install a third-party skill, summarize the current delivery workflow, extract reusable experience, create or update a personal skill, list repository skills, or check repository status.
  ---
  ```

  ```markdown
  # OPCSkills

  把 `$opc-skills` 作为 OPCSkills 仓库的主入口。接受自然语言，不要求用户填写内部 YAML 参数；根据意图读取并执行对应 builtin Skill。
  ```

  将仓库根变量名改为 `OPCSKILLS_ROOT`，将所有用户可复制的总入口命令改为 `$opc-skills`；说明 `$zx-skills` 是等价兼容别名，但不要在每个命令同时展示两种写法。

- [ ] **Step 4: Replace the old adapter with a complete thin redirect**

  `adapters/codex/zx-skills/SKILL.md` 仅保留以下职责：

  ```markdown
  ---
  name: zx-skills
  description: Compatibility alias for OPCSkills. Use when the user explicitly invokes the legacy $zx-skills entrypoint.
  ---

  # OPCSkills 兼容入口

  `$zx-skills` 是 `$opc-skills` 的兼容别名。

  1. 解析当前 `SKILL.md` 的真实路径，向上定位包含 `skill-manifest.yaml` 的仓库根目录。
  2. 读取 `<repository-root>/adapters/codex/opc-skills/SKILL.md` 的完整内容。
  3. 按主适配器执行本次用户请求；保留原始用户输入，不缩写、不改写、不绕过其确认门禁。
  4. 若主适配器或 manifest 不存在，立即停止并报告实际路径，不猜测其他仓库。
  ```

- [ ] **Step 5: Add main and compatibility display metadata**

  Main metadata:

  ```yaml
  interface:
    display_name: "OPCSkills"
    short_description: "统一管理第三方导入、链路总结和个人 Skill 沉淀"
    default_prompt: "Use $opc-skills to summarize the current workflow and decide whether to create or update a reusable skill."
  policy:
    allow_implicit_invocation: false
  ```

  Compatibility metadata:

  ```yaml
  interface:
    display_name: "OPCSkills (zx-skills compatibility)"
    short_description: "旧入口；新任务请优先使用 $opc-skills"
    default_prompt: "Use the legacy $zx-skills alias and delegate the request to the OPCSkills primary adapter."
  policy:
    allow_implicit_invocation: false
  ```

- [ ] **Step 6: Run adapter-focused tests**

  Run:

  ```bash
  python3 tests/test-personal-namespace.py
  python3 tests/test-dynamic-categories.py
  python3 tests/test-project-organizer-contract.py
  python3 tests/test-project-organizer-directory-first.py
  python3 tests/test-selfimprove-confirmation.py
  ```

  Expected: all PASS; the Task 1 brand test may still fail only on manifest/README/reminder branding that Task 4 will change.

- [ ] **Step 7: Commit the adapter boundary**

  ```bash
  git add adapters/codex tests/test-personal-namespace.py tests/test-dynamic-categories.py tests/test-project-organizer-contract.py tests/test-project-organizer-directory-first.py tests/test-selfimprove-confirmation.py
  git commit -m "feat: add OPCSkills primary Codex entrypoint"
  ```

### Task 3: Implement and Test Dual-Entrypoint Installation

**Files:**
- Create: `tests/test-install-codex.sh`
- Create: `tests/test-install-codex.ps1`
- Modify: `scripts/install-codex.sh`
- Modify: `scripts/install-codex.ps1`

**Interfaces:**
- Consumes: Task 2 产生的 `adapters/codex/opc-skills` 和 `adapters/codex/zx-skills`。
- Produces: `install|status|uninstall` 三个动作；测试时可用 `OPCSKILLS_SKILLS_HOME` 把目标目录隔离到临时路径。

- [ ] **Step 1: Write POSIX dual-entry tests**

  测试使用 `mktemp -d` 和：

  ```bash
  export OPCSKILLS_SKILLS_HOME="$test_root/skills"
  ```

  必须覆盖以下断言：

  ```bash
  "$script_path" install
  [[ "$(cd "$OPCSKILLS_SKILLS_HOME/opc-skills" && pwd -P)" == "$repository_root/adapters/codex/opc-skills" ]]
  [[ "$(cd "$OPCSKILLS_SKILLS_HOME/zx-skills" && pwd -P)" == "$repository_root/adapters/codex/zx-skills" ]]
  "$script_path" status
  "$script_path" install
  "$script_path" uninstall
  [[ ! -e "$OPCSKILLS_SKILLS_HOME/opc-skills" && ! -L "$OPCSKILLS_SKILLS_HOME/opc-skills" ]]
  [[ ! -e "$OPCSKILLS_SKILLS_HOME/zx-skills" && ! -L "$OPCSKILLS_SKILLS_HOME/zx-skills" ]]
  ```

  再分别建立“只有指向本仓库的旧 `zx-skills`链接”与“`opc-skills` 是用户普通文件”两个独立临时目录：前者安装后必须变为双入口；后者必须非零退出，且不创建/删除 `zx-skills`。

- [ ] **Step 2: Run POSIX tests and verify RED**

  Run: `bash tests/test-install-codex.sh`

  Expected: FAIL because the current installer only manages `zx-skills` and ignores `OPCSKILLS_SKILLS_HOME`.

- [ ] **Step 3: Write the equivalent PowerShell tests**

  Use a unique temp directory and preserve/restore the previous environment value:

  ```powershell
  $OriginalSkillsHome = $env:OPCSKILLS_SKILLS_HOME
  $env:OPCSKILLS_SKILLS_HOME = Join-Path $TestRoot "skills"
  try {
      & $ScriptPath install
      & $ScriptPath status
      & $ScriptPath install
      & $ScriptPath uninstall
  }
  finally {
      $env:OPCSKILLS_SKILLS_HOME = $OriginalSkillsHome
      if (Test-Path -LiteralPath $TestRoot) {
          Remove-Item -LiteralPath $TestRoot -Recurse -Force
      }
  }
  ```

  Include the same fresh install, legacy-only upgrade and foreign-path conflict cases as the POSIX test.

- [ ] **Step 4: Run PowerShell tests and verify RED**

  Run: `pwsh -NoProfile -File tests/test-install-codex.ps1`

  Expected: FAIL because the current installer only manages `zx-skills`.

- [ ] **Step 5: Implement preflight-first dual management in both installers**

  Define exactly two source/target pairs:

  ```text
  opc-skills -> adapters/codex/opc-skills
  zx-skills  -> adapters/codex/zx-skills
  ```

  Target parent resolution must be:

  ```bash
  target_parent="${OPCSKILLS_SKILLS_HOME:-$HOME/.agents/skills}"
  ```

  ```powershell
  $TargetParent = if ([string]::IsNullOrWhiteSpace($env:OPCSKILLS_SKILLS_HOME)) {
      Join-Path $HOME ".agents\skills"
  }
  else {
      $env:OPCSKILLS_SKILLS_HOME
  }
  ```

  For each pair classify the target as `current`, `absent` or `conflict`. Before `install` or `uninstall`, inspect both pairs; if either is `conflict`, exit without changing either path. `install` creates only `absent` entries and records which entries it created so a later creation failure can remove only those newly created entries. `status` prints one line per entry and exits zero only when both are `current`. `uninstall` removes only entries classified `current`; it never removes a regular file, foreign link, repository directory or business Skill.

- [ ] **Step 6: Run both installer suites**

  Run:

  ```bash
  bash tests/test-install-codex.sh
  pwsh -NoProfile -File tests/test-install-codex.ps1
  ```

  Expected: both PASS, including idempotency, legacy upgrade and conflict protection.

- [ ] **Step 7: Commit the dual installer**

  ```bash
  git add scripts/install-codex.sh scripts/install-codex.ps1 tests/test-install-codex.sh tests/test-install-codex.ps1
  git commit -m "feat: install OPCSkills with legacy alias"
  ```

### Task 4: Migrate Active Branding, Prompts, and Reminder Copy

**Files:**
- Modify: `skill-manifest.yaml`
- Modify: `builtin/skill-creator.yaml`
- Modify: `builtin/skill-editor.yaml`
- Modify: `builtin/skill-import-external.yaml`
- Modify: `builtin/skill-selfimprove.yaml`
- Modify: `skills-custom/02-ui-design/zx-ui-spec/skill.yaml`
- Modify: `skills-custom/02-ui-design/zx-ui-check/skill.yaml`
- Modify: `templates/codex-agents-reminder.md`
- Modify: `scripts/configure-codex-reminder.sh`
- Modify: `scripts/configure-codex-reminder.ps1`
- Modify: `tests/test-configure-codex-reminder.sh`
- Modify: `tests/test-configure-codex-reminder.ps1`
- Modify: `scripts/compute-proposal-id.py`
- Modify: `tests/test-proposal-id.py`

**Interfaces:**
- Consumes: Task 1 brand test and Task 2 `$opc-skills` main command.
- Produces: active repository metadata and user-facing prompts consistently branded OPCSkills while stable ID/marker protocols remain byte-for-byte compatible.

- [ ] **Step 1: Extend the brand test to enumerate active branded files**

  Add exact checks that `ZXSkills` does not appear in current runtime and user-facing files:

  ```python
  ACTIVE_BRAND_FILES = [
      "skill-manifest.yaml",
      "builtin/skill-creator.yaml",
      "builtin/skill-editor.yaml",
      "builtin/skill-import-external.yaml",
      "builtin/skill-selfimprove.yaml",
      "templates/codex-agents-reminder.md",
      "scripts/install-codex.sh",
      "scripts/install-codex.ps1",
      "scripts/configure-codex-reminder.sh",
      "scripts/configure-codex-reminder.ps1",
  ]
  for path in ACTIVE_BRAND_FILES:
      assert "ZXSkills" not in read(path), path
  ```

  Also assert the marker remains exactly `zx-skills-reminder` and manifest values remain:

  ```python
  assert manifest["validation"]["custom_skill_id_pattern"].startswith("^zx-")
  assert manifest["validation"]["external_forbidden_id_prefixes"] == ["zx-"]
  ```

- [ ] **Step 2: Run the brand test and verify RED on active branding**

  Run: `python3 tests/test-opc-branding.py`

  Expected: FAIL on current `ZXSkills` strings.

- [ ] **Step 3: Update manifest and Skill metadata**

  Set:

  ```yaml
  repository:
    id: opc-skills
    name: "OPCSkills"
    description: "覆盖产品、设计、研发、测试、发布和项目管理完整交付链路的本地 Skill 集合。"
  ```

  In all four builtin Skills change repository prose and `metadata.author` to `OPCSkills`, and change generated copyable entry commands from `$zx-skills` to `$opc-skills`. Bump patch versions exactly as follows because the output contract changes:

  ```text
  skill-creator: 3.0.0 -> 3.0.1
  skill-editor: 3.0.0 -> 3.0.1
  skill-import-external: 3.0.0 -> 3.0.1
  skill-selfimprove: 4.0.0 -> 4.0.1
  ```

  Change the two UI Skill repository-owned author values from `ZXSkills` to `OPCSkills`; keep IDs, names, versions and triggers unchanged. Keep `zx-project-organizer` author `ZX` unchanged because it denotes the personal namespace, not the retired project brand.

- [ ] **Step 4: Update reminder content while preserving the old managed markers**

  The template must begin/end with the existing markers and contain:

  ```markdown
  <!-- zx-skills-reminder:start -->
  ## OPCSkills 沉淀提醒

  - 完成并验证一个可复用的功能、方案、测试、排障或发布节点后，如果形成了跨项目可复用的判断、流程、模板或门禁，在最终答复末尾提醒：
    `💡 本次链路可能值得沉淀，建议运行：$opc-skills 总结一下当前链路`
  - 只提醒，不自动调用 OPCSkills，不自动创建、修改、移动或删除 OPCSkills 仓库中的文件。
  <!-- zx-skills-reminder:end -->
  ```

  Reminder scripts must continue finding/removing old marker blocks but print `OPCSkills` in all user-visible status/error messages. Update both reminder tests to expect `$opc-skills` and to keep asserting `<!-- zx-skills-reminder:start -->`.

- [ ] **Step 5: Update non-protocol script descriptions**

  Change the module docstrings and success text in `scripts/compute-proposal-id.py` and `tests/test-proposal-id.py` from `ZXSkills` to `OPCSkills`. Do not change `zxsi`/`zpo` prefix selection, canonical JSON serialization, SHA-256 inputs or test vectors.

- [ ] **Step 6: Run brand, reminder, namespace, proposal and YAML tests**

  Run:

  ```bash
  python3 tests/test-opc-branding.py
  python3 tests/test-personal-namespace.py
  python3 tests/test-proposal-id.py
  bash tests/test-configure-codex-reminder.sh
  pwsh -NoProfile -File tests/test-configure-codex-reminder.ps1
  ```

  Expected: all PASS.

- [ ] **Step 7: Commit active branding**

  ```bash
  git add skill-manifest.yaml builtin skills-custom/02-ui-design templates scripts/configure-codex-reminder.sh scripts/configure-codex-reminder.ps1 scripts/compute-proposal-id.py tests/test-opc-branding.py tests/test-configure-codex-reminder.sh tests/test-configure-codex-reminder.ps1 tests/test-proposal-id.py
  git commit -m "refactor: migrate active branding to OPCSkills"
  ```

### Task 5: Rewrite the Public README for GitHub-First Dual-Entry Use

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: Task 2 main/compat adapter, Task 3 dual installer and Task 4 reminder behavior.
- Produces: an external-user guide whose commands work against `geek-black-li/opc-skills` and whose compatibility section explains what remains `zx-*`.

- [ ] **Step 1: Add README assertions to the brand test**

  Assert the public guide contains:

  ```python
  readme = read("README.md")
  for phrase in (
      "# OPCSkills：全栈 OPC 本地 Skills 仓库",
      "git clone https://github.com/geek-black-li/opc-skills.git",
      "cd opc-skills",
      "$opc-skills 查看仓库状态",
      "~/.agents/skills/opc-skills",
      "~/.agents/skills/zx-skills",
      "Gitee 备用远程",
      "zx-<category>-<function>",
  ):
      assert phrase in readme, phrase
  ```

  Assert the README still explicitly documents `$zx-skills` as a compatibility alias, not as the recommended primary entry.

- [ ] **Step 2: Run the brand test and verify README RED**

  Run: `python3 tests/test-opc-branding.py`

  Expected: FAIL on the old title, Gitee clone command and single-entry install instructions.

- [ ] **Step 3: Update the installation and daily-use path**

  Replace the public quick start with:

  ```bash
  git clone https://github.com/geek-black-li/opc-skills.git
  cd opc-skills
  bash scripts/install-codex.sh
  ```

  Show both installed paths, recommend `/skills` then `$opc-skills 查看仓库状态`, and make every normal daily-use example start with `$opc-skills`.

- [ ] **Step 4: Add the compatibility and remote notes**

  State all four boundaries together:

  ```text
  - `$opc-skills` is the primary repository entry.
  - `$zx-skills` remains available for existing instructions and habits.
  - Personal Skill IDs remain `zx-*`; proposal IDs remain `zxsi-*` and `zpo-*`.
  - GitHub is the primary repository; Gitee is a manually synchronized backup remote, not an automatic mirror.
  ```

  Update the repository tree to start with `OPCSkills/` and show both adapter directories. Preserve the complete temp-inbox isolation warning, three workflows, dynamic category rules, project-organizer guide and multi-tool compatibility sections.

- [ ] **Step 5: Update troubleshooting and uninstall guidance**

  Explain that `status` requires both managed entries, `uninstall` removes only those two links, a foreign path is never overwritten, and an old single `$zx-skills` install is upgraded by rerunning `install`. Keep reminder uninstall separate and document that its old marker is deliberately stable.

- [ ] **Step 6: Run README and behavior regressions**

  Run:

  ```bash
  python3 tests/test-opc-branding.py
  python3 tests/test-personal-namespace.py
  python3 tests/test-dynamic-categories.py
  bash tests/test-install-codex.sh
  bash tests/test-configure-codex-reminder.sh
  ```

  Expected: all PASS.

- [ ] **Step 7: Commit the public guide**

  ```bash
  git add README.md tests/test-opc-branding.py
  git commit -m "docs: publish OPCSkills setup and compatibility guide"
  ```

### Task 6: Run the Complete Repository Gate and Create the Final Gitee Backup Point

**Files:**
- Modify: `docs/superpowers/specs/2026-08-14-opc-skills-migration-design.md`
- Create: `docs/superpowers/plans/2026-08-14-opc-skills-migration-verification.md`

**Interfaces:**
- Consumes: all repository changes from Tasks 1-5.
- Produces: a clean, tested `main` whose exact HEAD is backed up once to the current Gitee `origin/main` before remote renaming.

- [ ] **Step 1: Run every tracked Python test independently**

  Run:

  ```bash
  for test_file in tests/test-*.py
  do
    python3 "$test_file"
  done
  ```

  Expected: every file exits 0, including proposal hashes and project-organizer contracts.

- [ ] **Step 2: Run all shell and PowerShell tests**

  Run:

  ```bash
  bash tests/test-install-codex.sh
  bash tests/test-configure-codex-reminder.sh
  pwsh -NoProfile -File tests/test-install-codex.ps1
  pwsh -NoProfile -File tests/test-configure-codex-reminder.ps1
  ```

  Expected: four PASS results.

- [ ] **Step 3: Parse every YAML file and check whitespace**

  Run:

  ```bash
  python3 -c 'from pathlib import Path; import yaml; files=list(Path(".").rglob("*.yaml"))+list(Path(".").rglob("*.yml")); [yaml.safe_load(p.read_text(encoding="utf-8")) for p in files if ".git" not in p.parts]; print(f"YAML parsed: {len(files)}")'
  git diff --check
  ```

  Expected: YAML parse exits 0 and `git diff --check` prints nothing.

- [ ] **Step 4: Record verification without machine secrets**

  Write the commands, pass counts, current commit hash and `git status --short` result to `docs/superpowers/plans/2026-08-14-opc-skills-migration-verification.md`. Do not include the GitHub token, Keychain data, proxy environment dump or absolute temp paths. Change the design status to `已实施仓库内迁移，等待远程与本地目录迁移`.

- [ ] **Step 5: Commit the verification record**

  ```bash
  git add docs/superpowers/specs/2026-08-14-opc-skills-migration-design.md docs/superpowers/plans/2026-08-14-opc-skills-migration-verification.md
  git commit -m "test: record OPCSkills migration verification"
  ```

- [ ] **Step 6: Recheck clean state and Gitee relationship**

  Run:

  ```bash
  git status --short
  git remote get-url origin
  git fetch origin main
  git log --oneline --decorate -1
  ```

  Expected: clean status; `origin` is still the Gitee URL; local `main` is only ahead, never behind or diverged from `origin/main`.

- [ ] **Step 7: Make the one-time migration backup push to Gitee**

  Run: `git push origin main`

  Expected: push succeeds, then `git rev-parse HEAD` equals `git rev-parse origin/main`. If it fails, stop before GitHub creation and do not change remotes.

### Task 7: Create the GitHub Repository and Switch to Dual Remotes

**Files:**
- Modify: local `.git/config` only through `git remote` commands; no tracked file changes.
- External create: `https://github.com/geek-black-li/opc-skills`

**Interfaces:**
- Consumes: clean, tested and Gitee-backed HEAD from Task 6; authenticated `gh 2.97.0` account `geek-black-li`.
- Produces: GitHub Public `origin`, Gitee backup `gitee`, and GitHub `main` equal to local HEAD.

- [ ] **Step 1: Verify account, repository availability, and local preconditions**

  Run each with proxy only on the GitHub commands:

  ```bash
  HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gh auth status
  HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gh repo view geek-black-li/opc-skills --json nameWithOwner,visibility,url
  git status --short
  git rev-parse HEAD
  git rev-parse origin/main
  git remote -v
  ```

  Expected: authenticated as `geek-black-li`; repository lookup returns not found before creation; worktree clean; local and Gitee hashes match; only the intended Gitee URL is named `origin`. If the GitHub repository already exists, inspect it and stop unless it is the intended empty repository owned by `geek-black-li`.

- [ ] **Step 2: Create the empty Public GitHub repository**

  Run:

  ```bash
  HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gh repo create geek-black-li/opc-skills --public --description "Reusable full-stack OPC skills for end-to-end project delivery"
  ```

  Expected: repository created without README, `.gitignore` or License; `gh repo view` reports `visibility=PUBLIC`.

- [ ] **Step 3: Rename the current remote and add GitHub as origin**

  Run:

  ```bash
  git remote rename origin gitee
  git remote add origin https://github.com/geek-black-li/opc-skills.git
  git remote -v
  ```

  Expected: `origin` has the GitHub URL and `gitee` has the unchanged Gitee URL.

- [ ] **Step 4: Push and set GitHub tracking**

  Run:

  ```bash
  HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 git push -u origin main
  ```

  Expected: push succeeds and local `main` tracks `origin/main`.

- [ ] **Step 5: Verify remote identity, visibility, and exact commit hash**

  Run:

  ```bash
  local_head=$(git rev-parse HEAD)
  github_head=$(HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 git ls-remote origin refs/heads/main | awk '{print $1}')
  test "$local_head" = "$github_head"
  HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gh repo view geek-black-li/opc-skills --json nameWithOwner,visibility,url,defaultBranchRef
  git remote -v
  ```

  Expected: hashes equal, GitHub reports Public and default branch `main`, and Gitee remains configured as `gitee`.

- [ ] **Step 6: Apply the explicit failure recovery if remote switching fails before a verified push**

  Only on failure before Step 5 succeeds: inspect `git remote -v`; if GitHub currently occupies `origin`, remove that local remote, then rename `gitee` back to `origin`. Do not delete either hosted repository and do not force-push.

  ```bash
  git remote remove origin
  git remote rename gitee origin
  git remote -v
  ```

### Task 8: Rename the Local Directory and Reinstall Both Codex Entries

**Files:**
- Move: `/Users/black_li/Desktop/01 工作/其他/产品/ZXSkills` -> `/Users/black_li/Desktop/01 工作/其他/产品/OPCSkills`
- Modify: user-managed links under `/Users/black_li/.agents/skills/`

**Interfaces:**
- Consumes: verified GitHub `origin/main` and the dual-entry installer from Task 3.
- Produces: new local root and two Codex entries resolving to it; no tracked repository content change.

- [ ] **Step 1: Resolve and record current managed entries without changing them**

  Run:

  ```bash
  bash scripts/install-codex.sh status
  readlink /Users/black_li/.agents/skills/opc-skills
  readlink /Users/black_li/.agents/skills/zx-skills
  ```

  Expected: status is either a valid dual install or a known legacy-only state. Any foreign path conflict stops the rename until resolved explicitly.

- [ ] **Step 2: Recheck the irreversible-boundary preconditions**

  Run from the current repository:

  ```bash
  git status --short
  git rev-parse HEAD
  git rev-parse origin/main
  test ! -e '/Users/black_li/Desktop/01 工作/其他/产品/OPCSkills'
  ```

  Expected: clean worktree; hashes equal; target directory absent. Any failure stops the task.

- [ ] **Step 3: Remove the currently valid managed links before moving the repository**

  Run while both links still resolve to the old repository path:

  ```bash
  bash scripts/install-codex.sh uninstall
  test ! -e /Users/black_li/.agents/skills/opc-skills
  test ! -L /Users/black_li/.agents/skills/opc-skills
  test ! -e /Users/black_li/.agents/skills/zx-skills
  test ! -L /Users/black_li/.agents/skills/zx-skills
  ```

  Expected: only the two verified managed links are removed. If uninstall refuses either path, stop before moving the repository. If the later directory rename itself fails, rerun `bash scripts/install-codex.sh install` from the unchanged `ZXSkills` path to restore both links.

- [ ] **Step 4: Rename the repository from its parent directory**

  Run with working directory `/Users/black_li/Desktop/01 工作/其他/产品`:

  ```bash
  mv -- 'ZXSkills' 'OPCSkills'
  ```

  Expected: the old path no longer exists and the new path contains `.git`, `README.md` and `skill-manifest.yaml`.

- [ ] **Step 5: Reinstall the two managed entries from the new path**

  Run with working directory `/Users/black_li/Desktop/01 工作/其他/产品/OPCSkills`:

  ```bash
  bash scripts/install-codex.sh install
  bash scripts/install-codex.sh status
  ```

  Expected: both `opc-skills` and `zx-skills` resolve under the new `OPCSkills/adapters/codex` root. Because Step 3 removed only verified managed links while their targets were still readable, this install does not need to guess whether a broken old-path link belonged to the repository.

- [ ] **Step 6: Verify both resolved targets exactly**

  Run:

  ```bash
  test "$(cd /Users/black_li/.agents/skills/opc-skills && pwd -P)" = '/Users/black_li/Desktop/01 工作/其他/产品/OPCSkills/adapters/codex/opc-skills'
  test "$(cd /Users/black_li/.agents/skills/zx-skills && pwd -P)" = '/Users/black_li/Desktop/01 工作/其他/产品/OPCSkills/adapters/codex/zx-skills'
  ```

  Expected: both commands exit 0.

### Task 9: Final End-to-End Verification and Handoff

**Files:**
- No tracked changes expected.

**Interfaces:**
- Consumes: new path, dual local entrypoints and dual remotes.
- Produces: evidence that all completion conditions are simultaneously true and a user handoff to reopen the Codex workspace.

- [ ] **Step 1: Run the full test suite again from the renamed root**

  Run from `/Users/black_li/Desktop/01 工作/其他/产品/OPCSkills`:

  ```bash
  for test_file in tests/test-*.py
  do
    python3 "$test_file"
  done
  bash tests/test-install-codex.sh
  bash tests/test-configure-codex-reminder.sh
  pwsh -NoProfile -File tests/test-install-codex.ps1
  pwsh -NoProfile -File tests/test-configure-codex-reminder.ps1
  git diff --check
  ```

  Expected: every test passes and `git diff --check` is silent.

- [ ] **Step 2: Verify all live state in one final snapshot**

  Run:

  ```bash
  pwd -P
  git status -sb
  git remote -v
  git rev-parse HEAD
  git rev-parse origin/main
  bash scripts/install-codex.sh status
  HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gh repo view geek-black-li/opc-skills --json nameWithOwner,visibility,url,defaultBranchRef
  ```

  Expected: path ends in `/OPCSkills`; status is clean and tracks `origin/main`; hashes equal; `origin` is GitHub; `gitee` is Gitee; both entries installed; GitHub is Public on `main`.

- [ ] **Step 3: Perform a read-only adapter discovery check**

  Confirm both installed `SKILL.md` files are readable, main frontmatter says `name: opc-skills`, compatibility frontmatter says `name: zx-skills`, and the compatibility file points to `adapters/codex/opc-skills/SKILL.md`. Do not invoke creator/editor/import workflows during this smoke check.

- [ ] **Step 4: Hand off the new workspace**

  Report the GitHub URL, current commit hash, two remote URLs, new local path, both installed entries and full test counts. Ask the user to close the old `ZXSkills` workspace and open `/Users/black_li/Desktop/01 工作/其他/产品/OPCSkills`; then start a new Codex task and verify `/skills`, `$opc-skills 查看仓库状态`, and `$zx-skills 查看仓库状态`.
