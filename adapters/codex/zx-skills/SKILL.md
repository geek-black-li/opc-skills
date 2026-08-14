---
name: zx-skills
description: Use when the user explicitly invokes ZXSkills to execute a formal local skill, import or install a third-party skill, summarize the current delivery workflow, extract reusable experience, create or update a personal skill, list repository skills, or check repository status.
---

# ZXSkills

把 `$zx-skills` 作为 ZXSkills 仓库的唯一入口。接受自然语言，不要求用户填写内部 YAML 参数；根据意图读取并执行对应 builtin Skill。

## 定位仓库

1. 获取本 `SKILL.md` 的真实路径；如果它是符号链接，先解析链接目标。
2. 从真实路径向上查找 `skill-manifest.yaml`，将其目录作为 `ZXSKILLS_ROOT`。
3. 若未找到，再检查用户明确提供的仓库路径。仍未找到时停止，并要求用户提供 ZXSkills 本地路径。
4. 读取 `skill-manifest.yaml` 后再执行任何路由。不得把 `skills-temp-inbox` 当作正式 Skill 来源。

## 个人命名空间

- `skills-custom` 中个人原创或深度改造 Skill 的 id 固定采用 `zx-<category>-<function>`。
- `zx-` 是个人命名空间；`category` 必须使用目标 manifest 分类的 `skill_token`；`function` 表示
  主要功能，优先使用一个通俗单词（如 `spec`、`check`、`plan`），确有必要时最多两个单词。
- 六个核心分类的 token 固定为：产品 `product`、UI `ui`、研发 `dev`、测试 `test`、运维 `ops`、
  项目管理 `project`。例如 `zx-ui-spec`、`zx-ui-check`、`zx-project-risk`。
- 新建、自优化建议、第三方改造入库和 external fork 均遵守 manifest 的 `custom_skill_id_pattern`。
- 用户只描述能力、未指定 id 时，先确定主要分类，再自动推荐短、直观的 id；检查分类 token、功能段
  长度和全仓库唯一性后再交给 creator，不要求用户整理内部命名参数。
- 用户给出的 id 不符合规则时，先解释问题并给出推荐名；不得静默沿用过长名称或错误分类段。
- 保持原样的第三方 Skill 使用 external id，不得占用 `zx-`；第三方 source 原件中的名称保持不变。

## 动态分类

- 优先匹配 manifest 中已有分类；名称不同不代表必须新建，按 scope 和最终交付责任判断。
- 所有现有分类都不匹配时，生成完整 `new_category` 方案，正式编号由写入时按 `07-` 起的
  `next-unused` 规则确定；方案必须同时包含全仓库唯一的单词型 `skill_token`。
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
| “按 ZX 完整结构初始化项目” | 调用 `zx-project-organizer`，设置 `structure_profile=zx-full-delivery` |
| “按项目实际情况初始化” | 调用 `zx-project-organizer`，设置 `structure_profile=adaptive` |
| “按以下目录初始化…” | 调用 `zx-project-organizer`，设置 `structure_profile=custom` 并原样传入目录树 |
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
`proposal_id`；总入口必须原样展示提案，并且只在所有提案材料完整展示后，用最后一段
`proposal_actions` 呈现确认、修改和放弃操作。

收到确认后，在当前任务上下文中找到原始 mode、project_root、context、`proposal_payload` 和
`proposal_id`，以 `action=apply`、
`approved_proposal={proposal_id:<zpo-id>, canonical_payload:<原 proposal_payload>}` 和
`confirmation={confirmed:true, proposal_id:<zpo-id>}` 再次调用 `zx-project-organizer`。不得重新生成或润色
已确认提案。Skill 会从 canonical payload 重新计算 ID，并重新检查工作区是否仍适合执行；确认不匹配、
原载荷不可读取、哈希不一致或目标状态已变化时返回 `blocked`，不得猜测或沿用不安全的旧计划。
`放弃项目结构提案` 不执行 apply，也不删除任何已有内容。

完整提案门槛：必须依序展示完整目录树、完整 migration/creation map、完整 planned file contents/commands、风险与校验、
具体 proposal_id，然后才在 `proposal_actions` 最后一段展示 `1=确认当前 proposal_id`、`2=返回修改`、`3=放弃`。数量摘要不能替代这些内容，目录树不得以
省略或模板说明代替。数字 `1` 仅在当前任务中能唯一定位已显示的 `proposal_id`、保留的原始
`proposal_payload` 可读取且重新计算的哈希匹配时，才构成执行授权；否则返回 `blocked` 或 `needs-input`，
不调用 apply。数字确认仍按原 proposal payload 构造 apply 参数，不得用数字重新生成提案。这是用户可见渲染合同，
不得依赖 JSON/YAML object 的键顺序；`summary`、`follow_ups` 和其他早于 `proposal_actions` 的字段都不得包含提案操作文案。

若同一任务上下文中同时存在多个仍可识别的提案，纯数字 `1` 必须返回 `needs-input` 或 `blocked`，
不得选择任一提案、不调用 apply，也不得对任何授权根目录写入。

## 引导式项目创建与整理

用户可以直接说：

- `$zx-skills 使用 zx-project-organizer，引导我创建一个全新项目`
- `$zx-skills 使用 zx-project-organizer，引导我整理现有项目`

全新项目传 `mode=initialize、workflow_mode=new-project`；存量项目整理传
`mode=reorganize、workflow_mode=existing-project`；只要求查看问题时传
`mode=audit、workflow_mode=existing-project`。用户没有明确说明时传 `workflow_mode=auto`，让 Skill 根据
用户说明和只读工作区证据判断。有歧义时先询问，不因空工作区自动否定用户提到的历史项目。

