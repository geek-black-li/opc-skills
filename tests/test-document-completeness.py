#!/usr/bin/env python3
"""Static template checks, not proof of generated project correctness."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PRD = ROOT / "skills-custom/01-product/zx-product-prd/assets/PRD-模板.md"
TECH = ROOT / "skills-custom/03-fullstack-arch-dev/zx-dev-architecture/assets/技术设计文档-模板.md"


def section(text, heading):
    """Body under an exact heading, excluding peer and parent sections."""
    lines = text.splitlines()
    start = lines.index(heading)
    depth = len(heading) - len(heading.lstrip("#"))
    end = len(lines)
    for index in range(start + 1, len(lines)):
        match = re.match(r"^(#{1,6}) ", lines[index])
        if match and len(match[1]) <= depth:
            end = index
            break
    return "\n".join(lines[start + 1:end])


def tables(text):
    """Read plain template tables outside fences and validate their structure."""
    result, current = [], []
    fence = None
    for line in text.splitlines() + [""]:
        marker = re.match(r"^(`{3,}|~{3,})", line)
        if marker:
            if fence is None:
                fence = marker[1]
            elif marker[1][0] == fence[0] and len(marker[1]) >= len(fence):
                fence = None
            continue
        if fence:
            continue
        if line.startswith("|"):
            current.append([cell.strip() for cell in line.strip().strip("|").split("|")])
        elif current:
            assert len(current) >= 3, "table needs a header, separator and fillable row"
            assert all(len(row) == len(current[0]) for row in current), current
            assert all(re.fullmatch(r":?-{3,}:?", cell) for cell in current[1]), current[1]
            result.append(current)
            current = []
    assert fence is None, "unclosed Markdown fence"
    return result


def require_columns(body, expected):
    matches = [table for table in tables(body) if expected <= set(table[0])]
    assert matches, f"missing definition columns: {sorted(expected)}"
    assert all(cell for cell in matches[0][2]), "definition slots must be explicit"


DB_HEADING = "### 4.6 数据库设计（需要持久保存业务数据时）"
API_HEADING = "### 4.7 接口或事件（存在调用边界时）"


def check_technical(text):
    tables(text)
    rows = tables(section(text, "## 0. 文档信息"))[0]
    assert any(row[0] == "设计深度／覆盖范围" and all(
        value in row[1] for value in ("概要设计", "详细设计", "完整项目", "局部修改")
    ) for row in rows)
    require_columns(section(text, "### 2.2 技术栈与运行组成"),
                    {"组成与用途", "采用的技术", "版本依据／配置位置", "当前或计划状态"})
    db = section(text, DB_HEADING)
    require_columns(db, {"字段", "含义与来源", "类型／长度", "必填／空值", "默认值／生成方式", "主键／关联／校验"})
    require_columns(db, {"查询或业务规则", "涉及字段与顺序", "约束／索引设计", "选择理由与验证"})
    require_columns(section(text, API_HEADING),
                    {"方向与位置", "字段", "类型／格式", "必填／空值／默认", "规则与说明"})
    for heading in ("### 4.9 前端实现（有前端且本次涉及时）", "### 交接结论"):
        body = section(text, heading)
        assert body.strip() and "{" in body, f"missing fillable section: {heading}"


def check_prd(text):
    tables(text)
    require_columns(section(text, "## 3. 功能与关键规则"),
                    {"输入或输出", "业务含义与来源", "必填／默认", "格式、范围或计算规则", "错误时的用户表现", "状态与依据"})


def must_reject(fn, text):
    try:
        fn(text)
    except (AssertionError, ValueError):
        return
    raise AssertionError("incomplete template was accepted")


technical = TECH.read_text(encoding="utf-8")
prd = PRD.read_text(encoding="utf-8")
check_technical(technical)
check_prd(prd)

# Headings alone, or a definition moved to an unrelated appendix, are insufficient.
for heading in (DB_HEADING, API_HEADING):
    body = section(technical, heading)
    incomplete = technical.replace(body, "\n{待补充}\n", 1)
    must_reject(check_technical, incomplete)
    must_reject(check_technical, incomplete + "\n## 附录\n" + body)

must_reject(check_technical, technical.replace("主键／关联／校验", "备注"))
must_reject(check_technical, technical.replace("必填／空值／默认", "备注"))
must_reject(check_prd, prd.replace("格式、范围或计算规则", "备注"))
must_reject(check_prd, prd.replace("| 必填／默认 |", "| 必填／默认 | 多余列 |"))
must_reject(check_technical, technical + "\n```mermaid\nflowchart TD\n")

# Extra detail must not fail merely because it makes the template longer.
check_technical(technical + "\n## 补充说明\n" + "可按实际场景展开。\n" * 400)
check_prd(prd + "\n## 补充说明\n" + "可按实际场景展开。\n" * 250)

print("Document completeness: definition slots, Markdown structure and negative cases passed (static checks only).")
