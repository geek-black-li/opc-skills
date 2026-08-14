# OPCSkills Single-Entry Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the legacy `$zx-skills` repository entrypoint and make `$opc-skills` the only installed and documented Codex entry while preserving the `zx-*`, `zxsi-*`, and `zpo-*` namespaces.

**Architecture:** Keep `adapters/codex/opc-skills` as the only full router. Simplify both installers to manage one owned link, rename the completion-reminder marker without retaining an upgrade path, and update current documentation and behavior tests. Preserve dated migration specifications and plans as historical evidence.

**Tech Stack:** Markdown Skills, Bash, PowerShell, Python 3 contract tests, YAML/PyYAML, Git.

## Global Constraints

- Do not change any custom Skill ID beginning with `zx-`.
- Do not change proposal ID prefixes `zxsi-` or `zpo-`.
- Do not modify the dated 2026-08-14 migration design, implementation plan, or verification record.
- Installers must never overwrite, follow recursively, or delete a foreign file, directory, broken link, symlink, or Junction.
- The repository must not retain automatic migration or deletion behavior for a legacy `zx-skills` entry.
- Remove the currently installed old reminder block before changing its marker; install the new block after the new scripts pass tests.
- Commit repository changes locally; do not push either remote without a separate user instruction.

## File Map

| Responsibility | Files |
| --- | --- |
| Sole Codex router | `adapters/codex/opc-skills/SKILL.md`, delete `adapters/codex/zx-skills/` |
| POSIX single-entry lifecycle | `scripts/install-codex.sh`, `tests/test-install-codex.sh` |
| PowerShell single-entry lifecycle | `scripts/install-codex.ps1`, `tests/test-install-codex.ps1` |
| Reminder marker and local managed block | `templates/codex-agents-reminder.md`, `scripts/configure-codex-reminder.sh`, `scripts/configure-codex-reminder.ps1`, both reminder tests |
| Current user documentation and repository contract | `README.md`, `tests/test-opc-branding.py` |

---

### Task 1: Make `opc-skills` the sole adapter

**Files:**
- Modify: `tests/test-opc-branding.py`
- Modify: `adapters/codex/opc-skills/SKILL.md`
- Delete: `adapters/codex/zx-skills/SKILL.md`
- Delete: `adapters/codex/zx-skills/agents/openai.yaml`

**Interfaces:**
- Consumes: Codex discovery contract requiring one directory containing `SKILL.md` and optional `agents/openai.yaml`.
- Produces: one adapter named exactly `opc-skills`; stable business and proposal namespaces remain unchanged.

- [ ] **Step 1: Write the failing adapter contract**

Replace the compatibility-adapter assertions in `tests/test-opc-branding.py` with observable repository assertions:

```python
primary = read("adapters/codex/opc-skills/SKILL.md")
assert re.search(r"^name: opc-skills$", primary, re.MULTILINE)
assert "$opc-skills" in primary
assert "$zx-skills" not in primary
assert not (ROOT / "adapters/codex/zx-skills").exists()
```

Keep the existing manifest assertions for `^zx-`, `zxsi-`, and `zpo-` unchanged.

- [ ] **Step 2: Run the contract and verify RED**

Run:

```bash
python3 tests/test-opc-branding.py
```

Expected: FAIL because `adapters/codex/zx-skills` still exists or the primary adapter still says `$zx-skills` is an alias.

- [ ] **Step 3: Apply the minimal adapter cleanup**

Delete the two tracked compatibility-adapter files and remove only this sentence from the primary adapter:

```text
`$zx-skills` 是等价兼容别名。
```

