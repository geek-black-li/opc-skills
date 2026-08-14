# OPCSkills 品牌、仓库与本地路径迁移设计

日期：2026-08-14

状态：已实施仓库内迁移，等待远程与本地目录迁移

当前仓库：`ZXSkills` / `https://gitee.com/geek_black_li/zx-skills.git`

## 1. 目标

将仓库的项目品牌统一为 `OPCSkills`，在 GitHub 创建公开仓库
`geek-black-li/opc-skills` 并作为主远程，同时把本地项目文件夹从
`ZXSkills` 改为 `OPCSkills`。

迁移采用兼容策略：新的主要调用入口为 `$opc-skills`，现有
`$zx-skills` 继续可用；个人 Skill 仍使用 `zx-*` 命名空间，现有提案 ID
前缀保持稳定。

## 2. 已确认决策

| 对象 | 决策 |
| --- | --- |
| 项目品牌 | `OPCSkills` |
| GitHub 仓库 | `geek-black-li/opc-skills`，Public |
| 本地文件夹 | `OPCSkills` |
| 主调用入口 | `$opc-skills` |
| 兼容调用入口 | `$zx-skills` |
| 个人 Skill 命名空间 | 保持 `zx-*` |
| 提案 ID | 保持 `zxsi-*`、`zpo-*` |
| GitHub remote | `origin` |
| Gitee remote | `gitee`，保留为备用远程 |
| Gitee 同步 | 不自动同步，需要时手动推送 |

GitHub CLI 已安装为官方 `gh 2.97.0`，当前登录账号为
`geek-black-li`，凭据保存在 macOS Keychain。当前终端访问
`github.com` 需要显式继承系统代理 `http://127.0.0.1:7890`；实施命令只在
进程环境中设置代理，不把代理或凭据写入仓库。

## 3. 迁移范围

### 3.1 项目品牌

以下用户可见和仓库级标识改为 `OPCSkills`：

- 根 README 的标题、说明、安装与使用示例；
- `skill-manifest.yaml` 的仓库标识和说明；
- Builtin Skill 的描述、Prompt 和作者标识；
- Codex 适配器的展示名称、说明和默认 Prompt；
- 安装脚本、状态输出、错误提示和提醒模板中的用户可见文案；
- 测试名称和断言中只代表项目品牌的 `ZXSkills` 文案。

以下稳定协议不随品牌迁移：

- 所有 `skills-custom/**/zx-*` 个人 Skill ID 和目录；
- `$zx-skills` 兼容调用入口；
- `zxsi-*`、`zpo-*` 提案 ID；
- 已安装提醒片段的管理标记 `zx-skills-reminder`；
- Skill 分类编号、目录结构、Manifest 扫描规则和提案哈希算法。

提醒标记保持不变是为了让新版脚本仍能识别、升级和卸载旧版受管片段；
标记内部的用户可见标题改为 OPCSkills。

### 3.2 Codex 双入口

主适配器位于 `adapters/codex/opc-skills/`，承载完整路由逻辑，Skill 名称为
`opc-skills`。兼容适配器位于 `adapters/codex/zx-skills/`，只负责声明旧入口、
定位同一仓库并转交主适配器，不复制完整业务 Prompt，避免双份逻辑漂移。

安装后同时存在：

```text
~/.agents/skills/opc-skills -> <OPCSkills>/adapters/codex/opc-skills
~/.agents/skills/zx-skills  -> <OPCSkills>/adapters/codex/zx-skills
```

安装脚本必须支持：

- `install`：安装或升级主入口与兼容入口；
- `status`：分别验证两条入口、符号链接目标和仓库根；
- `uninstall`：只移除两个受管入口，不删除仓库或业务 Skills；
- 旧版升级：检测只存在 `zx-skills` 的旧安装，安全迁移为双入口；
- 冲突保护：目标存在且不是本仓库受管链接时停止，不覆盖用户文件。

POSIX 与 PowerShell 安装脚本保持相同行为，并增加相应回归测试。

## 4. GitHub 与远程设计

