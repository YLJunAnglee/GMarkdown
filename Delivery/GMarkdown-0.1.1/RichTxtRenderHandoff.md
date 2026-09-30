# richTxt 展示修复续接记录（2026-09-29）

> 2026-09-30 当前决策与下一会话操作见 [NextSessionHandoff.md](./NextSessionHandoff.md)。本文以下各节保留实施时的历史记录；其中“尚未提交”等表述描述当时状态。展示实现后来已提交为 `5be60d3`，当前阶段不再追加 Demo 验证，下一步是整理 0.1.1 交付包。

## 2026-09-30 用户要求的再次 Review

已完成边界、逻辑及架构 Review，详见 [CustomClickableSpanReview.md](./CustomClickableSpanReview.md)。本轮复现并修复重复使用文本 chunk 导致 UIFontMetrics 再次缩放异常；消除同段多标记重复处理；统一虚线样式参数并收窄绘制器入口。用户确认的颜色和间距保持一致。

最终 20 项 HTML 单测 + 2 项 UI 测试通过，检查新增样本及原文章截图；原有 11 个未提交样本哈希一致。结论为有条件通过，限制和证据见 Review 文档。提交状态以 Git 记录为准。

## 2026-09-30 挖空虚线与文字间距

用户要求虚线离文字稍远。新增 `GMarkMarkedTextRenderer`，在 MultiView 文本块中按 MPITextKit 的实际选择区域与整行 used rect 绘制 #4F5CE7 圆点虚线，整行布局框下方留 2 pt。普通下划线不改；源富文本保留原文字、UTF-16 范围及原生下划线回退。标记段落预留至少 5 pt 行间距，末行虚线计入 cell 高度，宽度/字号变化时重建几何。

Review 修复了局部选择区域高度不一致导致虚线错位、跨行选择区域延伸到行尾空白，以及大字号/末行的空间不足。Swift 通过声明既有公开 Objective-C selector 读取选择区域，绕过 MPITextKit umbrella 未导出返回类型的问题；没有修改依赖或替换方法实现。

最终 17 项 HTML 单测及 1 项展示 UI 测试通过，已人工检查截图；范围包含同一行标记对齐、窄宽重排、普通下划线保留、原文范围不变与末行不裁切。证据：`/private/tmp/gmarkdown-cloze-gap-final.xcresult`、`/private/tmp/gmarkdown-cloze-gap-aligned2.xcresult`、`/private/tmp/gmarkdown-cloze-gap-aligned2-attachments`。其他渲染入口不承诺相同间距，未做全设备回归。仍未提交，下一项等用户确认。

## 2026-09-30 挖空下划线样式校正

按用户参考图，将 CustomClickableSpan 下划线改为原生 `single | patternDot`，并单独指定 `underlineColor = #4F5CE7`。文字自身颜色、字号、标记范围不变；普通 u 下划线不受影响。点距和粗细由原生文本引擎决定，未做参考图逐像素复刻。

修改后只读审查未发现新增问题；相关范围/缩放单测与 UI 测试各 1 项通过，并检查模拟器截图。证据：`/private/tmp/gmarkdown-cloze-dots.xcresult`、`/private/tmp/gmarkdown-cloze-dots-attachments`。原有 11 个用户样本哈希未变，仍未提交。

默认无样式正文为 18 pt 系统常规字体、UIColor.label；外层 HTML 样式或调用方 Style 可覆盖，显示字号随 Dynamic Type 缩放。

## 2026-09-30 续接：第 1 项展示能力

用户已授权并完成数字实体、空白/NBSP、dir、CustomClickableSpan 文字/范围/虚线展示。新增 `GMarkHTMLProcessor.process(html:)`，完整 HTML 绕开 Markdown 预处理并复用 GMarkChunk/GMarkdownMultiView。调用方自行选择内容与格式；不读取业务字段，不修改 AIEndorser。

- Demo 原文章及新增合成样本 `editorHTMLDemo` 使用显式 HTML 入口。
- 完成独立只读 Review，问题修复后再审查；最终 16 项 HTML 单测通过，2 项 UI 测试通过并检查 5 张截图。
- 本轮结果：`/private/tmp/gmarkdown-editor-html-final.xcresult`（16 项单测）；`/private/tmp/gmarkdown-editor-html-visual.xcresult`（此前 14 项单测 + 2 项 UI）；截图 `/private/tmp/gmarkdown-editor-html-attachments`。临时证据可能过期。
- 原有 11 个未提交样本保持原样。本轮尚未提交，交付源码副本/校验清单未同步。
- 待验收边界：尚无完整第二类业务原文及期望截图，未做宿主接入或所有设备回归；行内方向采用原生 embedding，不承诺浏览器完整双向隔离。
- 接入、标记 UTF-16 范围、分块与降级约定见 `RichTxtHTMLSupportScope.md`、`EditorHTMLImplementationPlan.md`。
- **停止在第 1 项；下一项须等用户确认。** 以下保留 2026-09-29 的历史记录。

## 目标与边界

