# 接续记录：2026-09-16 定向回归完成

本轮表格与图片定向回归已结束；修复和记录已提交为 `9864757 fix: improve table and image fallback rendering`。下一次根据本文继续，不重做已验证样本。

## 明天从哪里开始

1. 先读本文和 [探索索引](README.md)；仅当定位具体公式异常时，按 ID 查 [公式问题记录](FormulaIssues.md)。不要批量阅读旧文档。
2. 先执行 `git status --short`，保留当前未提交改动、Demo 资源和原始 JSONL。仓库为 `/Users/mgcly/Desktop/GMarkdownResearch/GMarkdown`；不得重置工作区、覆盖原始书籍或运行 Swift 构建/测试，除非用户另行授权。
3. T-001–T-003、I-001–I-002 均已在分块和 TextView 两条路径人工通过；如继续探索，应另选未覆盖的最小样本，不应将这五项重新列为待验证。异常时先逐字对照“原始内容”，区分源数据、解析、公式后端、表格布局和图片加载，再一次只处理一个根因并补记录。

## 今日达成的阶段结果

- 本轮提交 `9864757` 包含表格附件高度、窄表边框范围和 Markdown 图片替代文字链路的修复，以及 T-001–T-003、I-001–I-002 的完整记录；提交后工作区已清洁。
- 既有公式修复（花括号、编号、中文、行内/块级区分、TextView 横向滚动）保持有效；用户此前浏览约 40 章后反馈基本正常。
- 表格单元格取消两行上限，避免 `<br>` 属性、多行公式与示意图内容被截断。用户已对《高中数学必修 1 知识点》第 3 章的五列表格核对原文，分块和 TextView 的名称、记号、意义、性质、示意图均能对应显示。
- 默认表格样式改为安卓式 1pt `#D1D5DB` 网格、直角、`#F3F4F6` 表头、白色正文；颜色集中在 `DefaultTableStyle`。用户确认当前样式无问题。
- 表格内 HTML `<img>` 现会解析并交给图片加载器；不可用链接加载失败时以透明背景显示原始 `alt` 文本，不再显示灰色占位。已在《高中数学必修+选修知识点总结 .pdf》第 11 章“函数单调性知识点”的 TextView 验证：失败图片处仅显示 `alt`“递增函数图像”（按列宽换行），没有灰色占位、URL 或源码。截图：`/private/tmp/gmarkdown-math-ch11-image-alt.png`。
- 化学公式的 `\\ce` 与 `\\xlongequal` 红色源码泄漏已定位为 MathJax 扩展包未加载。SVG 转换器现加载 `TeXInputProcessorOptions.Packages.all`；已在《高中化学反应方程式汇总.pdf》第 7 章“硫及其化合物性质”的 TextView 验证：化学式正常排版，`\\xlongequal` 显示带“催化剂 / Δ”的长等号，未见红色源码。截图：`/private/tmp/gmarkdown-chem-ch7-correct-textview.png`。

## T-001：TextView 表格末行分隔线未闭合（2026-09-15）

- **复现：**《概率论与数理统计》第 29 章“概率计算例题汇总”。用户截图中分块渲染的 3 列 × 4 行表格正常；TextView 渲染的外框底边仍在，但第 2、3 列的竖线在末行底部前提前结束，未与底边闭合。
- **原始内容对照：**用户已打开“原始内容”。第 2 块为完整的三列 Markdown 表格，表头为“元件制造厂 / 次品率 / 提供元件的份额”，数据行 `1 / 0.02 / 0.15`、`2 / 0.01 / 0.80`、`3 / 0.03 / 0.05`；源数据不存在缺列、缺行或不闭合的表格标记。
- **原因：**TextView 的 `MDTableAttachedProvider` 直接把通用 `GMarkTableLayout.tableHeight` 用作附件高度。该高度包含只适用于分块外层的上下留白，但没有计入 TextView 网格本身的行间线和外边框；附件比网格内容高，造成末行内部分隔线不能接到底边。
- **修改：**`Sources/MarkdownTextView/Providers/MDTableAttachedProvider.swift` 现仅在 TextView 附件处换算高度：移除外层留白，补上行间线与上下边框，使附件高度与 `GMarkTableView` 网格高度一致。不改共享表格布局、分块路径或原始 JSONL。
- **验证结果（2026-09-15，用户运行）：**同一章节的 TextView 末行第 2、3 列竖线现已连接到底边；分块渲染表格也正常，未回归。两条路径通过。助手未编译、未运行 Swift 测试或 Demo。

