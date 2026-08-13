---
name: zx-skills
description: Use when the user explicitly invokes ZXSkills to import or install a third-party skill, summarize the current delivery workflow, extract reusable experience, create or update a personal skill, list repository skills, or check repository status.
---

# ZXSkills

把 `$zx-skills` 作为 ZXSkills 仓库的唯一入口。接受自然语言，不要求用户填写内部 YAML 参数；根据意图读取并执行对应 builtin Skill。

## 定位仓库

1. 获取本 `SKILL.md` 的真实路径；如果它是符号链接，先解析链接目标。
2. 从真实路径向上查找 `skill-manifest.yaml`，将其目录作为 `ZXSKILLS_ROOT`。
3. 若未找到，再检查用户明确提供的仓库路径。仍未找到时停止，并要求用户提供 ZXSkills 本地路径。
4. 读取 `skill-manifest.yaml` 后再执行任何路由。不得把 `skills-temp-inbox` 当作正式 Skill 来源。

## 个人命名空间

- `skills-custom` 中个人原创或深度改造 Skill 的 id 必须以 `zx-` 开头。
- 新建、自优化建议、第三方改造入库和 external fork 均遵守 manifest 的 `custom_skill_id_pattern`。
- 用户只描述能力、未指定 id 时，按主要分类自动生成 `zx-<domain>-<capability>` 小写横杠 id；
  检查全仓库唯一性后再交给 creator，不要求用户整理内部命名参数。
- 保持原样的第三方 Skill 使用 external id，不得占用 `zx-`；第三方 source 原件中的名称保持不变。

## 意图路由

| 用户表达 | 执行 |
| --- | --- |
| “安装/导入一个 Skill，地址是…” | 读取 `builtin/skill-import-external.yaml`，执行 `stage` |
| “确认原样入库…” | 读取导入评估，执行 `approve-original` |
| “确认改造入库…” | 读取导入评估，执行 `approve-customized` |
| “丢弃这个外部 Skill…” | 读取导入评估，执行 `discard` |
| “总结当前链路/这次工作” | 读取 `builtin/skill-selfimprove.yaml`，只分析总结 |
| “总结并沉淀/做成 Skill” | 先执行 self-improve，再按唯一结论路由 creator 或 editor |
| “新建一个 Skill…” | 读取 `builtin/skill-creator.yaml` |
| “修改/优化某个 Skill…” | 读取 `builtin/skill-editor.yaml` |
| “有哪些 Skill/仓库状态” | 按 manifest 扫描正式 Skill 并简要列出 |

如果一句话同时包含多个意图，按依赖顺序执行。例如“总结并沉淀”先分析，再创建或更新。无法可靠区分时选择只读的总结分析，并提出一个最小问题。

## 第三方 Skill

用户说“安装”时，不把链接直接写入正式目录。必须：

1. 按 `skill-import-external.yaml` 的 `stage` 流程保存到 `skills-temp-inbox`。
2. 只做静态来源、许可、兼容性和安全评估，不执行第三方代码、脚本、安装器或构建。
3. 返回简短结论：用途、风险等级、关键发现、建议分类、`inbox_id`。
4. 明确给出下一句可复制指令：
   - `$zx-skills 确认原样入库 <inbox_id>`
   - `$zx-skills 确认改造入库 <inbox_id>，要求：...`
   - `$zx-skills 丢弃 <inbox_id>`
5. 在用户发出与 `inbox_id` 匹配的确认前，不进入 `skills-external` 或 `skills-custom`。

## 总结与沉淀

“总结当前链路”默认只读，不修改 ZXSkills。读取当前任务的目标、过程、产物、失败修正和验证证据，执行 `skill-selfimprove.yaml`，用以下顺序简要输出：

1. `链路总结`：实际完成的关键步骤。
2. `可复用点`：能够跨项目复用的判断、流程或模板。
3. `评估结论`：固定为 `no-action`、`create-skill` 或 `update-skill`，并说明理由。
4. `下一步`：给出一条可复制的 `$zx-skills ...` 指令。

用户明确说“沉淀”“落地”或“做成 Skill”时：

- self-improve 返回 `create-skill`：把完整 `creator_parameters` 交给 `skill-creator.yaml` 执行。
- 返回 `update-skill`：把完整 `editor_parameters` 交给 `skill-editor.yaml` 执行。
- 返回 `no-action`：不强行创建文件，说明原因。

## 输出和变更

- 优先直接执行用户明确授权的只读或可恢复操作，不让用户整理内部参数。
- 写入后校验 YAML、唯一 id、分类路径、manifest 可发现性和残留占位符。
- 不自动提交或推送 Git，除非用户明确要求。
- 保留任务范围外的用户文件和未提交修改。
- 结果保持简短：完成了什么、文件在哪里、验证结果、需要用户决定什么。

## 示例

```text
$zx-skills 帮我安装一个 Skill，地址是 https://example.com/skill
$zx-skills 总结一下当前链路
$zx-skills 总结当前链路并沉淀成 Skill
$zx-skills 优化 zx-testing-api-regression-planning，补充异步消息失败场景
$zx-skills 列出我的测试类 Skills
```
