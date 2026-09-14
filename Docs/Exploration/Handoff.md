# 接续记录：2026-09-14 收尾

用户决定今天结束，下一次根据本文继续。今天不再扩展代码或启动新探索。

## 明天从哪里开始

1. 先读本文和 [探索索引](README.md)；仅当定位具体公式异常时，按 ID 查 [公式问题记录](FormulaIssues.md)。不要批量阅读旧文档。
2. 先执行 `git status --short`，保留当前未提交改动、Demo 资源和原始 JSONL。仓库为 `/Users/mgcly/Desktop/GMarkdownResearch/GMarkdown`；不得重置工作区、覆盖原始书籍或运行 Swift 构建/测试，除非用户另行授权。
3. 让用户继续运行 Demo：首页 → **项目书籍测试** → 书架 → 选书与章节 → **分块渲染 / TextView 渲染**。先完成今天尚未分路径记录的回归：
   - 《高中数学必修+选修知识点总结 .pdf》→ 第 11 章“函数单调性知识点”：确认 TextView 的 HTML 图片失败时仅显示 `alt`“递增函数图像”。
   - 《高中化学反应方程式汇总.pdf》→ 第 7 章“硫及其化合物性质”：切换 TextView，确认 `\\ce`、`\\xlongequal` 也不显示红色源码。
4. 再从 [探索索引](README.md) 的 T-001–T-003、I-001–I-002 中挑一个尚未覆盖的最小样本。异常时先逐字对照“原始内容”，区分源数据、解析、公式后端、表格布局和图片加载，再一次只处理一个根因并补记录。

## 今日达成的阶段结果

- 既有公式修复（花括号、编号、中文、行内/块级区分、TextView 横向滚动）保持有效；用户此前浏览约 40 章后反馈基本正常。
- 表格单元格取消两行上限，避免 `<br>` 属性、多行公式与示意图内容被截断。用户已对《高中数学必修 1 知识点》第 3 章的五列表格核对原文，分块和 TextView 的名称、记号、意义、性质、示意图均能对应显示。
- 默认表格样式改为安卓式 1pt `#D1D5DB` 网格、直角、`#F3F4F6` 表头、白色正文；颜色集中在 `DefaultTableStyle`。用户确认当前样式无问题。
- 表格内 HTML `<img>` 现会解析并交给图片加载器；不可用链接加载失败时以透明背景显示原始 `alt` 文本，不再显示灰色占位。分块路径已见“递增函数图像”，TextView 尚未单独验收。
- 化学公式的 `\\ce` 与 `\\xlongequal` 红色源码泄漏已定位为 MathJax 扩展包未加载。SVG 转换器现加载 `TeXInputProcessorOptions.Packages.all`；用户重新运行第 7 章并确认红色源码消失。该次截图为分块渲染，TextView 尚未单独验收。

## 保留的边界与取舍

- 完整 MathJax 包集是通用扩展加载，不仅针对 `\\ce`、`\\xlongequal`；但不在 MathJaxSwift 打包范围内的私有宏或损坏公式，仍可能显示红色未定义命令。这是后续定位信号，不改写源数据掩盖。
- 导出的 manifest 标明 `imageFilesIncluded: false`；无真实资源或不可达 URL 不能验收为位图加载成功，只能验收解析、布局和 `alt` 降级。
- TextView 行内公式略偏上、超宽行内公式等比缩小、标题/粗体/链接内部的双美元公式仍未系统覆盖，不能宣称全量通过。
- 助手始终没有编译、运行 Swift 测试或 Demo；所有视觉结论来自用户运行截图。

## 关键入口

- 原始数据：`Examples/GMarkdownExample/GMarkdownExample/md/projectBook.jsonl` 与 `md/Books/`；只读，不改写。
- 表格：`Sources/Render/GMarkStyle.swift`、`Sources/Render/RenderCells/GMarkTableCell.swift`、`Sources/MarkdownTextView/Providers/MDTableAttachedProvider.swift`。
- 图片：`Sources/Visitor/GMarkupVisitor.swift`、`Sources/Visitor/GMarkupPlugin.swift`、`Examples/GMarkdownExample/GMarkdownExample/NukeImageLoader.swift`。
- 公式：`Sources/Parser/GMarkFormulaMode.swift`、`Sources/Parser/Preprocessor/GMarkPreprocessor.swift`、`Sources/Generator/LaTex/`。
- Demo 页面：`Examples/GMarkdownExample/GMarkdownExample/ProjectContentViewController.swift`。

## 工作原则

以导出原始内容与展示内容能否忠实对应为验收目标，不评价原书数学/化学语义是否正确。保留未提交改动和原始数据；每次修改均记录原因、方案、实际用户验证结果和未覆盖范围，不凭一条路径推断另一条路径通过。
