# {{origin_label}}：{{category_name}} Skill

- 分类 ID：`{{category_id}}`
- Skill 分类词：`{{skill_token}}`
- 分类定位：{{scope}}

## 包含范围

{{includes}}

## 不包含范围

{{excludes}}

## 存放规则

本目录只存放属于 `{{category_id}}` 的{{origin_label}} Skill。每个 Skill 使用独立目录 `<skill-id>/`，正式入口为 `skill.yaml`，按需附带 `scripts/`、`references/` 或 `assets/`。

ID 规则：{{id_rule}}。custom Skill 固定使用 `zx-{{skill_token}}-<function>`，功能段优先一个通俗单词、最多两个。

能由已有分类合理负责的能力应放回已有分类；不得按客户名、项目名或单个 Skill 名继续拆分类。待评估的第三方内容仍必须先进入 `skills-temp-inbox`。
