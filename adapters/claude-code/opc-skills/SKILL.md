---
name: opc-skills
description: Use when the user invokes OPCSkills to run a formal local skill, manage third-party skill imports, summarize reusable work, create or update a personal skill, list repository skills, or inspect repository status.
---

# OPCSkills for Claude Code

把 `/opc-skills` 作为 OPCSkills 仓库在 Claude Code 中的唯一入口。接受自然语言参数，不要求用户填写仓库内部 YAML 字段。

## 加载正式路由

1. 解析本 `SKILL.md` 所在目录的真实路径；目录可能是从 `~/.claude/skills/opc-skills` 指向仓库的符号链接。
2. 从真实路径向上查找 `skill-manifest.yaml`，其所在目录就是 `OPCSKILLS_ROOT`。找不到时，再检查用户明确给出的路径；仍找不到则说明缺少正式仓库位置并停止。
3. 读取 `${OPCSKILLS_ROOT}/skill-manifest.yaml`，然后读取 `${OPCSKILLS_ROOT}/adapters/codex/opc-skills/SKILL.md` 作为共享的 OPCSkills 路由与治理契约。
4. 执行共享契约时，将其中的显式调用写法 `$opc-skills` 解释为 Claude Code 的 `/opc-skills`；示例、下一步指令和用户可复制命令也统一输出 `/opc-skills`。忽略仅服务于 Codex 界面元数据的 `agents/openai.yaml`。
5. 所有 builtin、custom、external、模板、引用和脚本路径都从 `OPCSKILLS_ROOT` 解析。正式业务 Skill 仍以 `skill-manifest.yaml` 发现的 `skill.yaml` 为唯一源码，不把第三方 `source/` 或 `skills-temp-inbox/` 当作可执行入口。

## Claude Code 边界

- `/opc-skills` 只负责加载和路由仓库能力；它不会把每个 `skill.yaml` 注册成独立的 Claude `/` 命令。调用业务能力时使用 `/opc-skills 使用 <skill-id>，...`。
- Claude Code 的 Skill 被发现不代表获得写入、删除、联网、提交、推送或发布权限；继续遵守共享契约、当前用户请求和目标项目规则。
- 面向用户先给普通中文结果，不默认展示内部 YAML 或大段结构化字段。

## 示例

```text
/opc-skills 查看仓库状态
/opc-skills 列出我的 Skills
/opc-skills 使用 zx-product-prd，复审 docs/PRD.md
/opc-skills 使用 zx-dev-architecture，基于已批准 PRD 更新技术设计
/opc-skills 总结一下当前链路
```
