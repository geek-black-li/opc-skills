# ZXSkills：全栈 OPC 本地 Skills 仓库

ZXSkills 用于沉淀一个全栈 OPC 从需求到交付全过程中的可复用 AI 执行能力。仓库按产品、UI 设计、全栈与架构、测试、运维发布、项目管理六个角色域组织，不绑定某一种编程 AI 产品。

仓库本身是一套 Skill 集合：AI 工具或适配器读取根目录的 [`skill-manifest.yaml`](skill-manifest.yaml)，按目录扫描规则发现 `builtin`、`skills-external` 和 `skills-custom` 中的 Skill。新增或删除业务 Skill 时不需要手工维护索引。

> 安全边界：任何网络下载或外部导入的 Skill 都必须先进入 `skills-temp-inbox`。该目录被 manifest 全局排除，未经静态评估和用户明确确认，不得进入 `skills-external` 或 `skills-custom`。

## 目前提供什么

当前版本提供一套可持续积累个人 Skills 的仓库框架，以及一个 Codex 原生总入口 `$zx-skills`：

| 能力 | 用途 |
| --- | --- |
| 第三方 Skill 导入 | 下载内容先隔离到暂存箱，完成来源、许可、兼容性和安全评估后再确认入库 |
| 当前链路总结 | 总结刚完成的需求、开发、测试或发布过程，识别可复用经验 |
| Skill 创建 | 将确认可复用的经验生成到 `skills-custom` |
| Skill 优化 | 对已有 Skill 做最小、可追溯的更新 |
| 仓库查看 | 按分类列出正式 Skill 和仓库状态 |

当前仓库**没有预置产品、设计、开发、测试等业务 Skill**。`skills-external` 和 `skills-custom` 初始为空；业务能力需要由使用者在实际项目中逐步沉淀或评估导入。

## 5 分钟开始使用 Codex

### 前置条件

- 已安装 Git。
- 已安装并能正常使用 Codex 桌面端、CLI 或 IDE 扩展。
- Codex 对本地仓库及 `~/.agents/skills` 具有读取权限。

### 第一步：克隆仓库

只想试用可以直接克隆；准备长期沉淀个人资产时，建议先在 Gitee Fork 本仓库，再克隆自己的 Fork。

```bash
git clone https://gitee.com/geek_black_li/zx-skills.git
cd zx-skills
```

每位使用者都在自己的本地副本中维护 `skills-custom` 和 `skills-external`。本地生成的内容不会自动回写原仓库；如需跨设备同步，请提交并推送到自己的 Fork 或私有远程仓库。

### 第二步：安装 `$zx-skills`

macOS / Linux：

```bash
bash scripts/install-codex.sh
```

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-codex.ps1
```

安装脚本会在用户级 Codex Skill 目录创建指向本仓库的链接：

```text
~/.agents/skills/zx-skills
```

脚本可以重复运行。若目标位置已经存在其他文件或指向其他仓库的链接，脚本会拒绝覆盖并提示人工处理。

### 第三步：验证安装

重新打开一个 Codex 任务，输入：

```text
/skills
```

确认列表中出现 `zx-skills`，然后执行：

```text
$zx-skills 查看仓库状态
```

Codex 原生 Skill 使用 `$skill-name` 显式调用；`/skills` 只用于查看 Skill 列表。如果安装后没有出现，先完全重启 Codex，再检查安装脚本输出的目标路径。

### 第四步（推荐）：开启项目节点完成提醒

如果希望 Codex 在完成并验证一个功能、方案、测试、问题排查或发布节点后，主动判断本次链路是否值得沉淀，可以安装 ZXSkills 的全局提醒规则。

macOS / Linux：

```bash
bash scripts/configure-codex-reminder.sh install
```

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\configure-codex-reminder.ps1 install
```

脚本把 [`templates/codex-agents-reminder.md`](templates/codex-agents-reminder.md) 中的受管片段追加到 Codex 全局指令文件：通常是 `~/.codex/AGENTS.md`；如果已经存在非空的 `~/.codex/AGENTS.override.md`，则写入当前生效的 override 文件。已有全局规则会被保留，重复运行不会产生重复片段。

