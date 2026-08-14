---
name: zx-skills
description: Compatibility alias for OPCSkills. Use when the user explicitly invokes the legacy $zx-skills entrypoint.
---

# OPCSkills 兼容入口

`$zx-skills` 是 `$opc-skills` 的兼容别名。

1. 解析当前 `SKILL.md` 的真实路径，向上定位包含 `skill-manifest.yaml` 的仓库根目录。
2. 读取 `<repository-root>/adapters/codex/opc-skills/SKILL.md` 的完整内容。
3. 按主适配器执行本次用户请求；保留原始用户输入，不缩写、不改写、不绕过其确认门禁。
4. 若主适配器或 manifest 不存在，立即停止并报告实际路径，不猜测其他仓库。
