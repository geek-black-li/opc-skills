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

## 动态分类

- 优先匹配 manifest 中已有分类；名称不同不代表必须新建，按 scope 和最终交付责任判断。
- 所有现有分类都不匹配时，生成完整 `new_category` 方案，正式编号由写入时按 `07-` 起的
  `next-unused` 规则确定。
- Self-Improve 和外部导入 stage 只提出建议，不创建分类。creator、external fork 或用户确认后的
  approve-original / approve-customized 才能同步更新 manifest，并在 custom/external 两侧生成
  分类目录与 `_readme.md`。
- 分类注册与 Skill 写入必须作为一次操作完成；失败时只回滚本次新增内容。

## 意图路由

| 用户表达 | 执行 |
| --- | --- |
| “安装/导入一个 Skill，地址是…” | 读取 `builtin/skill-import-external.yaml`，执行 `stage` |
| “确认原样入库…” | 读取导入评估，执行 `approve-original` |
| “确认改造入库…” | 读取导入评估，执行 `approve-customized` |
| “丢弃这个外部 Skill…” | 读取导入评估，执行 `discard` |
| “总结当前链路/这次工作” | 读取 `builtin/skill-selfimprove.yaml`，只分析总结 |
| “总结并沉淀/总结并优化/做成 Skill” | 只执行 self-improve，输出提案并停止，等待用户确认 |
| “确认提炼 `<proposal_id>`” | 校验当前任务中的提案与 ID，匹配后再路由 creator 或 editor |
| “放弃提炼 `<proposal_id>`” | 结束该提案，不写入仓库 |
| “新建一个 Skill…” | 以 `invocation_source=direct` 读取 `builtin/skill-creator.yaml` |
| “修改/优化某个 Skill…” | 以 `invocation_source=direct` 读取 `builtin/skill-editor.yaml` |
| “使用/调用 `<skill-id>` …” | 扫描正式 Skill，按唯一 id 加载并执行该 Skill |
| “确认执行项目结构提案 `<zpo-id>`” | 找到原提案，以 `action=apply` 和匹配 confirmation 再次执行原 Skill |
| “放弃项目结构提案 `<zpo-id>`” | 结束该提案，不修改目标项目 |
| “有哪些 Skill/仓库状态” | 按 manifest 扫描正式 Skill 并简要列出 |

如果一句话同时包含“总结”和“沉淀/优化”，只执行只读 Self-Improve，不得在同一轮继续创建或修改。
无法可靠区分时选择只读分析。只有不依赖 Self-Improve、直接且明确的“新建/修改 Skill”请求才使用
`invocation_source=direct`。

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

用户明确说“沉淀”“落地”“做成 Skill”或“总结并优化”时，也必须先停在分析提案：

- `no-action`：说明项目独有、证据不足或已有能力已经覆盖，不强行创建文件。
- `create-skill` / `update-skill`：先向用户说明 `哪些内容可以提炼`、`为什么值得提炼`、跨项目场景、
  证据、项目独有排除项、确认后具体改动和风险；返回 `result=awaiting-confirmation`、`proposal_id`
  与完整 creator/editor 参数。
- 同一轮不得调用 creator/editor，不得因为用户最初说了“沉淀”就把它解释成对尚未展示提案的确认。
- 最后给出两条可复制指令：
  - `$zx-skills 确认提炼 <proposal_id>`
  - `$zx-skills 放弃提炼 <proposal_id>`

用户后续确认时：

1. 在当前任务上下文中找到完全匹配的 `proposal_id`；找不到时停止，要求用户粘贴原提案，不凭印象重建。
2. 按 Self-Improve 规则对当前 creator/editor 参数重新计算 `proposal_id`；确认不匹配或参数已改变时返回
   `blocked`，重新展示新提案等待再次确认。
3. `create-skill` 路径把原参数连同 `invocation_source=self-improve` 及
   `self_improve_confirmation={confirmed:true, proposal_id, action:create-skill}` 交给 creator。
4. `update-skill` 路径同理传给 editor，action 为 `update-skill`。
5. 写入后返回真实验证结果。`放弃提炼` 只结束本提案，不删除任何已经存在的文件。

## 业务 Skill 提案确认

正式业务 Skill 可以定义自己的提案确认协议。当前 `zx-project-organizer` 在 initialize/reorganize 的
`action=propose` 阶段只读检查，返回 `result=awaiting-confirmation` 或 `migration-proposed` 以及 `zpo-*`
`proposal_id`；总入口必须原样展示提案和以下两条指令：

- `$zx-skills 确认执行项目结构提案 <zpo-proposal_id>`
- `$zx-skills 放弃项目结构提案 <zpo-proposal_id>`

收到确认后，在当前任务上下文中找到原始 mode、project_root、context、`proposal_payload` 和
`proposal_id`，以 `action=apply`、
`approved_proposal={proposal_id:<zpo-id>, canonical_payload:<原 proposal_payload>}` 和
`confirmation={confirmed:true, proposal_id:<zpo-id>}` 再次调用 `zx-project-organizer`。不得重新生成或润色
已确认提案。Skill 会从 canonical payload 重新计算 ID，并重新检查工作区是否仍适合执行；确认不匹配、
原载荷不可读取、哈希不一致或目标状态已变化时返回 `blocked`，不得猜测或沿用不安全的旧计划。
`放弃项目结构提案` 不执行 apply，也不删除任何已有内容。

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
$zx-skills 确认提炼 zxsi-0123456789abcdef
$zx-skills 放弃提炼 zxsi-0123456789abcdef
$zx-skills 使用 zx-project-organizer，帮我审计当前项目结构
$zx-skills 确认执行项目结构提案 zpo-0123456789abcdef
$zx-skills 放弃项目结构提案 zpo-0123456789abcdef
$zx-skills 优化 zx-testing-api-regression-planning，补充异步消息失败场景
$zx-skills 列出我的测试类 Skills
```