- 当前只在 GMarkdown 组件及 GMarkdownExample 中处理真实文章的富文本展示；**不接入或修改 AIEndorser**。
- 输入是桌面导出文件 `/Users/mgcly/Desktop/book-723B1E77-A1BE-4F94-8E4D-64A4FBE99248(1).jsonl`。其中 4 个 `TXT` 块有 `richTxt`，另有 2 个独立 `IMG` 块，但导出中没有图片文件或可直接加载的地址。
- Demo 样本 `Examples/GMarkdownExample/GMarkdownExample/md/markdownBookRichTxt` 是 4 段原始 `richTxt` 按顺序以空行连接，内容与导出字段逐字一致。块标题属于独立字段，未加入样本；图片块也未加入。
- 用户要求解决真实截图中的空项目符号、过大间距、字号/颜色/粗斜体丢失和 Demo 菜单遮挡，同时高度审查架构、逻辑和原有能力。只支持编辑器实际使用的 HTML/CSS 子集，不扩展为完整浏览器。

## 当前工作状态

分支 `explore/capabilities`。richTxt 展示修复已完成 Review；提交状态以 Git 记录为准。后续功能仍按用户确认的范围推进。

已修改并完成审查：

1. `Sources/Visitor/Helpers/GMarkHTMLSanitizer.swift`：在 HTML 块渲染中删除视觉上为空的列表项；加入有限 CSS 文本样式解析（像素字号、十六进制颜色、粗体、斜体、段落 margin-bottom），并把 HTML 文本与 Markdown 的默认段落间距区分开。样式状态也接入了 `GMarkupVisitor` 的行内 HTML 路径。
2. `Examples/GMarkdownExample/GMarkdownExample/MarkdownRenderController.swift`：文章样本成为 Markdown Renderer 默认文件；菜单按钮移入导航栏，避免压住正文。
3. `Examples/GMarkdownExample/GMarkdownExample.xcodeproj/project.pbxproj`：登记新样本资源。
4. `Examples/GMarkdownExample/GMarkdownExample/md/markdownBookRichTxt`：新增真实样本。
5. `Tests/GMarkdownTests/HTMLSanitizerTests.swift` 与 `RichTxtVisualTests.swift`：新增空列表、文本样式、嵌套标签和整篇滚动截图验证；Xcode 测试 target 已登记。

用于模拟器截图的 `ViewController.swift` 临时自动跳转已经**撤回**，该文件应与 HEAD 完全一致。用户此前自己修改的 11 个 `markdownAcceptance*` / `markdownLatex` 文件属于原有未提交改动，**不要覆盖、还原或顺手提交**。

## 已有证据与限制

- 修改前截图：`/private/tmp/gmarkdown-richtext-preview.png`；用户随后给了四张完整滚动截图。原文共有 18 个空 `<li></li>`、24 个 `<br/>`，并使用 `16px/18px`、`#333333/#484D54/#4F5CE7`、粗体、斜体及 `<u>`。
- 修改后在 iPhone 17 / iOS 27 模拟器的**首屏**截图：`/private/tmp/gmarkdown-richtext-fixed.png`。视觉上空项目符号消失，列表明显收紧，蓝色、粗体、18px 标题及下划线出现，菜单不再遮挡首行。临时截图路径可能在下次会话失效；必要时重新运行 Demo。
- 最终工作树使用 `GMarkdownFormulaTests` scheme 完成模拟器构建、单测和 UI 测试；`ViewController.swift` 与 HEAD 一致。Xcode 输出过现有 `GMarkChunk.identifier` 可变 `Sendable` 警告，以及 XCTest 最低部署版本链接警告，与本轮逻辑无关。
- 2026-09-29 最终在 iPhone 17 / iOS 27 Simulator 运行 6 项 HTML 单测及 1 项 UI 测试，7 项通过、0 失败。UI 测试保存首屏、中段、末段截图；检查到空项目符号消失，字号、颜色、粗斜体及下划线生效，菜单位于导航栏。
- Review 修复了列表项关闭时读取整段文本、行内 `margin` 影响段落间距、同名未带样式的内层标签提前关闭外层样式三个问题；`git diff --check` 通过。

## 后续边界

1. 当前实现只覆盖样本中实际使用的 HTML/CSS 子集；其他 CSS 与真实 IMG 块未纳入本轮验收。
2. 不要改写原始样本来掩盖组件问题，不要碰 AIEndorser。**下一项功能须等用户确认**。

## 相关入口

- `Delivery/GMarkdown-0.1.1/RichTxtHTMLSupportScope.md`：2026-09-30 整理的当前 HTML 展示范围、降级行为、入口差异与后续缺口。
- `Sources/Visitor/Helpers/GMarkHTMLSanitizer.swift`：HTML 文本处理共享入口。
- `Sources/Visitor/GMarkupVisitor.swift`：`GMarkdownMultiView` 使用的 HTMLBlock/InlineHTML 路径。
- `Sources/Visitor/GMarkupPlugin.swift`：`MarkdownTextView` 的 HTMLBlock 路径。
- `Examples/GMarkdownExample/GMarkdownExample/MarkdownRenderController.swift`：Demo 页面、样本菜单与加载。
- `Delivery/GMarkdown-0.1.1/ProjectIntegrationExecutionPlan.md`：更早的项目接入计划；其中“先全面扩展 HTML”的优先级已被真实样本驱动的方案取代。
