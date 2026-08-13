# 外部 Skill 收件暂存箱

本目录只隔离保存网络下载、复制文本或外部导入的待评估 Skill，不是正式 Skill 仓库。

- `skill-manifest.yaml` 全局排除本目录，AI 工具不得扫描或加载这里的内容。
- 所有导入应通过 `builtin/skill-import-external.yaml`，每个条目使用独立 `<inbox-id>/`。
- 暂存条目应包含 `source/` 原件和 `assessment.yaml` 来源、许可、兼容性与风险记录。
- 评估默认只做静态检查，不执行脚本、安装器、构建、生命周期钩子或仓库代码。
- 只有用户明确确认后，才能原样迁移到 `skills-external`、改造后写入 `skills-custom`，或删除该单个暂存条目。
- 禁止绕过本目录把网络 Skill 直接放入正式仓库。
