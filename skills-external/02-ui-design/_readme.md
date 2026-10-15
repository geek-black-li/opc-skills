# 第三方 UI 设计能力 Skill

存放已经完成来源、许可、兼容性和风险评估，并经用户确认原样入库的 UI 设计类第三方 Skill，包括界面设计、交互细节、设计规范、视觉交付和 UI 还原校验。

每个 Skill 使用独立目录 `<skill-id>/`：可加载入口为 `skill.yaml`，第三方原件保存在 `source/` 且尽量不修改。待评估内容必须先进入 `skills-temp-inbox`。

正式 external 适配 `skill-id` 不得占用 `zx-` 个人命名空间；若 source 原件使用该前缀，保留原件并在适配入口记录非 `zx-` ID 映射。

## 已评估的受限接入

| Skill | 正式入口版本／上游来源 | 运行边界 |
|---|---|---|
| [Impeccable](impeccable/skill.yaml) | 4.5.2；`abf5779…` | 文本指导模式；禁用hooks、启动器、二进制、遥测和live |
| [Design Taste Frontend](design-taste-frontend/skill.yaml) | 适配1.1.0／上游2.0.0；`f624f37…` | 禁用原生inspect及安装器；draw历史限制在项目内，其他脚本按任务授权 |

`source/`保留原始源码、许可和评估证据；其中的安装器、插件和hooks配置不是项目配置，不自动加载或执行。受限入口不等同完整运行时已验证。Taste旧源码和原适配入口备份继续保留。
