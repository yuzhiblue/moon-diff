#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate docs/申报书-moon-diff.pdf from docs/申报书-moon-diff.md (8月黑客松版)."""
import os
import re
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
# macOS TTC/TTF with CJK coverage; pick subfont 0
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
    ("项目方向", "MoonBit 基础软件生态 · 文本比对与补丁基础设施"),
    ("是否为移植项目", "否（原创项目）"),
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
    "moon-diff 是一个用 MoonBit 从零实现的文本 diff 与 patch 库，对标 Python difflib、"
    "diff/patch 工具链与 Git 的 diff 能力，为 MoonBit 生态补上版本控制、文本比对与补丁应用"
    "这一基础构件。项目以纯 MoonBit、零外部依赖实现，核心是一套泛型差异引擎（可作用于任意 "
    "Array[T]：行、词元、字符、AST 节点等），之上构建了统一 diff 渲染与回放、Git 风格 diff、"
    "语义 JSON Patch、三路合并、多文件树 diff、Unicode/CJK 友好的词元切分等完整能力。同时附带"
    "一个可运行的 CLI 前端（diff/patch/merge/json/ratio 等子命令），可直接用于日常文本比对与补丁操作。"))

S.append(section("二、核心功能范围"))
S.append(bullets([
    "五种差异算法：经典 LCS（diff）、Myers O(ND) 最小编辑脚本（myers_diff）、Patience（patience_diff）、Histogram（histogram_diff）、线性空间 Hirschberg（diff_linear，仅 O(|a|+|b|) 内存）；",
    "统一 diff 渲染与回放：to_unified 输出 GNU diff -u 风格补丁，apply_unified / apply_unified_fuzzy 还原（兼容 offset/fuzz），apply_unified_reverse 支持 patch -R 逆向应用；",
    "Git 风格与二进制 diff：git_diff_text 输出 diff --git / index &lt;sha&gt; 头，内置从零实现并验证的 SHA-1（git_blob_hash），binary_diff 输出二进制文件差异格式，to_unified_stat 渲染 git diff --stat 风格摘要；",
    "语义 JSON diff（RFC 6902）：json_diff_text 生成对象顺序无关的 JSON Patch，apply_json_patch 回放，形成“生成—应用—还原”闭环；",
    "三路合并：merge3 实现 diff3 区域策略，带冲突标记，支持 git merge -X ours/theirs 风格解析；",
    "多文件树 diff：diff_trees / render_tree_patch / apply_tree_patch 生成并消费 Git 风格多文件补丁，含重命名检测；",
    "Unicode / CJK 友好：tokenize_unicode 按 CJK 字符/词/标点切分，中文、日文、韩文逐字比对；diff_tokens_unicode / word_diff_html_unicode 提供词级内联高亮；ratio 基于 LCS 计算 [0,1] 相似度（类 difflib.ratio），可用于查重与排序；",
    "忽略空白/大小写：diff_lines_ignore 支持 --ignore-whitespace / --ignore-case，同时保留真实内容用于渲染与回放；",
    "工程完备：泛型零依赖设计（T: Eq/Show），前后缀公共段剪枝优化大输入性能，CI（GitHub Actions + CNB 流水线）实跑 moon build + moon test，已发布到 MoonCakes（v0.2.2）。",
]))

S.append(section("三、项目现有基础"))
S.append(bullets([
    "有效 MoonBit 代码约 4,000 行（核心库 3,275 行 + CLI 314 行 + 测试 393 行，物理 4,879 行），处于大赛参考规模区间；",
    "53 个测试（41 个常规测试 + 12 个模糊测试），覆盖五算法重建一致性、最小编辑距离交叉验证、unified/JSON/tree 补丁往返、Unicode tokenizer、ratio 边界、git diff --stat、忽略空白/大小写等，CI 全绿；",
    "自带性能基准（src/bench，对比 Python difflib）与有效代码行统计脚本（docs/loc.py）；",
    "已发布 MoonCakes 包（moon add yuzhiblue/moon-diff 即可使用），仓库公开、构建测试可复现。",
]))

S.append(section("四、本次计划开发或新增的内容"))
S.append(bullets([
    "CLI 文件 I/O 落地：基于 moonbitlang/x/fs 支持真实文件参数（moon run cli -- diff old.txt new.txt、--patch/--merge 等），替代当前转义字符串传参，使示例可对真实文件直接执行；",
    "HTML 高亮渲染完善：扩展 word_diff_html 为完整的行内高亮渲染器（前后缀着色、行号、折叠），并补充配套示例；",
    "新增示例工程：在仓库内提供一个可直接运行的示例（如“配置文件的差异检查/合并工具”），演示库 API 在真实场景的使用；",
    "文档与测试补强：补充英文 API 文档、更多模糊测试用例与性能基准数据，完善 README 的“使用方法”与“示例”章节，确保验收时“文档清楚、示例可执行”。",
]))

S.append(section("五、项目预期目标和技术路线"))
S.append(para(
    "<b>预期目标</b>：在验收时交付一个真实可用、边界清晰、测试完备、文档清楚、可直接接入 "
    "MoonBit 项目的文本 diff/patch 库，成为 MoonBit 生态中文本比对领域的基础设施选项。"))
S.append(para(
    "<b>技术路线</b>：核心引擎按“泛型差异算法层（LCS/Myers/Patience/Histogram/Hirschberg）→ "
    "序列化渲染层（unified/git/binary）→ 应用层（apply/reverse/fuzzy）→ 高层能力"
    "（merge3/JSON Patch/tree diff）”分层构建；正确性以五算法重建一致性测试 + 随机模糊测试交叉验证"
    "+ 与 Python difflib / git 行为对照基准保障；性能采用前后缀公共段剪枝、线性空间算法（Hirschberg）"
    "并持续追踪 benchmark；生态集成以 MoonCakes 发布 + GitHub Actions/CNB 双 CI + 可运行 CLI 示例工程，降低接入门槛。"))

S.append(section("六、预计完成的功能、测试和文档"))
S.append(bullets([
    "功能：上述“本次计划新增的内容”全部落地（文件 I/O、HTML 高亮、示例工程）；",
    "测试：测试总数从 53 增至 70+，新增模糊测试覆盖边界输入（空串、单字符、超长行、非法 UTF-8、深嵌套 JSON 等）；",
    "文档：README 补全 API 用法与示例输出；docs/ 新增英文 API 参考与性能基准报告；申报书与代码仓库保持同步更新。",
]))

S.append(section("七、参赛承诺"))
S.append(para(
    "本项目为作者原创（非移植项目），以 Apache-2.0 协议开源，代码仓库公开可访问、可构建、可测试，"
    "核心功能全部使用 MoonBit 实现，满足大赛验收要求，接受评审与社区反馈。"))

doc.build(S)
print("OK ->", os.path.join(BASE, "申报书-moon-diff.pdf"))
