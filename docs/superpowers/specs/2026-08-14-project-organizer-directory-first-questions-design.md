# ZX Project Organizer 目录优先提问设计

## 背景

Codex 任务 `019ffe40-d3bf-76c2-b96e-2badc88040a0` 使用 `zx-project-organizer` 创建“AI获客”项目工作目录，共经历约 16 个问题。流程先询问项目用途、目标用户和阶段，又分别确认前端存在性、应用名称、后端存在性、后端形态以及三个应用的代码骨架，最后才确认目标目录。最终提案只报告目录数量和三个应用路径，没有把完整项目目录树展示给用户。

根因来自当前 Skill 契约：`new_project_stages` 将产品发现、目录决策和代码初始化串成线性必答流程；`scaffolding` 强制逐应用单独询问；输出虽包含 `proposed_structure`，但没有要求最终用户答复必须直接渲染该字段。

本规格在“全新项目提问顺序、代码骨架确认粒度和最终提案展示”范围内取代
[`2026-08-14-project-organizer-guided-initialization-design.md`](2026-08-14-project-organizer-guided-initialization-design.md)
的对应规则；原设计中的独立应用边界、命名、接口规范归属、存量项目保护和提案安全门禁继续有效。

## 目标

将全新项目初始化改为“目录优先”的条件式引导：只让会改变路径、文件、代码生成、基础设施配置或 Git 状态的决定阻塞目录提案；所有问题和选项支持数字回答；任何可执行提案都必须先展示完整目录树。

本设计不改变存量项目只读审计、迁移确认、提案哈希、路径安全和 apply 门禁。

## 后续人工裁决

- **人工裁决 1**：原计划把前五个 stage 写成固定列表，但 `scaffold-details` 是条件阶段。接受的顺序是
  `project-location` → `structure-profile` → `applications` → `scaffold-strategy`，仅当选择生成代码时插入
  `scaffold-details`，然后进入 `infrastructure`。因此不能再用固定的第五项断言跳过条件阶段。
- **人工裁决 2**：monolith、API Gateway 和 BFF 的显式区分继续保留，但它们不是后端架构的穷举。
  稳定 taxonomy 同时支持 `backend-application`、`background-worker`、`scheduled-job` 和 `data-sync`；
  每种 `application_type` 必须绑定唯一 canonical role 和路径语义，前端不得携带后端专用 type。

后端稳定语义如下：

| application_type | canonical role | 路径语义 |
| --- | --- | --- |
| `backend-monolith` | `单体后端` | `<project-slug>` 或 `<project-slug>-api` |
| `backend-application` | `独立后端应用` | `<project-slug>-<responsibility>`，覆盖一般独立服务或微服务 |
| `api-gateway` | `API 网关` | `<project-slug>-gateway` |
| `bff` | `BFF` | `<project-slug>-<terminal>-bff` |
| `background-worker` | `后台任务` | `<project-slug>-worker` |
| `scheduled-job` | `定时任务` | `<project-slug>-scheduler` |
| `data-sync` | `数据同步` | `<project-slug>-data-sync` 或 `<project-slug>-data-sync-job`；保留公开示例 `ai-huoke-data-sync-job` |

其中 `role` 只表示与 `application_type` 精确绑定的 canonical role，不承载参数化路径语义。
`backend-application` 在 input `applications` 和 output `application_plan` 都必须另行提供非空
`responsibility`，并用于 `<project-slug>-<responsibility>`；BFF 则必须另行提供非空
`terminal`，并用于 `<project-slug>-<terminal>-bff`。两个字段都不得塞入 `role`。

应用问题仍最多展示 8 个选项，并根据当前已确认上下文选择相关项；一轮无需展示整个 catalog。技术栈未知或
`all-skip` 时，不从 `application_type` 推断 Go、Python、Node.js 或其他语言。

## 第一性原理

一个问题只有会改变下列至少一项时，才属于项目目录初始化的阻塞问题：

1. `project_root`、显示名称或目录标识。
2. `structure_profile` 或稳定文档边界。
3. 前后端独立应用的数量、名称、终端、职责和路径。
4. `creation_plan` 中是否生成代码或配置文件。
5. 是否创建已确认的基础设施配置。
6. 是否执行 `git init`。

项目用途、目标用户和项目阶段可以丰富 README 或帮助其他产品 Skill，但它们本身不决定上述六项。用户主动提供时可以作为已确认背景使用；缺失时登记为 `unknown` 或省略，不得阻塞目录提案，也不得由 Skill 猜测。