引导过程必须遵守：

1. 一次只问当前最早、会影响后续设计的一个问题。
2. 每个问题都必须提供推荐选项和推荐理由，同时说明其他选项的影响并允许自定义。
3. 推荐不等于确认；只有用户明确接受、修改或自定义的当前问题才能更新，未提及推荐继续保持 proposed。
4. 目录优先的六类决策依次是：项目目录位置、名称和英文标识；结构策略；应用目录；批量代码骨架策略；
   基础设施；Git 初始化。项目用途、目标用户和阶段不阻塞目录提案，只在确实影响当前目录或用户主动要求时
   作为可选补充问题。
5. 代码骨架先作一次批量选择：`全部只创建目录`（推荐）、全部生成，或选择部分应用生成；只有选择生成的
   应用才继续询问技术栈、版本、包管理器或运行测试命令。
6. 基础设施未知时推荐 `暂不确认基础设施`，不生成推测性数据库、缓存、消息队列或定时任务配置。
7. 项目英文标识可以推荐，但用户确认前不得自动把中文名称转换为拼音并落盘。

### 数字答复路由

- 用户只回复数字时，只映射当前任务中最新且唯一的 `guided_question`；每个问题的选项数字必须唯一且连续。
- 仅在上述最新唯一问题上下文中，先 trim 整体及逗号两侧的 ASCII 空白：` 1 ` 视为 `1`，`1, 3,1`
  归一化为有序去重的 `[1,3]`。单选数字转换为 `selected_option_numbers=[n]`；多选逗号数字转换为有序去重数组。
- 空 token、非数字、越界数字、问题已经解决、上下文缺失或存在多个未解决问题时返回 `needs-input`，不得猜测。
- `回复数字即可` 只适用于上述当前问题；最终提案的 `1`、`2`、`3` 按提案确认门禁路由，不能当作普通问题答案。

应用结构统一为 `development/frontend/apps` 和 `development/backend/apps`。前端使用项目标识加终端短名，
例如 `ai-huoke-web-admin`、`ai-huoke-wx-mini`、`ai-huoke-uniapp`；单体后端允许 `ai-huoke` 或
`ai-huoke-api`，多后端应用使用职责后缀。不得创建 `services`、`packages`、`libs` 或 `shared-code`，
应用之间只能通过 API、RPC 或消息协议协作；接口规范跟随提供方应用。

applications 问题涉及后端时必须明确区分 `backend-monolith`（承载业务能力的单体后端）、API Gateway
（网关边界）和 BFF（面向特定前端的聚合层）；Gateway/BFF 不等同业务单体，禁止使用“单一后端 API”代表单体。
用户选择 monolith 后，`application_plan` 必须记录 `application_type=backend-monolith`、`role=单体后端`，
不能靠目录数量推断。单体是部署和业务边界，不是语言；技术栈未知且 `scaffold_strategy=all-skip` 时，
不得询问或推断 Go、Python、Node.js。

稳定后端类型还包括 `backend-application`（一般独立服务或微服务）、`background-worker`、`scheduled-job` 和
`data-sync`；每类 `application_type` 必须绑定 reference 中唯一的 canonical role 和路径语义。applications 问题
按当前已确认上下文每轮最多 8 个相关选项，不要求展示整个 catalog。任何后端 application_type 都不得用于推断技术语言。

`backend-application` 的 `role` 必须精确保持 canonical role“独立后端应用”，具体职责单独记录在非空
`responsibility`，并用于 `<project-slug>-<responsibility>` 命名。BFF 的 `role` 必须精确保持“BFF”，服务终端
单独记录在非空 `terminal`，并用于 `<project-slug>-<terminal>-bff` 命名。不得把 `responsibility` 或
`terminal` 塞入 canonical `role`。

代码骨架采用批量优先：先让用户在“全部只创建目录”、全部生成和选择部分应用生成之间决定；选择部分应用
时才用多选数字确认应用。一个应用被确认生成不代表其他应用也生成，已有应用一律不得重新生成或覆盖。
技术栈信息不足时继续提问，不猜测框架。

初始化时必须明确结构策略：

- `zx-full-delivery`：使用 ZX 个人完整交付结构，预建产品、设计、测试、项目管理、
  `development/frontend/apps|backend/apps|experiments` 和根目录 `research/sources|assets`。
- `adaptive`：只按当前项目已确认事实生成最小结构。
- `custom`：用户提供完整目录树，路径、编号、中文名称和层级均按原文执行。

用户只说“初始化项目”且当前上下文没有已确认策略时，先用一句话让用户选择，不能默认套用轻量结构。
用户回复只修正某些事实时，只更新被明确提及的事实；不得把整组未提及候选项视为确认。custom 或
zx-full-delivery 提案必须展示 `structure_comparison`，确认 missing、additional、renamed_or_moved 均为空。最终
确认前必须展示完整目录树；数量统计不能替代完整目录树，也不得以“其余目录同模板”或省略号代替。

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
$zx-skills 使用 zx-project-organizer，引导我创建一个全新项目
$zx-skills 使用 zx-project-organizer，引导我整理现有项目
$zx-skills 使用 zx-project-organizer，按 ZX 完整结构初始化当前项目
$zx-skills 使用 zx-project-organizer，按项目实际情况自适应初始化
$zx-skills 确认执行项目结构提案 zpo-0123456789abcdef
$zx-skills 放弃项目结构提案 zpo-0123456789abcdef
$zx-skills 优化 zx-test-regression，补充异步消息失败场景
$zx-skills 列出我的测试类 Skills
```
