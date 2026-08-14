# ZXSkills：全栈 OPC 本地 Skills 仓库

ZXSkills 用于沉淀一个全栈 OPC 从需求到交付全过程中的可复用 AI 执行能力。仓库以产品、UI 设计、全栈与架构、测试、运维发布、项目管理六个角色域作为核心分类；确实无法匹配时可按受控规则扩展新的业务分类。仓库不绑定某一种编程 AI 产品。

仓库本身是一套 Skill 集合：AI 工具或适配器读取根目录的 [`skill-manifest.yaml`](skill-manifest.yaml)，按目录扫描规则发现 `builtin`、`skills-external` 和 `skills-custom` 中的 Skill。新增或删除业务 Skill 时不需要手工维护索引。

> 安全边界：任何网络下载或外部导入的 Skill 都必须先进入 `skills-temp-inbox`。该目录被 manifest 全局排除，未经静态评估和用户明确确认，不得进入 `skills-external` 或 `skills-custom`。

## 目前提供什么

当前版本提供一套可持续积累个人 Skills 的仓库框架，以及一个 Codex 原生总入口 `$zx-skills`：

| 能力 | 用途 |
| --- | --- |
| 第三方 Skill 导入 | 下载内容先隔离到暂存箱，完成来源、许可、兼容性和安全评估后再确认入库 |
| 当前链路总结 | 总结刚完成的需求、开发、测试或发布过程，识别可复用经验 |
| Skill 创建 | 先展示可提炼内容和价值，用户确认具体提案后生成到 `skills-custom` |
| Skill 优化 | 先展示通用增补项、排除项和风险，确认后对已有 Skill 做最小、可追溯更新 |
| 仓库查看 | 按分类列出正式 Skill 和仓库状态 |