Do not change routed builtin files, `zx-*` business Skill IDs, or proposal confirmation rules.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
python3 tests/test-opc-branding.py
```

Expected: PASS. Task 1 changes only adapter assertions; existing README compatibility assertions remain unchanged until Task 5.

- [ ] **Step 5: Commit**

```bash
git add tests/test-opc-branding.py adapters/codex/opc-skills/SKILL.md adapters/codex/zx-skills
git commit -m "refactor: remove legacy Codex adapter"
```

### Task 2: Simplify the POSIX installer to one owned link

**Files:**
- Modify: `tests/test-install-codex.sh`
- Modify: `scripts/install-codex.sh`

**Interfaces:**
- Consumes: `OPCSKILLS_SKILLS_HOME` override or `$HOME/.agents/skills` fallback.
- Produces: `install`, `status`, and `uninstall` for only `<skills-home>/opc-skills`.

- [ ] **Step 1: Rewrite the POSIX behavior test for one entry**

Keep real filesystem links and fault injection. The revised suite must assert:

```bash
assert_current_link_at "$skills_home/opc-skills" "$opc_source"
assert_absent "$skills_home/zx-skills"
assert_status_line "$case_root/status.out" opc-skills current
[ "$(wc -l < "$case_root/status.out" | tr -d ' ')" -eq 1 ]
```

Delete `zx_source`, dual-entry helpers, legacy-upgrade cases, and partial-two-entry cases. Add a non-interference case:

```bash
new_case ignored-legacy-name
mkdir -p "$skills_home"
printf 'foreign\n' > "$skills_home/zx-skills"
assert_success run_installer_quiet install "$case_root/install.out"
assert_current_link_at "$skills_home/opc-skills" "$opc_source"
[ "$(cat "$skills_home/zx-skills")" = foreign ] || fail "installer modified unrelated zx-skills path"
```

Preserve absolute/relative link idempotency, absent/current/conflict status, fallback HOME, uninstall ownership checks, and rollback fault injection for `opc-skills`.

- [ ] **Step 2: Verify RED**

Run:

```bash
bash tests/test-install-codex.sh
```

Expected: FAIL because the current installer creates and reports `zx-skills` and rejects a foreign `zx-skills` path.

- [ ] **Step 3: Implement a single-entry POSIX installer**

Reduce the source and target declarations to:

```bash
opc_source="$repository_root/adapters/codex/opc-skills"
opc_target="$target_parent/opc-skills"
```

Validate only `$opc_source/SKILL.md`. `preflight` calculates only `opc_state`; conflict refusal checks only `opc_target`; rollback removes only a newly created, still-owned `opc_target`. `install` creates only the OPC link, `status` prints one line and succeeds only for `current`, and `uninstall` removes only the still-owned OPC link. Use singular output:

```text
OPCSkills Codex entrypoint removed.
```

- [ ] **Step 4: Verify GREEN and mutation sensitivity**

Run:

```bash
bash tests/test-install-codex.sh
```

Expected: PASS. Confirm the committed rollback test would fail if the rollback call were removed from the `ln -s` failure branch.

- [ ] **Step 5: Commit**

```bash
git add scripts/install-codex.sh tests/test-install-codex.sh
git commit -m "refactor: install only opc-skills on POSIX"
```

### Task 3: Simplify the PowerShell installer to one owned link

**Files:**
- Modify: `tests/test-install-codex.ps1`
- Modify: `scripts/install-codex.ps1`

**Interfaces:**
- Consumes: `OPCSKILLS_SKILLS_HOME` override or `$HOME\.agents\skills` fallback.
- Produces: the same single-entry lifecycle as Task 2, using a symlink off Windows and a Junction on Windows.

- [ ] **Step 1: Rewrite the PowerShell behavior test for one entry**

Set only:

```powershell
$OpcSource = Join-Path $RepositoryRoot "adapters/codex/opc-skills"
```

Fresh install, status, idempotency, fallback, conflict, rollback, and uninstall cases must assert only `opc-skills`. Add the same non-interference contract with a real foreign file:

```powershell
$ForeignZx = Join-Path $Context.Skills "zx-skills"
[IO.Directory]::CreateDirectory($Context.Skills) | Out-Null
[IO.File]::WriteAllText($ForeignZx, "foreign`n")
Invoke-Installer $Context "install"
Assert-CurrentLink (Join-Path $Context.Skills "opc-skills") $OpcSource
if ([IO.File]::ReadAllText($ForeignZx) -ne "foreign`n") { throw "installer modified unrelated zx-skills path" }
```

Preserve the native-Windows API contract that owned directory links/Junctions are removed with the guarded `[IO.Directory]::Delete` helper, never recursive `Remove-Item`.

- [ ] **Step 2: Verify RED**

Run:

```bash
pwsh -NoProfile -File tests/test-install-codex.ps1
```

Expected: FAIL because the current `$Entries` array manages `zx-skills` and treats the foreign path as a conflict.

- [ ] **Step 3: Implement one PowerShell entry object**

Replace `$Entries` with one object while retaining the existing generic lifecycle functions:

```powershell
$Entries = @(
    [pscustomobject]@{
        Name = "opc-skills"
        Source = Join-Path $RepositoryRoot "adapters\codex\opc-skills"
        Target = Join-Path $TargetParent "opc-skills"
    }
)
```

Change only the uninstall success text to singular. Do not weaken `Get-TargetState`, `Assert-NoConflicts`, `Remove-CurrentEntrypointLink`, or rollback ownership rechecks.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
pwsh -NoProfile -File tests/test-install-codex.ps1
```

