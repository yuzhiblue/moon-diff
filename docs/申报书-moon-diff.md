# moon-diff 项目申报书

## 基本信息

- **项目名称**：moon-diff — MoonBit 文本 diff & patch 库
- **参赛者**：yuzhiblue
- **联系方式**：630110598@qq.com
- **GitHub 仓库**：https://github.com/yuzhiblue/moon-diff
- **项目方向**：MoonBit 基础软件生态 · 文本比对与补丁
- **是否为移植项目**：否

## 项目简介

moon-diff 是一个用 MoonBit 写的文本 diff 和 patch 库，对标 Python difflib 和 diff/patch 工具链。纯 MoonBit 实现，零外部依赖，核心是一套泛型差异引擎，可以作用在任意 Array[T] 上（行、词、字符、AST 节点都可以）。上面构建了统一 diff 渲染与回放、Git 风格 diff、语义 JSON Patch、三路合并、多文件树 diff、Unicode/CJK 分词等能力，另外带一个可运行的 CLI 前端，日常比对文本、打补丁可以直接用。

## 核心功能范围

- **五种差异算法**：经典 LCS、Myers O(ND)、Patience、Histogram、线性空间 Hirschberg（只用 O(|a|+|b|) 内存）
- **统一 diff 渲染与回放**：to_unified 输出 GNU diff -u 风格补丁，apply_unified / apply_unified_fuzzy 还原（兼容 offset/fuzz），apply_unified_reverse 支持 patch -R 逆向应用
- **Git 风格与二进制 diff**：git_diff_text 输出 diff --git / index 头，内置从零实现并验证的 SHA-1，binary_diff 输出二进制文件差异，to_unified_stat 渲染 git diff --stat 风格摘要
- **语义 JSON diff（RFC 6902）**：json_diff_text 生成对象顺序无关的 JSON Patch，apply_json_patch 回放
- **三路合并**：merge3 实现 diff3 区域策略，带冲突标记，支持 ours/theirs 解析
- **多文件树 diff**：diff_trees / render_tree_patch / apply_tree_patch，Git 风格多文件补丁，含重命名检测
- **Unicode / CJK 友好**：tokenize_unicode 按 CJK 字符/词/标点切分，中日韩文本可以逐字比对；ratio 基于 LCS 算相似度，可用来查重
- **忽略空白/大小写**：diff_lines_ignore 支持 --ignore-whitespace / --ignore-case，渲染和回放时保留真实内容

## 项目现有基础

- 有效 MoonBit 代码约 4,000 行（物理 4,879 行）
- 53 个测试（41 个常规 + 12 个模糊测试），CI 全绿
- 已发布到 MoonCakes（v0.2.2），moon add yuzhiblue/moon-diff 即可使用
- 仓库公开，构建测试可复现

## 本次计划开发或新增的内容

- CLI 文件 I/O：基于 moonbitlang/x/fs 支持真实文件参数（moon run cli -- diff old.txt new.txt），替代现在的转义字符串传参
- HTML 高亮渲染：扩展 word_diff_html 为完整的行内高亮渲染器（着色、行号），补配套示例
- 新增示例工程：仓库里放一个可直接运行的示例（配置文件差异检查/合并工具）
- 文档与测试补强：补充 API 文档、更多模糊测试用例

## 项目预期目标和技术路线

预期目标：交付一个真实可用、测试完备、文档清楚的 MoonBit 文本 diff/patch 库，能直接接入项目使用。

技术路线：核心引擎按"差异算法层 → 渲染层（unified/git/binary）→ 应用层（apply/reverse/fuzzy）→ 高层能力（merge3/JSON Patch/tree diff）"分层；正确性靠五算法重建一致性测试 + 随机模糊测试交叉验证 + 与 Python difflib / git 对照基准；性能用前后缀公共段剪枝和线性空间算法（Hirschberg）。

## 预计完成的功能、测试和文档

- 功能：上面"本次计划新增的内容"全部落地
- 测试：从 53 个增至 70+，新增边界输入用例（空串、单字符、超长行、非法 UTF-8、深嵌套 JSON 等）
- 文档：README 补全 API 用法和示例输出，docs/ 新增英文 API 参考和性能基准报告

## 移植或参考说明

本项目为原创项目，不是移植项目。实现时参考了以下项目的思路和格式约定：

- Python 标准库 difflib（ratio 相似度算法、SequenceMatcher 的匹配块思路）
- GNU diff / patch 工具（unified diff 格式、offset/fuzz 容错行为）
- Git（diff --git / index 头格式、blob SHA-1、git diff --stat 摘要、三路合并冲突标记）
- RFC 6902 JSON Patch 规范（语义 JSON diff 的操作格式）
- Myers / Patience / Histogram / Hirschberg 等算法的公开论文与实现

本项目使用 Apache-2.0 协议开源，仓库公开可访问、可构建、可测试。