当前仓库只沉淀经过实际项目提炼的业务能力，目前包含项目结构整理 `zx-project-organizer`、UI 规范整理
`zx-ui-spec` 和 UI 页面检查 `zx-ui-check`；不会为了填满分类预置一批空泛 Skill。后续能力继续通过
实际项目的 Self-Improve、手动创建或第三方评估导入逐步积累。

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
$zx-skills 确认提炼 <proposal_id>
$zx-skills 放弃提炼 <proposal_id>
$zx-skills 使用 zx-project-organizer，帮我审计当前项目结构
$zx-skills 确认执行项目结构提案 <zpo-proposal_id>
$zx-skills 放弃项目结构提案 <zpo-proposal_id>
$zx-skills 新建一个 API 回归测试 Skill
$zx-skills 优化 zx-test-regression，补充异步消息失败场景
$zx-skills 列出我的测试类 Skills
```

总入口会自动判断意图并读取对应的 builtin Skill，不要求使用者填写内部 YAML 参数。

“总结并沉淀/优化”不是预先授权写入。第一次调用只会展示：哪些内容可以提炼、为什么值得提炼、
跨项目适用场景、证据、必须排除的项目独有内容、计划改动和风险，并返回 `proposal_id`。只有下一条
消息明确确认同一个 `proposal_id`，creator/editor 才能写入；参数一旦变化，旧确认立即失效。

仓库使用 [`scripts/compute-proposal-id.py`](scripts/compute-proposal-id.py) 统一计算 `zxsi-*` 和 `zpo-*`
内容指纹，避免不同工具对 JSON 空格、键顺序、中文转义或末尾换行处理不同。适配器可把 JSON 文件或
标准输入交给脚本；脚本会自行生成无末尾换行的 canonical JSON 字节再计算 SHA-256。

### 项目结构整理为什么也分两步

`zx-project-organizer` 的审计模式始终只读。初始化或重构项目时，第一次调用也只生成提案：已确认/
推断/未知事实及来源、推荐结构、完整文件内容、迁移映射、是否初始化 Git 和 `zpo-*` 提案 ID。
确认前不会创建目录、写 README、移动文件或运行 `git init`。

#### 引导创建一个全新项目

不需要先整理一大段参数，直接说：

```text
$zx-skills 使用 zx-project-organizer，引导我创建一个全新项目
```

Skill 会逐步帮助用户补齐整个创建流程，一次只问一个会影响后续设计的问题：

1. 项目要解决什么问题、服务哪些用户。
2. 项目阶段、中文名称和英文项目标识。
3. 采用完整、自适应还是自定义结构，以及需要哪些文档边界。
4. 是否有前端；分别有哪些终端应用。
5. 是否有后端；是单体还是多个独立应用，各自职责是什么。
6. 每个应用是否生成可运行代码骨架。
7. 仅对选择生成的应用继续确认框架、版本、包管理器或模块名、启动命令和测试方式。
8. 是否需要已明确的数据库、缓存、消息队列、定时任务和 Git 初始化。
9. 汇总完整目录、文件、代码骨架、命令和风险，等待提案确认。

每个关键问题都会给出一个推荐选项、推荐理由、其他选项的影响和自定义入口。推荐只是建议，状态仍为
`proposed`；只有用户明确接受或修改后才成为确认事实。接受一个推荐不会自动接受后续推荐。

例如：

```text
问题：微信小程序应用使用哪个目录名？
推荐：ai-huoke-wx-mini
推荐原因：包含项目标识和终端类型，同时保持简短。
选项：接受推荐 / 修改名称 / 不创建该应用 / 自定义
```

#### 引导整理一个存量项目

```text
$zx-skills 使用 zx-project-organizer，引导我整理现有项目
```

Skill 会先只读扫描目录、源码、运行入口、构建配置、Git 状态、正式文档、部署配置和路径引用，区分
`confirmed`、`inferred`、`unknown` 和 `proposed`，再逐项询问哪些内容保留、移动、改名、新增或丢弃。

存量项目默认推荐沿用已有可运行技术栈和稳定约定。已有应用不会被重新生成或覆盖；只有用户明确新增的
应用才会询问是否生成代码骨架。目录移动前必须展示迁移映射、引用影响、执行顺序、验证方法和回滚方式，
用户确认对应 `zpo-*` 提案前不会移动任何文件。

#### 前后端独立应用结构

不论当前只有一个还是多个应用，都保留稳定的 `apps` 层：

```text
development/
├── frontend/
│   └── apps/
│       ├── ai-huoke-web-admin/
│       ├── ai-huoke-h5/
│       ├── ai-huoke-wx-mini/
│       ├── ai-huoke-uniapp/
│       ├── ai-huoke-ios/
│       └── ai-huoke-android/
├── backend/
│   └── apps/
│       ├── ai-huoke/
│       ├── ai-huoke-worker/
│       └── ai-huoke-scheduler/
└── experiments/
```

目录命名规则：

| 类型 | 规则 | 示例 |
| --- | --- | --- |
| 项目标识 | 小写、横杠分隔，推荐后必须由用户确认 | `ai-huoke` |
| 前端应用 | `<project-slug>-<terminal>` | `ai-huoke-web-admin`、`ai-huoke-wx-mini`、`ai-huoke-uniapp` |
| 单体后端 | `<project-slug>` 或 `<project-slug>-api` | `ai-huoke`、`ai-huoke-api` |
| 多后端应用 | `<project-slug>-<responsibility>` | `ai-huoke-worker`、`ai-huoke-data-sync-job` |

Go、Python、Node.js 可以同时位于 `backend/apps`，但技术栈不写入目录名。每个应用独立维护依赖、测试、
构建和交付配置，不创建 `services`、`packages`、`libs` 或 `shared-code`，也不通过相对路径引用其他应用源码。

HTTP API、RPC 和消息规范跟随提供方后端应用，只创建实际使用的规范目录：

```text
development/backend/apps/ai-huoke/specifications/http-api/
development/backend/apps/ai-huoke-worker/specifications/messages/
```

不会创建中央 `development/backend/specifications`，消费方也不维护另一份权威规范。

代码骨架按应用分别选择，例如可以只为 `ai-huoke-web-admin` 和 Go 单体后端 `ai-huoke` 生成可运行骨架，
而 `ai-huoke-wx-mini`、`ai-huoke-uniapp` 只创建目录。技术栈或版本未确认时只提供推荐并继续询问，不生成
占位代码。

初始化有三种结构策略，不再由 AI 隐式选择：

| 策略 | 适合场景 | 行为 |
| --- | --- | --- |
| `zx-full-delivery` | 希望项目一开始就建立完整 OPC 交付边界 | 严格采用 ZX 版本化完整结构，预建产品、设计、测试、项目管理、前后端/实验和调研资产目录 |
| `adaptive` | 技术与交付边界尚不稳定，希望保持最小结构 | 只根据已确认事实和现有框架生成目录，推断不落盘 |
| `custom` | 已经有明确目录树或团队规范 | 用户目录树是权威结构，不允许静默改名、搬移、增加或遗漏 |

推荐的个人完整结构用法：

```text
$zx-skills 使用 zx-project-organizer，按 ZX 完整结构初始化当前项目，不初始化 Git
```

完整结构固定包含：

```text
docs/project/{01-项目计划,02-里程碑,03-风险与阻塞,04-会议记录,05-决策记录}
docs/product/{00-项目背景,01-调研分析,02-用户研究,03-竞品分析,04-需求池,05-业务流程,06-PRD,07-版本规划,08-需求评审,09-验收标准}
docs/design/{01-信息架构,02-用户流程,03-低保真原型,04-视觉设计,05-设计规范,06-设计评审}
docs/testing/{01-测试计划,02-测试用例,03-测试报告,04-验收记录}
development/{frontend/apps,backend/apps,experiments}
research/{sources,assets}
```

该契约保存在
[`zx-full-delivery-structure.yaml`](skills-custom/06-project-manage/zx-project-organizer/references/zx-full-delivery-structure.yaml)，
以后调整完整结构只需要版本化修改这一份参考文件。

只说“初始化项目”但没有说明策略时，Skill 会先询问选择完整、自适应还是自定义，不再默认输出轻量
`src/` 结构。用户对上一轮事实清单只修改部分内容时，未提及事项继续保持“待确认”，不会被自动当作
全部确认。custom/完整结构提案还会逐项输出 requested、planned、missing、additional 和 renamed/moved
路径差异，只有完全一致才允许进入确认阶段。

确认提案：

```text
$zx-skills 确认执行项目结构提案 <zpo-proposal_id>
```

放弃提案：

```text
$zx-skills 放弃项目结构提案 <zpo-proposal_id>
```

确认时会使用第一次展示的原始提案载荷重新计算 ID，并重新检查工作区是否仍适合执行；不会让 AI
临时重新发挥生成另一套目录或文件。ID 不匹配、载荷丢失、目标冲突或项目状态变化时返回 `blocked`，
先给出新提案再等待确认。`initialize_git` 默认是 `false`，只有提案中明确为 `true` 才可能执行。

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

不会。提醒规则只让 Codex 判断是否应该建议你运行 `$zx-skills 总结一下当前链路`。Self-Improve
即使被手动或自动调用也只会分析；新建/优化提案还要用匹配的 `proposal_id` 再次确认，第三方入库则要
确认匹配的 `inbox_id`，仓库才会发生对应变更。

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
├── category-readme-template.md
├── scripts/
│   ├── install-codex.sh
│   ├── install-codex.ps1
│   ├── configure-codex-reminder.sh
│   └── configure-codex-reminder.ps1
├── templates/
│   └── codex-agents-reminder.md
├── tests/
│   ├── test-configure-codex-reminder.sh
│   ├── test-configure-codex-reminder.ps1
│   ├── test-dynamic-categories.py
│   └── test-personal-namespace.py
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
    ├── 02-ui-design/
    │   ├── _readme.md
    │   ├── zx-ui-spec/skill.yaml
    │   └── zx-ui-check/skill.yaml
    ├── 03-fullstack-arch-dev/_readme.md
    ├── 04-test-quality/_readme.md
    ├── 05-ops-release/_readme.md
    └── 06-project-manage/
        ├── _readme.md
        └── zx-project-organizer/
            ├── skill.yaml
            └── references/zx-full-delivery-structure.yaml
```