使用已登录的 GitHub 账号创建 Public 空仓库
`geek-black-li/opc-skills`。建仓时不生成 README、`.gitignore` 或 License，
避免与已有 Git 历史冲突。

远程切换顺序：

1. 确认本地 `main` 与当前 Gitee `origin/main` 一致且工作区干净；
2. 创建 GitHub 空仓库；
3. 把当前 `origin` 重命名为 `gitee`；
4. 把 GitHub `https://github.com/geek-black-li/opc-skills.git` 添加为新 `origin`；
5. 推送完整 `main` 历史并设置 upstream；
6. 核验 GitHub 远程提交哈希与本地 `HEAD` 一致；
7. 保留 Gitee 地址，不自动推送。

若 GitHub 建仓或推送失败，不删除或改写 Gitee 仓库。若远程名称切换只完成一部分，
按已记录的原 URL 恢复 `origin`，然后停止。

## 5. 本地目录改名

本地目录改名最后执行，因为绝对路径变化会让已安装的 Codex 符号链接立即失效。

前置条件：

- 所有仓库测试通过；
- Git 工作区干净；
- GitHub `origin/main` 已验证；
- 父目录下不存在 `OPCSkills`；
- 当前安装入口和目标路径已经只读解析并记录。

执行流程：

1. 从父目录把 `ZXSkills` 移动为 `OPCSkills`；
2. 使用新绝对路径运行双入口安装脚本；
3. 验证 `$opc-skills` 和 `$zx-skills` 都解析到新目录；
4. 运行安装状态检查和关键仓库测试；
5. 提示用户在 Codex 中重新打开 `OPCSkills` 工作区。

如果目标目录已存在，停止且不合并、不覆盖。若改名后安装验证失败，仓库内容仍保留在
`OPCSkills`；优先修复受管链接，不回滚已经验证成功的 GitHub 远程。

## 6. 实施顺序

迁移拆成四个可独立验证的阶段：

1. **内部品牌与双入口**：修改仓库文件、脚本和测试，保持旧入口兼容；
2. **GitHub 建仓与远程切换**：创建 Public 仓库，设置双远程并推送；
3. **本地目录改名与重装**：移动目录、修复双入口链接；
4. **最终验证与提交说明**：验证仓库、远程、安装入口和新路径。

阶段 1 未通过测试时不得进入阶段 2；阶段 2 未验证远程哈希时不得执行目录改名。

## 7. 测试与验收

### 7.1 静态与仓库测试

- 所有 YAML 可解析；
- 现有 Python、Shell 和 PowerShell 测试全部通过；
- 新增品牌边界测试：该改的 `ZXSkills` 已改，稳定的 `zx-*` 协议未被误改；
- 新增双入口安装、状态、升级和卸载测试；
- `git diff --check` 通过；
- 工作区无意外文件或未提交改动。

### 7.2 运行验收

- `gh repo view geek-black-li/opc-skills` 可读取 Public 仓库；
- `origin` 指向 GitHub，`gitee` 指向现有 Gitee；
- GitHub `main`、本地 `HEAD` 哈希一致；
- 本地根目录为 `OPCSkills`；
- `$opc-skills` 为主入口并能定位 `skill-manifest.yaml`；
- `$zx-skills` 兼容入口仍能路由到同一仓库；
- 旧提醒片段可以被新版脚本查询和卸载；
- Codex 重新打开新目录后，两条入口均可发现。

## 8. 非目标

本次不做以下改动：

- 不把个人 Skill 的 `zx-*` 批量改成 `opc-*`；
- 不改变提案 ID 或哈希协议；
- 不删除 Gitee 仓库；
- 不建设 GitHub 与 Gitee 的自动镜像或 CI 同步；
- 不重构与品牌迁移无关的业务 Skill；
- 不在仓库中保存 GitHub Token、代理配置或本机绝对路径。

## 9. 完成定义

当且仅当内部品牌、双入口兼容、GitHub Public 仓库、双远程、本地
`OPCSkills` 路径和全部验证同时成立，迁移才算完成。任何阶段失败都必须报告
实际状态，不得把部分建仓、部分改名或仅静态测试通过描述为完整迁移成功。
