# 第三方 UI 设计能力 Skill

存放已经完成来源、许可、兼容性和风险评估，并经用户确认原样入库的 UI 设计类第三方 Skill，包括界面设计、交互细节、设计规范、视觉交付和 UI 还原校验。

每个 Skill 使用独立目录 `<skill-id>/`：可加载入口为 `skill.yaml`，第三方原件保存在 `source/` 且尽量不修改。待评估内容必须先进入 `skills-temp-inbox`。

正式 external 适配 `skill-id` 不得占用 `zx-` 个人命名空间；若 source 原件使用该前缀，保留原件并在适配入口记录非 `zx-` ID 映射。