仓库框架不批量预置空泛业务 Skill；当前包含 `zx-project-organizer`、`zx-ui-spec` 和 `zx-ui-check`。
后续业务能力统一通过仓库工作流生成或导入。

## 六个核心业务分类

| 顺序 | 目录 | Skill 分类词 | 存放范围 |
| --- | --- | --- | --- |
| 01 | `01-product` | `product` | 需求调研、需求分析、产品设计、原型、产品验收 |
| 02 | `02-ui-design` | `ui` | UI 设计、交互细节、设计规范、视觉交付、还原校验 |
| 03 | `03-fullstack-arch-dev` | `dev` | 技术架构、方案设计、前后端开发、数据、系统集成 |
| 04 | `04-test-quality` | `test` | 测试策略、计划、用例、自动化、质量评估、测试报告 |
| 05 | `05-ops-release` | `ops` | 环境、构建、部署、发布、回滚、监控、迭代更新 |
| 06 | `06-project-manage` | `project` | 范围、计划、进度、风险、沟通、里程碑、交付管控 |

跨域 Skill 放到“对最终交付结果负责”的主分类，其他领域通过触发词、流程步骤或约束表达。不要为了分类完整而复制多份近似 Skill。

### 扩展业务分类

`01–06` 是核心交付分类，应优先复用。只有逐项比较 `skill-manifest.yaml` 中所有分类的 `scope` 和目录 `_readme.md` 后，仍然没有合理归属，才允许创建扩展分类。