这套配置的边界是：**只提醒，不自动执行**。Codex 只会在值得沉淀的重要节点结束时，在最终答复末尾建议运行：

```text
$zx-skills 总结一下当前链路
```

它不会自动调用 `$zx-skills`，也不会自动创建、修改、移动或删除 ZXSkills 仓库文件。普通问答、未完成或被阻塞的任务、微小修改、纯项目特有逻辑，以及本任务已经调用过 ZXSkills 时不应提醒。

Codex 会在任务启动时读取用户级全局指令，并让所有项目继承；具体加载顺序见 [Codex `AGENTS.md` 官方说明](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。配置完成后，新建一个 Codex 任务进行验证；无需把提醒规则复制到每个开发项目。

检查或关闭提醒：

```bash
bash scripts/configure-codex-reminder.sh status
bash scripts/configure-codex-reminder.sh uninstall
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\configure-codex-reminder.ps1 status
powershell -ExecutionPolicy Bypass -File .\scripts\configure-codex-reminder.ps1 uninstall
```

`uninstall` 只删除带有 `zx-skills-reminder` 标记的受管片段，不删除其他全局 Codex 指令。需要手动配置时，也可以打开模板并把完整标记片段合并到自己的全局 `AGENTS.md`；不要用模板覆盖原文件。

## 日常用法

只需要记住一个入口 `$zx-skills`，后面直接说自然语言：

```text
$zx-skills 帮我安装一个 Skill，地址是 https://example.com/skill
$zx-skills 总结一下当前链路
$zx-skills 总结当前链路并沉淀成 Skill
$zx-skills 新建一个 API 回归测试 Skill
$zx-skills 优化 api-regression-planning，补充异步消息失败场景
$zx-skills 列出我的测试类 Skills
```

总入口会自动判断意图并读取对应的 builtin Skill，不要求使用者填写内部 YAML 参数。

### 第三方 Skill 为什么需要再次确认

“帮我安装一个 Skill”第一次只会把第三方内容放入 `skills-temp-inbox` 并完成静态评估，不会直接加载或执行。评估完成后，Codex 会给出 `inbox_id`，再选择：

```text
$zx-skills 确认原样入库 <inbox_id>
$zx-skills 确认改造入库 <inbox_id>，要求：移除特定工具依赖
$zx-skills 丢弃 <inbox_id>
```

这是仓库的强制供应链安全边界，不能通过一句“直接安装”绕过。

## 更新、检查和卸载

更新仓库后，用户级链接会自动指向最新版，不需要重新安装：

```bash
git pull --ff-only
```

macOS / Linux：

```bash
bash scripts/install-codex.sh status
bash scripts/install-codex.sh uninstall
```

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-codex.ps1 status
powershell -ExecutionPolicy Bypass -File .\scripts\install-codex.ps1 uninstall
```

ZXSkills 入口和完成提醒是两项独立配置。`install-codex.* uninstall` 只删除 Codex 用户级入口；如果同时配置了完成提醒，再运行 `configure-codex-reminder.* uninstall`。两类卸载都不会删除本地 ZXSkills 仓库、`skills-custom`、`skills-external` 或暂存箱内容。

## 工具支持状态

| 工具 | 状态 | 使用方式 |
| --- | --- | --- |
| Codex 桌面端 / CLI / IDE 扩展 | 已提供原生入口 | 安装后使用 `$zx-skills` |
| Cursor | 尚未提供一键适配 | 可手动读取仓库文件；后续需要 `.cursor/rules` / commands 适配器 |
| Windsurf | 尚未提供一键适配 | 可手动读取仓库文件；后续需要对应规则或工作流适配器 |
| 其他本地 AI 工具 | 取决于工具能力 | 按 `skill-manifest.yaml` 和通用 YAML 契约实现适配 |

仓库采用通用源格式，但这不代表所有工具都能原生识别 `skill-manifest.yaml`。

## 开源许可状态

本仓库当前尚未提供 `LICENSE` 文件。公开可见不等于自动获得复制、修改或再发布许可；仓库维护者应在正式对外推广前选择并添加合适的开源或自定义许可证。

## 常见问题

### 输入 `$zx-skills` 没有触发

先运行安装脚本的 `status`，确认入口指向当前仓库；再完全重启 Codex，通过 `/skills` 检查。不要输入 `/zx-skills`，Codex 的 Skill 显式调用符号是 `$`。

### 更新后需要重新安装吗

不需要。安装使用目录链接，`git pull --ff-only` 后即指向最新内容；Codex 未刷新时重启即可。

### 我创建的个人 Skill 会上传到原作者仓库吗

不会。它们只写入你的本地副本。只有你主动执行 Git 提交和推送时才会进入配置的远程仓库，因此长期使用建议维护自己的 Fork 或私有仓库。

### 能否跳过第三方 Skill 的暂存评估

不能。所有外部内容必须先进入 `skills-temp-inbox`，只有匹配 `inbox_id` 的明确确认才能迁移到正式目录。

### 完成提醒会自动修改仓库吗

不会。提醒规则只让 Codex 判断是否应该建议你运行 `$zx-skills 总结一下当前链路`。只有你明确调用 `$zx-skills`，并在需要写入时给出沉淀或入库指令，仓库才会按相应工作流发生变更。

### 为什么不直接开启 ZXSkills 隐式调用

ZXSkills 同时包含导入、创建和修改能力。为避免宽泛的自动匹配触发写入流程，Codex 适配器保持 `allow_implicit_invocation: false`；全局 `AGENTS.md` 只承担轻量提醒，具体操作继续由使用者通过 `$zx-skills` 明确发起。显式/隐式调用机制见 [Codex Skills 官方说明](https://learn.chatgpt.com/docs/build-skills)。

## 设计目标

- 覆盖完整项目交付链路，而不是按某一款 AI 工具拆分目录。
- 用普通 YAML、相对路径和稳定字段表达 Skill，降低工具迁移成本。
- 将系统工具、第三方原件和个人核心资产分开管理。
- 通过目录扫描自动发现正式 Skill，避免维护重复注册清单。
- 把第三方供应链风险隔离在正式加载范围之外。
- 让项目经验通过创建、编辑和 Self-Improve 流程持续沉淀。

## 目录结构

```text
ZXSkills/
├── README.md
├── skill-manifest.yaml
├── skill-template.yaml
├── scripts/
│   ├── install-codex.sh
│   ├── install-codex.ps1
│   ├── configure-codex-reminder.sh
│   └── configure-codex-reminder.ps1
├── templates/
│   └── codex-agents-reminder.md
├── tests/
│   ├── test-configure-codex-reminder.sh
│   └── test-configure-codex-reminder.ps1
├── adapters/
│   └── codex/zx-skills/
│       ├── SKILL.md
│       └── agents/openai.yaml
├── builtin/
│   ├── skill-creator.yaml
│   ├── skill-editor.yaml
│   ├── skill-selfimprove.yaml
│   └── skill-import-external.yaml
├── skills-temp-inbox/
│   └── _readme.md
├── skills-external/
│   ├── 01-product/_readme.md
│   ├── 02-ui-design/_readme.md
│   ├── 03-fullstack-arch-dev/_readme.md
│   ├── 04-test-quality/_readme.md
│   ├── 05-ops-release/_readme.md
│   └── 06-project-manage/_readme.md
└── skills-custom/
    ├── 01-product/_readme.md
    ├── 02-ui-design/_readme.md
    ├── 03-fullstack-arch-dev/_readme.md
    ├── 04-test-quality/_readme.md
    ├── 05-ops-release/_readme.md
    └── 06-project-manage/_readme.md
```

当前仓库只提供框架、模板和四个内置工具，不预置业务 Skill。后续业务能力统一通过仓库工作流生成或导入。

## 六个业务分类

| 顺序 | 目录 | 存放范围 |
| --- | --- | --- |
| 01 | `01-product` | 需求调研、需求分析、产品设计、原型、产品验收 |
| 02 | `02-ui-design` | UI 设计、交互细节、设计规范、视觉交付、还原校验 |
| 03 | `03-fullstack-arch-dev` | 技术架构、方案设计、前后端开发、数据、系统集成 |
| 04 | `04-test-quality` | 测试策略、计划、用例、自动化、质量评估、测试报告 |
| 05 | `05-ops-release` | 环境、构建、部署、发布、回滚、监控、迭代更新 |
| 06 | `06-project-manage` | 范围、计划、进度、风险、沟通、里程碑、交付管控 |

跨域 Skill 放到“对最终交付结果负责”的主分类，其他领域通过触发词、流程步骤或约束表达。不要为了分类完整而复制多份近似 Skill。

## 三类正式 Skill 与一个隔离区

### `builtin`：仓库系统能力

存放维护本仓库所需的四个内置工具：

- `skill-creator`：从模板创建新的自定义业务 Skill。
- `skill-editor`：修改已有 Skill，保护 builtin、第三方原件和用户无关改动。
- `skill-selfimprove`：在工作节点结束后只做复用价值分析，固定返回三选一结论。
- `skill-import-external`：接收第三方内容，先隔离和评估，再等待用户确认。

### `skills-external`：已确认的第三方 Skill

存放经过评估并确认原样入库的第三方能力。推荐每个 Skill 使用独立目录：

```text
skills-external/<category>/<skill-id>/
├── skill.yaml       # 仓库可加载的标准入口
└── source/          # 第三方原始文件，保持字节不变
```

如果第三方原件已经符合本仓库契约，可复制为 `skill.yaml`；否则保留原件，并生成最小适配入口。适配入口必须记录来源、版本或提交号、许可证和 SHA-256，不能隐瞒或扩大原始行为。

### `skills-custom`：个人核心资产

存放个人原创能力和基于第三方深度改造后的 Skill。推荐结构：

```text
skills-custom/<category>/<skill-id>/
├── skill.yaml
├── scripts/         # 可选：需要确定性执行的脚本
├── references/      # 可选：按需读取的领域资料
└── assets/          # 可选：产出要复用的模板或素材
```

只有 `skill.yaml` 或 `skill.yml` 会被扫描；资源目录不会被当成独立 Skill 加载。引用资源时使用相对于 Skill 目录的路径，并在 `prompt` 中说明何时读取或运行。

### `skills-temp-inbox`：外部 Skill 隔离暂存箱

所有网络下载、复制粘贴和外部导入内容首先进入此目录。它不是正式 Skill 来源：

- 被 `skill-manifest.yaml` 全局排除；
- 不参与现有能力比较和自动触发；
- 不允许人工绕过评估直接复制到正式目录；
- 每个条目应包含 `source/` 原件与 `assessment.yaml` 来源/风险记录；
- 只能在用户明确确认后原样入库、改造入库或删除。

## Manifest 发现机制

`skill-manifest.yaml` 使用目录扫描，而不是枚举每个 Skill：

- `builtin`：扫描根层 `*.yaml` / `*.yml`。
- `skills-external`：递归扫描 `**/skill.yaml` / `**/skill.yml`。
- `skills-custom`：递归扫描 `**/skill.yaml` / `**/skill.yml`。
- `skills-temp-inbox/**`、`skill-template.yaml`、`_readme.md`、资源目录和隐藏文件均不加载。
- 只加载 `status: active` 的 Skill。
- 全仓库 `id` 必须唯一，重复时应报错，不能静默覆盖。

因此，新建业务 Skill 只需写到约定路径；删除时只需删除对应 Skill 目录。适配器重新扫描即可得到最新清单。

## 通用 Skill 文件规范

业务 Skill 使用 [`skill-template.yaml`](skill-template.yaml) 的结构。核心字段如下：

```yaml
schema_version: "1.0"
id: example-skill
name: "示例 Skill"
version: "1.0.0"
description: "能力说明和适用场景。"
category: 01-product
origin: custom
status: active
triggers:
  intents: []
  keywords: []
input_schema: {}
output_schema: {}
constraints: []
prompt: |-
  面向 AI 执行者的完整指令。
metadata: {}
```

### 命名和路径

- 目录、文件名和 `id` 使用小写字母、数字、横杠；业务分类保留两位数字前缀。
- `id` 需匹配 `^[a-z0-9]+(?:-[a-z0-9]+)*$`，并在 builtin、external、custom 中全局唯一。
- 自定义 Skill 路径固定为 `skills-custom/<category>/<skill-id>/skill.yaml`。
- 第三方 Skill 路径固定为 `skills-external/<category>/<skill-id>/skill.yaml`。
- `category` 必须与所属分类目录一致。

### 版本、来源和状态

- `version` 使用语义化版本 `major.minor.patch`。
- `origin` 只能是 `builtin`、`external` 或 `custom`，并与根目录一致。
- `status` 支持 `active`、`draft`、`deprecated`；manifest 默认只加载 `active`。
- 第三方或改造 Skill 在 `metadata.source` 记录来源、许可证、校验和与修改摘要。

### 描述和触发

- `description` 说明 Skill 做什么、何时适用，使用清晰的行业通用术语。
- `triggers.intents` 写用户可能表达的真实任务意图。
- `triggers.keywords` 写名称、领域词、常见同义词和可检索问题词。
- 避免触发范围过宽，也不要把某个项目名当成唯一触发条件。

### 输入和输出

- `input_schema` 和 `output_schema` 使用 JSON Schema 风格的普通 YAML 对象。
- 明确必填字段、类型、枚举、描述和是否允许额外字段。
- 输出应面向可验证交付物，而不是只要求“给出专业答案”。
- Self-Improve 生成的 creator/editor 参数必须完整，不使用 `TBD`、`TODO` 或“后续补充”。

### Prompt 编写

- 使用命令式、可执行的步骤，写清输入读取、判断顺序、异常处理、写入边界和完成条件。
- 只加入模型无法从任务本身推断的领域知识，不重复常识性说明。
- 易出错或有破坏性的操作使用严格步骤；需要上下文判断的部分保留合理自由度。
- 不假设某个工具一定拥有 shell、浏览器、网络、Git 或私有 API；如能力是必要条件，先检测，不可用时返回受限状态。
- 涉及文件修改时保护无关用户改动；涉及删除、发布、外部通信和凭据时明确授权边界。
- 完成前写明验证方法；验证失败必须报告真实状态。

### 资源组织

- 可重复且要求确定性的操作放入 `scripts/`，并实际测试脚本。
- 大段领域资料放入 `references/`，在 prompt 中按需读取，避免每次加载全部内容。
- 用于最终产出的模板、图像或样例放入 `assets/`。
- 不创建无用途的空资源目录和重复说明文档。

## 工作流 A：手动沉淀

适用于已经明确识别出可复用能力的情况。

```text
完成项目工作
  → 识别可复用的输入、步骤、边界和验收标准
  → 调用 builtin/skill-creator.yaml 或 skill-editor.yaml
  → 写入或更新 skills-custom
  → 解析 YAML 并验证 id、分类、版本、占位符
  → manifest 重新扫描后可调用
```

### 新建示例

提交给 `skill-creator` 的参数示例：

```yaml
category: 04-test-quality
skill_id: api-regression-planning
name: "API 回归测试规划"
description: "为接口变更识别回归范围并生成可执行测试计划。"
triggers:
  intents:
    - "为这次 API 变更制定回归计划"
  keywords:
    - API回归
    - 影响分析
goal: "从接口变更和调用关系生成有优先级、可验证的回归测试计划。"
workflow:
  - "读取接口差异、调用方、数据迁移和历史缺陷。"
  - "按直接影响、间接影响和高风险业务路径划分范围。"
  - "生成测试场景、数据条件、优先级和退出标准。"
quality_criteria:
  - "每项接口变更至少映射一个验证场景。"
  - "计划包含失败、兼容和回滚路径。"
```

创建器会基于模板生成 `skills-custom/04-test-quality/api-regression-planning/skill.yaml`，验证后由 manifest 自动发现。

### 修改示例

```yaml
target: api-regression-planning
change_request: "补充事件异步投递失败和重复消费的回归检查。"
proposed_changes:
  - "在 workflow 中加入事件生产者、消费者和重试策略分析。"
  - "在 quality_criteria 中加入幂等与死信队列验证。"
expected_version_bump: minor
```

`skill-editor` 先读取当前内容，再做最小修改、更新语义化版本并复验；不会用模板覆盖原 Skill。

## 工作流 B：自动 Self-Improve

适用于一个功能、需求、方案、测试或发布节点刚结束，需要判断是否值得沉淀的情况。它可以手动调用，也可以由外部 AI 工具配置为节点结束后的自动触发器。

```text
功能节点完成
  → 调用 builtin/skill-selfimprove.yaml
  → 读取本次过程、产物和验证证据
  → 扫描 manifest 中的正式 Skill（排除 temp-inbox）
  → 固定返回三选一
       ① no-action
       ② create-skill + creator_parameters
       ③ update-skill + editor_parameters
  → 用户或上层编排器决定是否调用 creator/editor
```

调用示例：

```yaml
project_context: "完成订单导入的失败重试与人工补偿设计。"
process_summary: "先定义失败类型，再区分自动重试、幂等恢复和人工接管，最后用故障注入验证。"
artifacts:
  - docs/order-import-recovery.md
  - tests/order-import-failure.spec.ts
validation_evidence:
  - "故障注入测试 18/18 通过"
auto_triggered: true
```

返回必须恰好匹配一个分支：

- `no-action`：说明项目独有、证据不足或已有 Skill 已覆盖，并明确可复用边界。
- `create-skill`：返回完整 `creator_parameters`，可原样交给 `skill-creator`。
- `update-skill`：返回完整 `editor_parameters`，可原样交给 `skill-editor`。

Self-Improve 永远只分析，不创建、修改、移动或删除仓库文件。自动触发也不会改变这一边界。

## 工作流 C：导入第三方 Skill

这是强制隔离流程，不能跳步。

```text
获得第三方文本 / 本地包 / HTTPS 链接
  → action=stage
  → 只写 skills-temp-inbox/<inbox-id>/
  → 保存 source 原件与 assessment.yaml
  → 静态评估来源、用途、许可、兼容性和安全风险
  → 返回 staged-awaiting-confirmation 并停止
  → 用户明确选择：
       ① approve-original → skills-external
       ② approve-customized → skills-custom
       ③ discard → 删除该单个暂存条目
```

### 第一步：暂存和评估

```yaml
action: stage
source:
  type: url
  value: "https://example.com/vendor/skill/archive/v1.2.0.zip"
  expected_ref: "v1.2.0"
```

导入工具只下载和静态读取，不运行安装器、脚本、构建、生命周期钩子或仓库代码。结果包含：

- 原始与最终 URL、获取时间、版本或提交号、SHA-256；
- 文件列表、用途和建议分类；
- 许可证与可再分发/改造边界；
- 工具专有字段和本仓库契约的兼容性差异；
- 网络、子进程、凭据、文件写入、持久化、自更新、动态执行、遥测、删除等风险；
- `low`、`medium`、`high` 或 `unknown` 总体风险。

“静态扫描没有命中”不等于安全证明；二进制、混淆内容、生成 bundle 或无法读取的文件必须标记为未知。

### 第二步：用户确认后处理

原样入库示例：

```yaml
action: approve-original
inbox_id: 20260813T080000Z-example-skill-a1b2c3d4
target_category: 03-fullstack-arch-dev
confirmation:
  confirmed: true
  action: approve-original
  inbox_id: 20260813T080000Z-example-skill-a1b2c3d4
```

改造入库示例：

```yaml
action: approve-customized
inbox_id: 20260813T080000Z-example-skill-a1b2c3d4
target_category: 03-fullstack-arch-dev
customization_request: "移除特定工具 API，改为通用文件输入，并增加离线运行约束。"
confirmation:
  confirmed: true
  action: approve-customized
  inbox_id: 20260813T080000Z-example-skill-a1b2c3d4
```

丢弃示例：

```yaml
action: discard
inbox_id: 20260813T080000Z-example-skill-a1b2c3d4
confirmation:
  confirmed: true
  action: discard
  inbox_id: 20260813T080000Z-example-skill-a1b2c3d4
```

确认对象中的 `action` 和 `inbox_id` 必须与本次请求完全一致。仅说“可以”“看起来没问题”或先前对另一条目的确认都不能触发正式入库或删除。

## 第三方 Skill 风险清单

正式入库前至少检查：

- 来源是否可追溯，下载地址、版本/提交号、作者和哈希是否记录。
- 是否存在安装、构建、卸载、pre/post 等生命周期钩子。
- 是否启动 shell、子进程、解释器、容器或外部可执行文件。
- 是否访问网络、上传内容、调用遥测或自更新服务。
- 是否读取凭据、环境变量、SSH/Git 配置、浏览器资料或私有项目文件。
- 文件系统读写范围是否超出声明用途，是否包含删除、覆盖、权限提升和持久化。
- 是否使用 `eval`、动态导入、反序列化、混淆、编码载荷或下载后执行。
- 是否包含二进制、压缩包、生成 bundle 或其他难以审计内容。
- 声明功能是否与真实代码一致，是否存在未说明的副作用。
- 许可证是否允许保存、使用、修改和再分发，归属说明是否完整。
- 是否绑定某个工具的私有 API、字段、路径或权限模型。

高风险、许可禁止或无法确认关键行为的内容应保持隔离或丢弃，不能因为功能有用就自动放行。

## 多工具兼容与接入

“本地 Skill”目前不是 Cursor、Windsurf、Codex、DevChat 等工具之间完全统一的文件协议。本仓库提供的是稳定、通用、可转换的数据契约，而不是声称所有工具都能原生读取同一个 manifest。

接入某个 AI 工具时，适配器按以下顺序工作：

1. 解析 `skill-manifest.yaml`。
2. 应用 `discovery.sources` 和 `global_exclude`，只发现正式 `skill.yaml` / `skill.yml`。
3. 校验必填字段、`id` 唯一性、分类路径、状态和版本。
4. 用 `triggers` 做能力发现或生成工具所需的索引描述。
5. 将 `prompt` 映射为该工具的规则、命令、Skill 正文或 Agent 指令。
6. 将 `input_schema`、`output_schema` 和 `constraints` 映射到该工具支持的结构；不支持的字段保留在 prompt 中。
7. 工具不支持动态目录扫描时，可在启动、提交或同步阶段生成它需要的索引文件；生成物不应反向成为仓库事实来源。

常见映射思路：

| 本仓库字段 | 通用目标含义 |
| --- | --- |
| `id` / `name` | Skill、命令或规则的唯一名称 |
| `description` / `triggers` | 能力发现和自动触发元数据 |
| `prompt` | AI 执行指令正文 |
| `input_schema` | 参数说明、表单或调用契约 |
| `output_schema` | 结构化响应或验收契约 |
| `constraints` | 安全、权限和项目边界 |
| `metadata.source` | 来源、许可证、校验和与审计记录 |

如果目标工具只识别 Markdown frontmatter，可由适配器生成：以 `id` 作为 `name`，以 `description` 和 `triggers` 生成 frontmatter 描述，以 `prompt`、输入输出和约束生成正文。不要为兼容某个工具而污染仓库中的源 Skill。

## 建议的校验门禁

每次新增、修改或导入后至少验证：

1. 所有 `.yaml` / `.yml` 都能被 YAML 1.2 兼容解析器读取。
2. 正式 Skill 包含 manifest 声明的所有必填字段。
3. `id` 符合格式且全局唯一。
4. `category`、`origin` 与所在路径一致。
5. 没有 `{{...}}`、`TBD`、`TODO` 等未完成占位符。
6. external/custom Skill 使用规范文件名 `skill.yaml` 或 `skill.yml`。
7. `skills-temp-inbox` 没有出现在任何 discovery source 中，并被全局排除。
8. prompt 引用的脚本、参考资料和资产真实存在。
9. 第三方 Skill 具有来源、许可证、哈希和风险评估记录。
10. 修改范围内没有覆盖无关用户文件。

## 仓库维护原则

- 一个 Skill 解决一个边界清楚、可重复调用的问题。
- 优先优化现有 Skill，避免按项目名复制近似能力。
- 经验尚未稳定或验证不足时，让 Self-Improve 返回 `no-action`。
- 原创或深度改造进入 `skills-custom`；已确认且尽量原样保留的第三方内容进入 `skills-external`。
- 第三方内容永远先进入 `skills-temp-inbox`，评估和明确确认是不可绕过的正式入库门槛。
- manifest 是扫描和验证契约；具体 AI 工具的生成索引只是适配产物。