Expected: PASS, including safe teardown of live and broken reparse points in the test fixture.

- [ ] **Step 5: Commit**

```bash
git add scripts/install-codex.ps1 tests/test-install-codex.ps1
git commit -m "refactor: install only opc-skills on PowerShell"
```

### Task 4: Replace the completion-reminder marker and live managed block

**Files:**
- Modify: `templates/codex-agents-reminder.md`
- Modify: `scripts/configure-codex-reminder.sh`
- Modify: `scripts/configure-codex-reminder.ps1`
- Modify: `tests/test-configure-codex-reminder.sh`
- Modify: `tests/test-configure-codex-reminder.ps1`
- Modify outside repository: `/Users/black_li/.codex/AGENTS.md`

**Interfaces:**
- Consumes: a balanced managed block in the currently active global Codex instruction file.
- Produces: exactly one `opc-skills-reminder` block suggesting `$opc-skills 总结一下当前链路`.

- [ ] **Step 1: Remove the current old managed block before changing scripts**

Run the currently committed old-marker implementation:

```bash
bash scripts/configure-codex-reminder.sh uninstall
```

Then verify that `~/.codex/AGENTS.md` retains unrelated content and contains neither old marker nor old command:

```bash
! rg -n 'zx-skills-reminder|\$zx-skills' /Users/black_li/.codex/AGENTS.md
```

- [ ] **Step 2: Write new-marker tests**

In both reminder suites, replace all managed markers with:

```text
<!-- opc-skills-reminder:start -->
<!-- opc-skills-reminder:end -->
```

Delete legacy-marker upgrade fixtures. Preserve install/idempotency, active override selection, status, uninstall, malformed single-marker refusal, unrelated-content preservation, and `END-OF-SUITE` assertions. Require the installed block to contain `$opc-skills 总结一下当前链路` and no `$zx-skills` command.

- [ ] **Step 3: Verify RED**

Run:

```bash
bash tests/test-configure-codex-reminder.sh
pwsh -NoProfile -File tests/test-configure-codex-reminder.ps1
```

Expected: both FAIL because the production template and scripts still use `zx-skills-reminder`.

- [ ] **Step 4: Implement the new marker**

Set the template and both scripts to:

```text
<!-- opc-skills-reminder:start -->
<!-- opc-skills-reminder:end -->
```

In the POSIX script use:

```bash
temp_file="$(mktemp "$codex_home/.opc-skills-agents.XXXXXX")"
```

Do not add fallback recognition of `zx-skills-reminder`.

- [ ] **Step 5: Verify GREEN**

Run both reminder suites again. Expected: PASS and each prints `END-OF-SUITE`.

- [ ] **Step 6: Install and verify the live new block**

Run:

```bash
bash scripts/configure-codex-reminder.sh install
bash scripts/configure-codex-reminder.sh status
rg -n 'opc-skills-reminder|\$opc-skills' /Users/black_li/.codex/AGENTS.md
! rg -n 'zx-skills-reminder|\$zx-skills' /Users/black_li/.codex/AGENTS.md
```

Expected: one balanced new block, no old marker or command, and unrelated global instructions preserved.

- [ ] **Step 7: Commit**

```bash
git add templates/codex-agents-reminder.md scripts/configure-codex-reminder.sh scripts/configure-codex-reminder.ps1 tests/test-configure-codex-reminder.sh tests/test-configure-codex-reminder.ps1
git commit -m "refactor: rename OPCSkills reminder marker"
```

### Task 5: Publish the single-entry current guide and branding contract

**Files:**
- Modify: `tests/test-opc-branding.py`
- Modify: `README.md`

**Interfaces:**
- Consumes: Tasks 1–4 current single-entry behavior.
- Produces: a user guide with one installation path and no legacy invocation instructions.

- [ ] **Step 1: Write failing current-document assertions**

Update `tests/test-opc-branding.py` so current files require:

```python
assert "~/.agents/skills/opc-skills" in readme
assert "~/.agents/skills/zx-skills" not in readme
assert "$zx-skills" not in readme
assert "adapters/codex/zx-skills/" not in readme
assert "`status` 只有在受管入口正确指向当前仓库时才通过" in readme
assert "`uninstall` 只删除由安装器管理的 `opc-skills` 链接" in readme
assert "<!-- opc-skills-reminder:start -->" in reminder
assert "<!-- opc-skills-reminder:end -->" in reminder
```