扩展规则：

- 从 `07` 到 `99` 选择当前最小未使用编号，manifest 中称为 `next-unused`；不要在分析或暂存阶段提前锁定编号。
- 分类 id 使用 `<两位编号>-<小写英文领域>`，例如 `07-ai-data`。
- 每个分类还要定义唯一的 `skill_token`，用于 custom Skill 的分类段。它必须是一个小写通俗单词，
  例如 `07-ai-data` 可以使用 `data`；不能与已有 `product`、`ui`、`dev`、`test`、`ops`、`project` 重复。
- 领域名称必须代表可持续、跨项目复用的能力边界；不得使用客户名、项目名、单个 Skill 名或一次性技术名称。
- 必须在 `skill-manifest.yaml` 的 `categories` 中登记 `id`、`skill_token`、`name` 和 `scope`。
- 必须同步创建 `skills-custom/<category>/_readme.md` 和 `skills-external/<category>/_readme.md`，两份说明均由 [`category-readme-template.md`](category-readme-template.md) 生成，包含分类定位、包含范围、排除范围和 ID 规则。
- 分类注册、两侧说明和目标 Skill 写入视为同一次操作。分类创建失败或 Skill 验证失败时，只回滚本次新增项，不删除操作前已经存在的用户文件。

Self-Improve 发现没有匹配分类时只返回 `new_category` 建议，不修改仓库。第三方 Skill 在 `stage` 阶段也只把建议写入评估记录；必须等用户确认 `approve-original` 或 `approve-customized` 后，才能创建正式分类。

示例：一个稳定覆盖 AI 模型评测、数据质量和数据治理的能力无法由现有六类合理负责：

```text
new_category.slug = ai-data
new_category.skill_token = data
  → 确认当前 07–99 中最小未使用编号为 07
  → manifest 新增 07-ai-data
  → 创建 skills-custom/07-ai-data/_readme.md
  → 创建 skills-external/07-ai-data/_readme.md
  → 写入 zx-data-model-check 或对应 external Skill
  → 一并验证；任一步失败则回滚本次新增内容
```

后续同领域 Skill 直接复用 `07-ai-data`，不再为每个模型、数据集或项目继续拆分新分类。

## 三类正式 Skill 与一个隔离区

### `builtin`：仓库系统能力

存放维护本仓库所需的四个内置工具：