## T-002：窄表右侧出现伪空列（2026-09-15）

- **复现：**《概率论与数理统计》第 72 章“二维联合分布律介绍”。分块渲染中，第 2 个表格在标题 `4` 后出现带外框的大块空白，数据行横线也只画到实际第 5 列的右边界；第 1 个六列表中的 `\\diagdown`、下标、`\\cdots` 与 `\\vdots` 正常显示，无红色源码。
- **原始内容对照：**用户已打开“原始内容”。第 4 块原始 Markdown 表格明确只有 5 列：`X\\!\\diagdown\\! Y`、`1`、`2`、`3`、`4`；各数据行也都是 5 列，不含空白第 6 列。
- **原因：**分块路径的 `GMarkTableView` 以父容器全宽画外边框，但窄表的列网格按自然宽度排列；因此实际网格右侧被外框包成伪空列。
- **修改：**`Sources/Render/Table/GMarkTableView.swift` 现在将外边框限制在网格的自然宽高内。窄表不再显示伪空列；宽表仍以容器宽作为视区，保留横向滚动。
- **验证结果（2026-09-15，用户运行）：**两条路径通过。分块路径第 1 个六列表出现横向滚动提示，`\\diagdown`、下标、`\\cdots`、`\\vdots` 正常显示；第 2 个五列分数表的外框现紧贴 `4` 列，伪空列已消失，分数与网格正常。TextView 路径的两张表也均显示完整：公式、网格和末行正常，无伪空列或红色源码。助手未编译、未运行 Swift 测试或 Demo。

## T-003：复杂公式表格（2026-09-15）

- **样本：**《概率论与数理统计》第 200 章“假设检验相关内容”，含 `\\begin{aligned}`、多行公式、分数与中文 `\\text{}` 的五列表格。
- **验证结果（2026-09-15/16，用户运行）：**两条路径通过。分块路径及 TextView 路径的截图均覆盖左、中、右横向视区：原假设、检验统计量、备择假设和拒绝域均可连续查看；多行公式、分数和中文显示完整，行高、网格与横向滚动正常，未见红色源码或单元格截断。助手未编译、未运行 Swift 测试或 Demo。

## I-001：Markdown 图片加载失败未显示替代文字（2026-09-16）

- **样本与原始内容：**《概率论与数理统计》第 224 章“假设检验p值讲解”，第 1 块。用户通过“原始内容”确认图片标记为 `![图8-7](此处为原书图示内容，标注两个标准正态分布图……)`；括号内是说明文字，不是可访问 URL，因此没有可加载的位图资源。
- **复现：**分块渲染在图片处保留空白区域，但未显示 `alt`“图8-7”。这不是图片节点或源数据丢失。
- **原因：**分块 `GMarkupVisitor.visitImage` 未把 Markdown 图片的替代文字传给已有的图片加载失败回调。TextView 的 `DefaultImagePlugin` 也未把配置的 `imageLoader` 传给 `MDAsyncImageAttachedProvider`，因而同样无法使用统一降级逻辑。
- **修改：**分块路径现将 `Image.plainText` 作为 `fallbackText`；TextView 图片附件保存同一替代文字，且由插件传入外层 `imageLoader`。两条路径继续使用 Demo 的透明背景、系统字体文本降级，不请求或伪造图片。
- **验证结果（2026-09-16，用户运行）：**两条路径通过。分块与 TextView 的不可加载图片位置均显示“图8-7”，没有灰色占位或源码；前后公式与正文连续正常。保留原图片附件的版面高度，避免加载失败时内容跳动。助手未编译、未运行 Swift 测试或 Demo。

## I-002：无 `src` 的表格 HTML 图片（2026-09-16）

- **样本与原始内容：**《概率论与数理统计》第 364 章“平稳过程习题解答”，第 2 块。用户通过“原始内容”确认表格含 8 个 `<img>`；每个仅有 `width`、`height` 与 `alt`，没有 `src`。`alt` 中包含中文说明和 LaTeX，因此不存在可加载位图，也不能把原始 `alt` 作为公式源码显示。
- **验证结果（2026-09-16，用户运行）：**两条路径通过。三个表格列及第 4–7 行保持完整，图片单元格按固定尺寸留白；未显示原始 HTML、`alt` 或 LaTeX 源码，未破坏行高、网格或后续正文。无需为缺少 `src` 的源数据新增加载或降级代码。助手未编译、未运行 Swift 测试或 Demo。

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
