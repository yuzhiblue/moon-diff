#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate docs/申报书-moon-diff.pdf from docs/申报书-moon-diff.md (8月黑客松版)."""
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.lib import colors
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                ListFlowable, ListItem, Table, TableStyle)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

BASE = os.path.dirname(os.path.abspath(__file__))
FONT_CANDIDATES = [
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc",
    "/System/Library/Fonts/Supplemental/Songti.ttc",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
]

def find_font():
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return p
    raise RuntimeError("no CJK font found")

font_path = find_font()
pdfmetrics.registerFont(TTFont("CJK", font_path, subfontIndex=0))

styles = getSampleStyleSheet()
title_st = ParagraphStyle("t", parent=styles["Title"], fontName="CJK",
                          fontSize=17, leading=22, spaceAfter=2, alignment=TA_LEFT)
sub_st = ParagraphStyle("s", parent=styles["Normal"], fontName="CJK",
                        fontSize=10.5, leading=14, textColor=colors.HexColor("#555555"),
                        spaceAfter=10)
h_st = ParagraphStyle("h", parent=styles["Heading2"], fontName="CJK",
                      fontSize=12.5, leading=16, spaceBefore=9, spaceAfter=4,
                      textColor=colors.HexColor("#1a1a1a"))
body_st = ParagraphStyle("b", parent=styles["Normal"], fontName="CJK",
                         fontSize=10, leading=15.5, spaceAfter=3)
field_st = ParagraphStyle("f", parent=styles["Normal"], fontName="CJK",
                          fontSize=10, leading=15)
bullet_st = ParagraphStyle("bu", parent=body_st, leftIndent=4, spaceAfter=2)
cell_st = ParagraphStyle("c", parent=styles["Normal"], fontName="CJK",
                         fontSize=9.5, leading=13.5)

def para(t): return Paragraph(t, body_st)

def field(k, v):
    return Paragraph(f'<b>{k}</b>：{v}', field_st)

def section(t): return Paragraph(t, h_st)

def bullets(items):
    lis = [ListItem(Paragraph(x, bullet_st), leftIndent=10) for x in items]
    return ListFlowable(lis, bulletType="bullet", start="•", bulletFontName="CJK",
                        bulletFontSize=9, leftIndent=12)

doc = SimpleDocTemplate(
    os.path.join(BASE, "申报书-moon-diff.pdf"),
    pagesize=A4, leftMargin=20*mm, rightMargin=20*mm,
    topMargin=18*mm, bottomMargin=18*mm,
    title="moon-diff 项目申报书（8月黑客松）",
    author="yuzhiblue",
)

S = []
S.append(Paragraph("moon-diff 项目申报书", title_st))
S.append(Paragraph("2026 MoonBit 国产基础软件生态开源大赛 · 8月黑客松", sub_st))

info = [
    ("项目名称", "moon-diff — MoonBit 文本 diff &amp; patch 库"),
    ("参赛者", "yuzhiblue"),
    ("联系方式", "630110598@qq.com"),
    ("GitHub 仓库", "https://github.com/yuzhiblue/moon-diff"),
    ("项目方向", "MoonBit 基础软件生态 · 文本比对与补丁"),
    ("是否为移植项目", "否"),
]
rows = [[Paragraph(f"<b>{k}</b>", cell_st), Paragraph(v, cell_st)] for k, v in info]
tbl = Table(rows, colWidths=[30*mm, 140*mm])
tbl.setStyle(TableStyle([
    ("FONTNAME", (0, 0), (-1, -1), "CJK"),
    ("FONTSIZE", (0, 0), (-1, -1), 9.5),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("TOPPADDING", (0, 0), (-1, -1), 1.5),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5),
    ("LEFTPADDING", (0, 0), (-1, -1), 0),
    ("RIGHTPADDING", (0, 0), (-1, -1), 0),
]))
S.append(tbl)
S.append(Spacer(1, 4))

S.append(section("一、项目简介"))
S.append(para(
    "moon-diff 是一个用 MoonBit 写的文本 diff 和 patch 库，对标 Python difflib 和 "
    "diff/patch 工具链。纯 MoonBit 实现，零外部依赖，核心是一套泛型差异引擎，可以作用在任意 "
    "Array[T] 上（行、词、字符、AST 节点都可以）。上面构建了统一 diff 渲染与回放、Git 风格 "
    "diff、语义 JSON Patch、三路合并、多文件树 diff、Unicode/CJK 分词等能力，另外带一个可运行的 "
    "CLI 前端，日常比对文本、打补丁可以直接用。"))

S.append(section("二、核心功能范围"))
S.append(bullets([
    "五种差异算法：经典 LCS、Myers O(ND)、Patience、Histogram、线性空间 Hirschberg（只用 O(|a|+|b|) 内存）；",
    "统一 diff 渲染与回放：to_unified 输出 GNU diff -u 风格补丁，apply_unified / apply_unified_fuzzy 还原（兼容 offset/fuzz），apply_unified_reverse 支持 patch -R 逆向应用；",
    "Git 风格与二进制 diff：git_diff_text 输出 diff --git / index 头，内置从零实现并验证的 SHA-1，binary_diff 输出二进制文件差异，to_unified_stat 渲染 git diff --stat 风格摘要；",
    "语义 JSON diff（RFC 6902）：json_diff_text 生成对象顺序无关的 JSON Patch，apply_json_patch 回放；",
    "三路合并：merge3 实现 diff3 区域策略，带冲突标记，支持 ours/theirs 解析；",
    "多文件树 diff：diff_trees / render_tree_patch / apply_tree_patch，Git 风格多文件补丁，含重命名检测；",
    "Unicode / CJK 友好：tokenize_unicode 按 CJK 字符/词/标点切分，中日韩文本可以逐字比对；ratio 基于 LCS 算相似度，可用来查重；",
    "忽略空白/大小写：diff_lines_ignore 支持 --ignore-whitespace / --ignore-case，渲染和回放时保留真实内容。",
]))

S.append(section("三、移植或参考说明"))
S.append(para("本项目为原创项目，不是移植项目。实现时参考了以下项目的思路和格式约定："))
S.append(bullets([
    "Python 标准库 difflib（ratio 相似度算法、SequenceMatcher 的匹配块思路）；",
    "GNU diff / patch 工具（unified diff 格式、offset/fuzz 容错行为）；",
    "Git（diff --git / index 头格式、blob SHA-1、git diff --stat 摘要、三路合并冲突标记）；",
    "RFC 6902 JSON Patch 规范（语义 JSON diff 的操作格式）；",
    "Myers / Patience / Histogram / Hirschberg 等算法的公开论文与实现。",
]))
S.append(para("本项目使用 Apache-2.0 协议开源，仓库公开可访问、可构建、可测试。"))

doc.build(S)
print("OK ->", os.path.join(BASE, "申报书-moon-diff.pdf"))