- `skill-creator`：从模板创建新的自定义业务 Skill。
- `skill-editor`：修改已有 Skill，保护 builtin、第三方原件和用户无关改动。
- `skill-selfimprove`：在工作节点结束后只做复用价值分析，固定返回三选一结论；创建/优化建议必须等待用户确认。
- `skill-import-external`：接收第三方内容，先隔离和评估，再等待用户确认。

### `skills-external`：已确认的第三方 Skill

存放经过评估并确认原样入库的第三方能力。推荐每个 Skill 使用独立目录：

```text
skills-external/<category>/<skill-id>/
├── skill.yaml       # 仓库可加载的标准入口
└── source/          # 第三方原始文件，保持字节不变
```

如果第三方原件已经符合本仓库契约，可复制为 `skill.yaml`；否则保留原件，并生成最小适配入口。适配入口必须记录来源、版本或提交号、许可证和 SHA-256，不能隐瞒或扩大原始行为。`skills-external` 的正式适配 ID 不得使用 `zx-`；如果第三方 source 原件恰好使用该前缀，原件保持不变，正式适配入口改用可追溯且不占用个人命名空间的 ID，并记录映射关系。

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

#### 个人 Skill 命名空间

`zx-` 是仓库所有者的个人 Skill 命名空间。所有 `skills-custom` 中的个人原创和第三方深度改造 Skill
都必须使用固定格式 `zx-<category>-<function>`，用于：

- 一眼识别个人专属能力；
- 避免与 builtin 和第三方 Skill 重名；
- 通过 `zx-` 统一检索、筛选和管理；
- 形成按分类组织的系列，例如 `zx-product-*`、`zx-ui-*`、`zx-dev-*`、`zx-test-*`、`zx-ops-*`、`zx-project-*`。

三段含义固定：

- `zx-`：个人命名空间，固定不变。
- `category`：分类短词，必须取目标分类在 manifest 中登记的 `skill_token`。
- `function`：这个 Skill 的主要功能，优先使用一个通俗单词，确有必要时最多两个单词。

核心分类词与简单示例：

| 分类 | 分类词 | 示例 |
| --- | --- | --- |
| 产品 | `product` | `zx-product-prd` |
| UI 设计 | `ui` | `zx-ui-spec`、`zx-ui-check` |
| 全栈与架构 | `dev` | `zx-dev-api` |
| 测试 | `test` | `zx-test-regression` |
| 运维发布 | `ops` | `zx-ops-release` |
| 项目管理 | `project` | `zx-project-risk`、`zx-project-organizer` |

推荐使用 `spec`、`check`、`plan`、`review`、`test`、`deploy`、`risk` 等看到就能理解的功能词。
不要把设计过程、实现方式和多个近义词连续堆进 id。例如：

```text
推荐：zx-ui-spec
不推荐：zx-ui-design-spec-extractor

推荐：zx-ui-check
不推荐：zx-ui-implementation-conformance-audit
```

通过 `$zx-skills` 新建时，用户只需描述能力。创建器会先确定分类，再按
`zx-<category>-<function>` 推荐简短 id，并校验分类词、功能词数量、目录同名和全仓库唯一性，不要求
用户手写内部参数。`builtin` 保持系统工具原名；原样入库的 external Skill 不加 `zx-`。

如果升级前已经存在不带 `zx-`、分类段不匹配或功能段过长的 custom Skill，应执行一次显式迁移：
确定新 id、把目录同步改为新 id、更新仓库内引用，并重新检查全局唯一性和 manifest 可发现性。
不要只改 YAML 的 `id` 而保留旧目录，也不要在普通内容编辑时静默重命名。

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

`category_extension` 另外定义扩展分类的编号范围、`next-unused` 策略、slug/id 正则、`skill_token`、
镜像根目录和分类说明模板。它是 creator、editor fork 和确认后的第三方导入共同遵守的写入契约，
不会让 manifest 扫描 `skills-temp-inbox` 或模板文件。

## 通用 Skill 文件规范

业务 Skill 使用 [`skill-template.yaml`](skill-template.yaml) 的结构。核心字段如下：