## 目录优先问题流

### 必答问题

普通新项目最多包含以下六类必答问题，按照依赖顺序处理：

1. **项目位置与标识**：确认目标目录、显示名称和 `project_slug`。如果用户表达和只读文件系统证据足以形成一组安全建议，可以用一个推荐选项同时确认三者；不能把当前 ZXSkills 工作区当成目标项目。
2. **结构策略**：选择 `zx-full-delivery`、`adaptive` 或 `custom`。
3. **应用目录**：一次确认本次需要的全部前端和后端独立应用；允许数字多选和自定义名称。不得先问“是否有前端”再另问前端列表，也不得先问“是否有后端”再另问后端列表。
4. **代码骨架策略**：先批量选择“全部只建目录”“全部生成”或“选择部分生成”。只有选择全部或部分生成时，才继续收集对应应用的技术栈事实。
5. **基础设施**：只有基础设施选择会导致本次创建目录或配置时才成为阻塞问题；推荐项固定为“暂不确认基础设施”。选择暂不确认时不得创建数据库、缓存、消息队列或定时任务目录和配置。
6. **Git**：确认是否把 `git init` 纳入当前提案。

问题数量不是固定目标。已在用户请求中明确的事实直接进入 `confirmed`，不重复询问；只有条件触发时才追加问题。

### 条件问题

- `adaptive` 缺少稳定文档边界时，追加一个文档范围问题；`zx-full-delivery` 已包含完整文档边界，不再询问。
- 应用清单不明确时，使用一个数字多选问题收集前端终端和后端应用；用户选择“暂不创建应用目录”后不再追问应用。
- “全部生成”或“选择部分生成”才询问代码骨架详情；技术栈按需要生成的应用收集，可以在一个问题中展示多个应用的编号，不为相同的 `skip` 决策逐应用重复提问。
- 用户明确要求创建某类基础设施目录或配置时，才继续询问具体类型和技术选型。
- 自定义结构不完整或存在路径歧义时，只询问影响解析的最小问题。

### 不再阻塞的问题

- 项目主要解决什么问题。
- 项目主要服务哪些用户或业务角色。
- 项目处于调研、原型、MVP 还是正式开发阶段。

这些内容不再出现在目录初始化的必答阶段。Skill 可以在最终 `follow_ups` 中建议后续使用产品类 Skill 完善项目定位、用户研究和阶段规划，但不能因此拒绝生成目录提案。

## 数字交互契约

每个 `guided_question` 必须具有稳定问题 ID、递增的数字序号和数字选项：

```text
问题 2：采用哪种目录结构？

1. ZX 完整交付结构（推荐）
2. 自适应最小结构
3. 自定义目录树

回复数字即可，例如：1
```

具体规则：

- 单选允许回复 `1`、`2` 等数字。
- 多选允许回复 `1,3,5`，顺序不表示优先级。
- 自定义内容可以直接输入文字，不要求先输入特殊数字。
- 数字只映射当前任务中最新、尚未解决的 `guided_question`；问题已解决、上下文丢失或同时存在多个候选问题时必须返回 `needs-input`，不得猜测。
- `guided_question` 输出增加 `sequence`、`selection_mode` 和 `answer_hint`；每个 option 增加 `number`。
- 单选问题保留 2～4 个选项；应用数字多选问题最多允许 8 个选项，以容纳常见终端、后端和“暂不创建”。
- `recommendation_updates` 支持 `selected_option_numbers`；内部仍保存稳定 option id，数字只作为当前问题的交互别名。
- 用户回复推荐数字表示明确接受当前推荐，可以进入 `accepted/confirmed`；不影响其他问题或候选事实。

## 应用和代码骨架交互

应用目录问题必须一次展示当前完整候选清单，并支持数字多选。例如：

```text
问题 3：本次创建哪些应用目录？可多选。

1. Web 管理后台
2. H5
3. 微信小程序
4. iOS
5. Android
6. 单体后端
7. 暂不创建应用目录（推荐：应用边界尚未明确时）
```

已确认应用进入 `application_plan` 后，代码骨架先问一次批量策略：

```text
问题 4：这些应用如何处理代码骨架？

1. 全部只创建目录，暂不生成代码（推荐）
2. 全部生成可运行代码骨架
3. 选择部分应用生成
```

