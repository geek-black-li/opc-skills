# OPCSkills 仓库内迁移验证记录

日期：2026-08-14

验证范围：仓库内迁移及最终修复门禁（Python、Shell、PowerShell、YAML 与空白检查）。

被测代码提交：`12b5031991af67eaa4f392992a7bc42a0af41cce`

PowerShell 环境：`PowerShell 7.6.3 Core` on macOS。本记录没有在原生 Windows / Windows PowerShell 5.1 上执行 Junction 测试；该项状态为 **NOT VERIFIED**。

## 执行结果

以下命令均在上述被测提交的干净工作树上执行，退出码均为 `0`。

### Python 测试（7/7 通过）

```bash
for test_file in tests/test-*.py
do
  python3 "$test_file"
done
```

通过的文件：

- `tests/test-dynamic-categories.py`
- `tests/test-opc-branding.py`
- `tests/test-personal-namespace.py`
- `tests/test-project-organizer-contract.py`
- `tests/test-project-organizer-directory-first.py`
- `tests/test-proposal-id.py`
- `tests/test-selfimprove-confirmation.py`

命令结尾计数：`PYTHON_TEST_FILES_PASSED=7`。

### Shell 与 PowerShell 测试（4/4 通过）

```bash
bash tests/test-install-codex.sh
pwsh -NoProfile -File tests/test-install-codex.ps1
bash tests/test-configure-codex-reminder.sh
pwsh -NoProfile -File tests/test-configure-codex-reminder.ps1
```

安装器套件实际结尾输出：

```text
PASS: POSIX Codex installer covers dual-entry lifecycle, status, conflicts, fallback, idempotency, and rollback
PASS: PowerShell Codex installer covers dual-entry lifecycle, status, conflicts, fallback, idempotency, and rollback
```

提醒套件实际结尾哨兵输出：

```text
END-OF-SUITE: OPCSkills POSIX reminder tests passed (legacy upgrade, status, uninstall, override migration, malformed markers, README).
END-OF-SUITE: OPCSkills PowerShell reminder tests passed (legacy upgrade, status, uninstall, override migration, malformed markers, README).
```

PowerShell 提醒测试的 `install` / `status` / `uninstall` 全部通过子 PowerShell 进程执行，并逐次校验退出码与输出；最终哨兵证明卸载、override 迁移、畸形标记拒绝及 README 断言均已执行。

### YAML 与空白检查（2/2 通过）

```bash
python3 -c 'from pathlib import Path; import yaml; files=list(Path(".").rglob("*.yaml"))+list(Path(".").rglob("*.yml")); parsed=[p for p in files if ".git" not in p.parts]; [yaml.safe_load(p.read_text(encoding="utf-8")) for p in parsed]; print(f"YAML parsed: {len(parsed)}"); raise SystemExit(0 if len(parsed)==14 else 1)'
git diff --check d507724..HEAD
```

YAML 解析输出：`YAML parsed: 14`。`git diff --check d507724..HEAD` 无输出，退出码为 `0`。

## 工作树状态

门禁执行前后，`git status --short` 均无输出。本验证记录将在独立的仅记录提交中纳入版本控制。

## 后续边界

本记录不包含远程操作、用户 Skill 目录修改或原生 Windows Junction 执行。后续仍须按迁移计划由主任务完成并验证 Gitee 备份推送、GitHub 双远程切换、本地目录迁移和双入口重装。