Continue asserting `zx-<category>-<function>`, `zxsi-`, `zpo-`, `zx-project-organizer`, `zx-ui-spec`, and `zx-ui-check`.

- [ ] **Step 2: Verify RED**

Run:

```bash
python3 tests/test-opc-branding.py
```

Expected: FAIL because README still documents the compatibility adapter, two links, and the old marker.

- [ ] **Step 3: Update only current README guidance**

Make these exact semantic changes:

- “目前提供什么” says Codex provides the sole `$opc-skills` entry.
- Installation creates only `~/.agents/skills/opc-skills`.
- `/skills` verification expects only `opc-skills` from this repository.
- “入口与远程兼容边界” becomes “入口与远程边界” and distinguishes `opc-skills` from preserved `zx-*` IDs.
- Reminder text documents `opc-skills-reminder` as the current marker.
- Installer status/uninstall descriptions use a singular managed entry.
- Tool support, troubleshooting, FAQ, directory tree, and adapter explanation remove compatibility language and the legacy-upgrade FAQ.

Do not alter historical files under `docs/superpowers/specs/2026-08-14-*` or `docs/superpowers/plans/2026-08-14-*`.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
python3 tests/test-opc-branding.py
```

Expected: PASS with stable personal and proposal namespaces still asserted.

- [ ] **Step 5: Commit**

```bash
git add README.md tests/test-opc-branding.py
git commit -m "docs: document the sole opc-skills entrypoint"
```

### Task 6: Run full regression and verify live state

**Files:**
- Verify: all tracked repository files
- Verify outside repository: `/Users/black_li/.agents/skills/`, `/Users/black_li/.codex/AGENTS.md`

**Interfaces:**
- Consumes: all earlier task commits.
- Produces: clean, locally committed single-entry repository ready for an explicit push request.

- [ ] **Step 1: Run every executable suite**

```bash
for test_file in tests/test-*.py; do python3 "$test_file"; done
bash tests/test-install-codex.sh
pwsh -NoProfile -File tests/test-install-codex.ps1
bash tests/test-configure-codex-reminder.sh
pwsh -NoProfile -File tests/test-configure-codex-reminder.ps1
```

Expected: all Python files and all four shell/PowerShell suites pass; both reminder suites print `END-OF-SUITE`.

- [ ] **Step 2: Parse every tracked YAML file and check whitespace**

```bash
python3 - <<'PY'
import pathlib, subprocess, yaml
root = pathlib.Path('.')
paths = subprocess.check_output(
    ['git', 'ls-files', '-z', '--', '*.yaml', '*.yml']
).decode().split('\0')
for path in filter(None, paths):
    yaml.safe_load((root / path).read_text(encoding='utf-8'))
print(f'YAML_OK={len(list(filter(None, paths)))}')
PY
git diff --check
```

Expected: all tracked YAML/YML parses and `git diff --check` is silent.

- [ ] **Step 3: Verify repository and live Codex state**

```bash
bash scripts/install-codex.sh status
test -L /Users/black_li/.agents/skills/opc-skills
test ! -e /Users/black_li/.agents/skills/zx-skills
test ! -L /Users/black_li/.agents/skills/zx-skills
test "$(readlink /Users/black_li/.agents/skills/opc-skills)" = '/Users/black_li/Desktop/01 工作/其他/产品/OPCSkills/adapters/codex/opc-skills'
rg -n 'opc-skills-reminder|\$opc-skills' /Users/black_li/.codex/AGENTS.md
! rg -n 'zx-skills-reminder|\$zx-skills' /Users/black_li/.codex/AGENTS.md
git status --short --branch
```

Expected: one current local Skill link, one current new reminder block, no old link/marker/command, and no uncommitted tracked changes.

- [ ] **Step 4: Review the retained `zx` namespace hits**

```bash
rg -n --hidden --glob '!.git/**' --glob '!docs/superpowers/specs/2026-08-14-*' --glob '!docs/superpowers/plans/2026-08-14-*' 'zx-skills|\$zx-skills' .
```

Expected: no current compatibility-entry hit. Hits for `zx-*` business Skill IDs, `zxsi-*`, and `zpo-*` are valid and must remain.

- [ ] **Step 5: Record the final local commit and stop before pushing**

```bash
git log -7 --oneline
git status --short --branch
```

Report the commit range, test counts, live link, reminder state, and the fact that GitHub/Gitee have not been pushed by this plan.