```yaml
schema_version: "1.0"
id: zx-product-spec
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
- 所有 `id` 需匹配 `^[a-z0-9]+(?:-[a-z0-9]+)*$`，并在 builtin、external、custom 中全局唯一。
- custom `id` 必须匹配 `^zx-[a-z0-9]+-[a-z0-9]+(?:-[a-z0-9]+)?$`，格式固定为
  `zx-<category>-<function>`；分类段匹配 manifest 的 `skill_token`，功能段最多两个单词。
- external 正式适配 `id` 禁止使用保留前缀 `zx-`，但 source 原件内容不因此改写。
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
skill_id: zx-test-regression
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

创建器会基于模板生成 `skills-custom/04-test-quality/zx-test-regression/skill.yaml`，验证后由 manifest 自动发现。

### 修改示例

```yaml
target: zx-test-regression
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
       ② create-skill + 可提炼说明 + creator_parameters
       ③ update-skill + 可提炼说明 + editor_parameters
  → ②/③ 固定返回 awaiting-confirmation + proposal_id，然后停止
  → 用户查看提炼价值、项目独有排除项、具体改动和风险
  → 用户后续确认同一个 proposal_id
  → 重新计算 ID，匹配后才调用 creator/editor；不匹配则阻止写入
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
- `create-skill`：说明准备提炼的通用能力与价值，返回完整 `creator_parameters` 和 `proposal_id`。
- `update-skill`：说明准备补强的通用能力与价值，返回完整 `editor_parameters` 和 `proposal_id`。

两个建议分支都必须包含：可提炼能力、为什么值得提炼、至少两个跨项目场景、复用证据、项目独有
排除项、确认后计划改动和风险。第一次输出固定为 `awaiting-confirmation`，并给出：

```text
$zx-skills 确认提炼 <proposal_id>
$zx-skills 放弃提炼 <proposal_id>
```

Self-Improve 永远只分析，不创建、修改、移动或删除仓库文件。自动触发、用户说“总结并沉淀”或
“总结并优化”都不会改变这一边界，也不会让同一轮自动调用 creator/editor。`proposal_id` 是具体
creator/editor 参数的内容指纹；确认缺失、ID 不匹配或参数变化时，下游返回 `blocked`，需要展示新提案
并重新确认。用户直接明确提出“新建一个 Skill”或“修改某个 Skill”时仍可走手动工作流 A。

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
- 结构化 `category_assessment`：匹配已有分类时给出分类 id，没有匹配时给出完整 `new_category` 建议但不预分配编号；
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
4. custom `id` 使用 `zx-` 前缀，external 正式适配 `id` 不占用 `zx-`。
5. `category`、`origin` 与所在路径一致；扩展分类已注册 manifest，并同时拥有 custom/external 两份无占位符的 `_readme.md`。
6. 没有 `{{...}}`、`TBD`、`TODO` 等未完成占位符。
7. external/custom Skill 使用规范文件名 `skill.yaml` 或 `skill.yml`。
8. `skills-temp-inbox` 没有出现在任何 discovery source 中，并被全局排除。
9. prompt 引用的脚本、参考资料和资产真实存在。
10. 第三方 Skill 具有来源、许可证、哈希和风险评估记录。
11. 修改范围内没有覆盖无关用户文件。
12. Self-Improve 创建/优化提案具有 `proposal_id`，且 creator/editor 只接受匹配的后续确认。

## 仓库维护原则

- 一个 Skill 解决一个边界清楚、可重复调用的问题。
- 优先优化现有 Skill，避免按项目名复制近似能力。
- 经验尚未稳定或验证不足时，让 Self-Improve 返回 `no-action`。
- Self-Improve 先解释提炼内容和跨项目价值；没有匹配提案的用户确认，不得创建或优化 Skill。
- 原创或深度改造使用 `zx-` id 进入 `skills-custom`；已确认且尽量原样保留的第三方内容使用非 `zx-` id 进入 `skills-external`。
- 第三方内容永远先进入 `skills-temp-inbox`，评估和明确确认是不可绕过的正式入库门槛。
- manifest 是扫描和验证契约；具体 AI 工具的生成索引只是适配产物。
