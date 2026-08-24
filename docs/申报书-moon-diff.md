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

## 移植或参考说明

本项目为原创项目，不是移植项目。实现时参考了以下项目的思路和格式约定（仅参考公开的算法思路、格式规范与接口行为，未复制其源代码）：

- Python 标准库 difflib（ratio 相似度算法、SequenceMatcher 的匹配块思路）— 许可证：Python Software Foundation License（PSFL）
- GNU diff / patch 工具（unified diff 格式、offset/fuzz 容错行为）— 许可证：GPL-3.0-or-later
- Git（diff --git / index 头格式、blob SHA-1、git diff --stat 摘要、三路合并冲突标记）— 许可证：GPL-2.0-only
- RFC 6902 JSON Patch 规范（语义 JSON diff 的操作格式）— IETF Trust 版权，代码组件为 Simplified BSD License
- Myers / Patience / Histogram / Hirschberg 等算法 — 公开学术论文（Myers 1986、Hirschberg 1975 等），属公开文献

### 来源合规声明

本项目全部代码为作者原创 MoonBit 实现，仅参考上述公开的开源项目与文献的思路和格式，未复制、改写或包含任何私有代码、闭源代码、商业代码或来源不明的内容；项目以 Apache-2.0 协议开源，仓库公开可访问、可构建、可测试。
