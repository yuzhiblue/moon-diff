# -*- coding: utf-8 -*-
"""Generate a one-page A4 competition application PDF (Chinese) for moon-diff."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, ListFlowable,
    ListItem, HRFlowable,
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont

pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))
FONT = "STSong-Light"

PAGE_W, PAGE_H = A4
MARGIN = 18 * mm

doc = SimpleDocTemplate(
    r"d:\moonbit\docs\moon-diff-申报书.pdf",
    pagesize=A4,
    leftMargin=MARGIN, rightMargin=MARGIN,
    topMargin=15 * mm, bottomMargin=14 * mm,
    title="moon-diff 项目申报书",
    author="yuzhiblue",
)

styles = {
    "title": ParagraphStyle("title", fontName=FONT, fontSize=17, leading=22,
                            alignment=TA_CENTER, spaceAfter=2,
                            textColor=colors.HexColor("#1a3c6e")),
    "subtitle": ParagraphStyle("subtitle", fontName=FONT, fontSize=10, leading=14,
                               alignment=TA_CENTER, textColor=colors.HexColor("#555555"),
                               spaceAfter=6),
    "h": ParagraphStyle("h", fontName=FONT, fontSize=11.5, leading=16,
                        spaceBefore=8, spaceAfter=3,
                        textColor=colors.HexColor("#1a3c6e")),
    "body": ParagraphStyle("body", fontName=FONT, fontSize=9.3, leading=14,
                           alignment=TA_LEFT, spaceAfter=2),
    "bullet": ParagraphStyle("bullet", fontName=FONT, fontSize=9.3, leading=13.5,
                             spaceAfter=1),
    "footer": ParagraphStyle("footer", fontName=FONT, fontSize=8, leading=11,
                             alignment=TA_CENTER, textColor=colors.HexColor("#888888")),
}

def P(text, s="body"):
    return Paragraph(text, styles[s])

info = [
    ["项目名称", "moon-diff"],
    ["参赛赛道", "基础软件生态 · 库开发（MoonBit 标准库及生态工具）"],
    ["负责人", "yuzhiblue（个人参赛）"],
    ["开发语言", "MoonBit"],
    ["开源协议", "Apache License 2.0"],
    ["仓库地址", "https://github.com/yuzhiblue/moon-diff"],
]
info_table = Table([[P(k, "body"), P(v, "body")] for k, v in info],
                   colWidths=[28 * mm, PAGE_W - 2 * MARGIN - 28 * mm])
info_table.setStyle(TableStyle([
    ("FONTNAME", (0, 0), (-1, -1), FONT),
    ("FONTSIZE", (0, 0), (-1, -1), 9.3),
    ("TEXTCOLOR", (0, 0), (0, -1), colors.HexColor("#1a3c6e")),
    ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#eef2f8")),
    ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#c9d3e3")),
    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ("RIGHTPADDING", (0, 0), (-1, -1), 5),
    ("TOPPADDING", (0, 0), (-1, -1), 3),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
]))

highlights = [
    "双差异算法：经典 LCS 动态规划（diff）与 Myers O(ND) 最小编辑脚本（myers_diff），后者给出编辑距离最短的变更集。",
    "标准统一 diff 格式：to_unified 输出 GNU diff -u 风格补丁（含 @@ 区块头与上下文行），与 Git / patch 工具链兼容，且可通过 apply_unified 完全还原。",
    "零依赖、纯 MoonBit 实现：基于泛型 Array[T]（T: Eq / Show），可对任意序列（行、词元、AST 节点）做差异计算。",
    "工程完备：自带 GitHub Actions CI（moon test + moon build），8 项单元测试覆盖核心路径与补丁往返。",
]

apps = [
    "代码版本控制与差异展示（类 git diff 的基础能力）",
    "文本/文档比对工具、在线协作文档的差异高亮",
    "补丁（patch）系统的生成与应用",
    "任意结构化数据的变更检测与同步",
]

plan = ("当前核心功能（diff / myers_diff / to_unified / apply_unified / diff_lines）已完成，"
        "测试与 CI 就绪，计划于验收前通过 moon publish 发布到 MoonCakes。后续将补充字符/词级 "
        "diff、patch 兼容启发式（fuzz / offset）与性能基准套件。")

promise = ("本作品为作者原创，以 Apache-2.0 协议开源，可公开访问、可构建、可测试，"
           "满足大赛验收要求，并接受评审与社区反馈。")

story = [
    P("MoonBit 开源大赛 · 项目申报书", "title"),
    P("国产基础软件生态开源大赛（MGPIC 2026）", "subtitle"),
    HRFlowable(width="100%", thickness=1, color=colors.HexColor("#1a3c6e"),
               spaceBefore=2, spaceAfter=8),
    info_table,
    Spacer(1, 4),
    P("一、项目简介", "h"),
    P("moon-diff 是一个面向 MoonBit 语言的文本 diff 与 patch 库。它计算两段序列之间的差异，"
      "并提供统一 diff（diff -u 风格）的渲染与回放能力。项目以纯 MoonBit、零外部依赖实现，"
      "旨在为 MoonBit 生态补上版本控制与文本比对领域的基础构件。"),
    P("二、技术亮点", "h"),
    ListFlowable(
        [ListItem(P(t, "bullet"), leftIndent=6, value="•") for t in highlights],
        bulletType="bullet", start="•", leftIndent=10,
    ),
    P("三、应用场景", "h"),
    ListFlowable(
        [ListItem(P(t, "bullet"), leftIndent=6, value="•") for t in apps],
        bulletType="bullet", start="•", leftIndent=10,
    ),
    P("四、当前进度与后续计划", "h"),
    P(plan),
    P("五、参赛承诺", "h"),
    P(promise),
    Spacer(1, 6),
    HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#cccccc"),
               spaceBefore=2, spaceAfter=4),
    P("申报日期：2026-07-07 ｜  负责人：yuzhiblue ｜  仓库：github.com/yuzhiblue/moon-diff",
      "footer"),
]

doc.build(story)
print("PDF generated.")
