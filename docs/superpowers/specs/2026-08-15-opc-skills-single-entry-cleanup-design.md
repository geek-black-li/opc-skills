# OPCSkills 单入口清理设计

日期：2026-08-15

状态：已确认，待实施

## 1. 背景与目标

OPCSkills 当前只有仓库所有者本人使用，本机已经移除 `$zx-skills` 兼容入口，
不存在需要照顾的外部老用户。因此不再保留旧调用入口及其升级兼容逻辑，Codex
只暴露 `$opc-skills` 一个仓库总入口。

本次清理只移除旧的仓库调用入口。个人 Skill 命名空间和既有协议标识不是兼容
代码，必须继续保留。

## 2. 保留边界

以下内容保持不变：

- 自定义 Skill 使用 `zx-*` 命名空间；
- Self-Improve 提案 ID 使用 `zxsi-*`；
- Project Organizer 提案 ID 使用 `zpo-*`；
- GitHub 仓库名、OPCSkills 品牌和 `$opc-skills` 主入口；
- 已完成的历史设计、实施计划和验证记录原文，作为当时决策与执行证据。

## 3. 删除与修改范围

### 3.1 Codex 适配器

- 删除 `adapters/codex/zx-skills/`；
- `adapters/codex/opc-skills/` 成为唯一 Codex 总入口；
- 主适配器不再声明 `$zx-skills` 是兼容别名。

### 3.2 安装器

POSIX 与 PowerShell 安装器统一为单入口契约：

- `install` 只创建 `opc-skills`；
- `status` 只报告 `opc-skills`；
- `uninstall` 只删除经归属校验的 `opc-skills`；
- 删除 `zx-skills` 的创建、状态、冲突、回滚、升级和卸载分支；
- 不扫描、不修改任意现存的同名外部路径。

由于当前没有老用户，安装器不承担旧入口自动迁移或自动删除职责。

### 3.3 提醒配置

- 受管标记从 `zx-skills-reminder` 改为 `opc-skills-reminder`；
- POSIX 临时文件前缀从 `.zx-skills-*` 改为 `.opc-skills-*`；
- 模板、脚本、测试和当前 README 使用同一新标记；
- 不保留旧标记识别或升级逻辑。

当前本机的 `~/.codex/AGENTS.md` 已安装旧提醒片段。实施时先使用修改前的脚本安全
卸载该受管片段，再修改仓库代码，最后使用新脚本安装 `opc-skills-reminder` 片段。
这是一次性的本机状态收口，不进入安装器的长期兼容契约。

### 3.4 当前文档

README 只介绍 `$opc-skills`，删除双入口安装、旧入口升级和兼容 FAQ。目录树只展示
`adapters/codex/opc-skills/`。

2026-08-14 已完成的迁移设计、实施计划和验证记录属于历史证据，保留其中对
`$zx-skills` 的描述，不把历史事实重写成当前状态。

## 4. 测试设计

先修改测试并确认其因现有双入口实现而失败，再修改生产文件：

- 品牌契约断言当前适配器、README、提醒模板中只存在 OPCSkills 入口；
- POSIX 安装器覆盖单入口安装、重复安装、状态、卸载、冲突保护、回滚和回退目录；
- PowerShell 安装器覆盖同一组单入口行为和链接安全边界；
- POSIX 与 PowerShell 提醒测试断言新标记的安装、状态、覆盖迁移、异常标记保护和卸载；
- 全部 Python、Shell、PowerShell、YAML 解析和 `git diff --check` 回归通过；
- 本机最终只存在 `~/.agents/skills/opc-skills`，不存在 `~/.agents/skills/zx-skills`。
- 本机全局 Codex 指令只存在 `opc-skills-reminder` 受管片段，其中提示命令为
  `$opc-skills 总结一下当前链路`。

## 5. 完成标准

- Codex `/skills` 只发现 `opc-skills` 仓库入口；
- 当前运行代码、模板、README 和非历史测试不再包含 `$zx-skills` 兼容入口；
- `zx-*` 自定义 Skill、`zxsi-*` 和 `zpo-*` 保持可用；
- 安装与卸载不会覆盖或递归删除用户自有路径；
- 工作树变更范围只包含本设计定义的清理内容。