选择 1 时，所有本轮新应用写入 `generate=false、status=skipped`，不再逐应用重复询问。选择 3 时追加一个应用编号多选问题；只对选中的应用收集运行时、框架、版本、启动和测试信息。存量应用仍然禁止重新生成或覆盖。

## 基础设施策略

基础设施不是目录初始化的隐式要求。其推荐选项固定为：

```text
1. 暂不确认基础设施（推荐）
```

其他选项只能根据当前已确认需求列出，例如数据库、缓存、消息队列、定时任务或自定义组合。不得根据“MVP”“AI 项目”或业务用途自动推荐数据库、定时任务等技术组件。选择暂不确认后，将其记录为延后决策，不创建任何相关目录或配置，也不影响完整目录提案。

## 最终提案展示契约

当 `result=awaiting-confirmation` 或 `migration-proposed` 时，面向用户的最终答复必须按以下顺序展示：

1. `proposed_structure` 的完整目录树，放在 `text` 代码块中。
2. 完整 migration/creation map：存量项目展示全部 `migration_map`，新项目展示全部 `creation_plan`。
3. 完整 planned file contents/commands：文件项展示最终全文，骨架项展示全部命令。
4. 风险与校验。
5. 具体 `proposal_id`。
6. 专用 `proposal_actions` 字段的数字操作选项，必须是最后一段：`1. 确认执行`、`2. 返回修改`、`3. 放弃提案`。

这是用户可见渲染合同，不依赖 JSON/YAML object 的键顺序。提案操作文案只能出现在最后的
`proposal_actions`；`summary`、`follow_ups` 和任何更早字段都不得提前包含确认、修改或放弃动作。

目录数量、路径数量和 exact-match 统计只能作为辅助信息，不能替代完整目录树。完整树必须包含所有基础目录、应用目录和本次确认的规范目录；不能使用省略号或“其余目录同模板”。

用户在同一任务中回复 `1` 时，适配器把它映射为对当前已展示 `proposal_id` 的确认，再按原有哈希协议构造 `confirmation` 和 `approved_proposal`。如果当前提案不可唯一定位、载荷缺失或重新计算不匹配，则返回 `blocked`，不得执行。回复 `2` 回到最早受修改影响的问题；回复 `3` 放弃当前提案且不写文件。
如果同时存在两个或更多仍可识别的提案，纯数字 `1` 必须返回 `needs-input` 或 `blocked`，不选择任何提案，也不得写入任何授权根目录。

## 文件内容策略

缺少项目用途、目标用户或阶段时，基础文件只能陈述已确认事实，例如项目名称、目录导航和“产品定位尚未确认”。不得生成带占位符的业务描述，也不得根据项目名猜测具体用户、流程、权限或技术架构。

`creation_plan` 继续保存文件的完整内容和 SHA-256，确保提案绑定不变；用户可见答复重点展示完整目录树和文件清单，不用目录数量摘要代替结构。

## 存量项目兼容

存量项目继续先做只读审计并输出事实来源、迁移映射、引用影响、验证和回滚方式。数字问题和完整结构展示同样适用，但不得把新项目的批量代码骨架策略用于已有应用。已有应用的 `scaffold_plan` 保持 `generate=false、status=skipped`。

## 验收标准

- “创建项目工作目录”不再强制询问项目用途、目标用户和阶段。
- 目标目录在结构、应用和代码决策之前确认。
- 所有问题显示数字序号；所有选项有数字，单选和多选均可只回复数字。
- 数字只作用于最新未解决问题，不能跨问题或跨提案复用。
- 前后端存在性和应用列表不再拆成四个固定问题。
- 后端 input 和 output 都要求合法 `application_type` 与其 canonical role 精确匹配；前端拒绝后端专用 type。
- 一般独立服务、后台任务、定时任务和数据同步应用都能用稳定类型表达，且不推断技术语言。
- “全部只创建目录”可以一次应用到全部新应用，不再逐应用重复询问。
- 基础设施推荐为“暂不确认基础设施”，且不根据 MVP 或业务用途推断技术组件。
- `zx-full-delivery` 不再询问已经由模板确定的文档边界。
- `awaiting-confirmation` 和 `migration-proposed` 的用户答复必须展示无省略的完整目录树。
- 用户可以用数字 `1/2/3` 确认、返回修改或放弃当前提案，同时保留原有 proposal-id 哈希门禁。
- 原有 custom 精确结构、局部事实确认、存量应用保护、提案绑定和 apply 安全测试继续通过。
