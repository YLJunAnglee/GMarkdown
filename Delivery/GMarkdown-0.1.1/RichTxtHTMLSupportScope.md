# richTxt HTML 展示范围与后续缺口（2026-09-30）

## 结论与适用范围

当前交付的是**受控的文章展示子集**，不是通用 HTML 渲染器。已验收的路径是：将真实导出中的 4 段 `TXT.richTxt` 原样提取为 Demo 文件，交给 `GMarkProcessor + GMarkdownMultiView` 展示。两个独立 `IMG` 块没有可用图片资源，不在样本内。Demo 尚未实现从书籍数据自动执行“`richTxt` 非空优先，否则展示 `txt`”的输入选择规则；这项规则仍属项目接入工作。

本文件记录 2026-09-29 修复后的源码状态。交付目录中较早的 README、项目接入计划和能力对照仍描述修复前快照；对于 richTxt HTML 的当前实现，以本文件和下方源码入口为准。交付源码副本及其校验清单尚未同步。

当前样本实际出现：`p` 14 个、`span` 72 个、`ul` 6 个、`li` 34 个、`br` 24 个、`u` 17 个；CSS 仅有 `font-size`、`color`、`font-weight`、`font-style`、`margin`。其中 18 个空 `li` 在 HTML 块路径被去除。2026-09-29 的 iPhone 17 / iOS 27 模拟器验证覆盖了 6 项单测及 1 项整篇 UI 测试，7 项通过。以下“已验证”仅指这条路径和这些输入。

## 当前行为

| 输入 | `GMarkdownMultiView` 的 HTML 块路径 | 边界与降级 |
| --- | --- | --- |
| 普通文字、`p`、`div`、`blockquote`、`br` | 保留可读文字与基本换行；HTML 正文使用独立于 Markdown 默认段距的间距。 | 不复刻浏览器布局；空白文本节点会被丢弃，输入若依赖标签之间单独的空格，需另测。 |
| `ul`、`li` | `li` 显示项目符号；纯空白、仅换行或空图片替代文字的列表项被去除。 | `ol` 没有数字序号支持，会按项目符号展示；嵌套列表没有分级缩进保证。 |
| `span`、`strong`/`b`、`em`/`i`、`u`、`s`/`del` | 保留对应文字样式；已在真实文章验证粗体、斜体、下划线。 | 仅保证已验证组合；复杂 CSS 继承及混合排版没有完整 HTML 语义保证。 |
| `sup`、`sub`、`code`、`pre` | 代码中有上/下标与代码字体处理。 | 本轮真实文章没有这些标签，未做视觉验收；`pre` 不保证浏览器式空白保留。 |
| `style` 中的 `font-size`、`color` | 接受 8–72 px 字号、3/6 位十六进制颜色；不合法值被忽略。 | `rem`、`em`、百分比、命名色、`rgb()` 等均不解析，使用组件默认字体或颜色。 |
| `font-weight`、`font-style` | 识别粗体/斜体及有限的正常值；粗体支持 `bold`、`bolder`、数值不小于 600，斜体支持 `italic`、`oblique`。 | 其他值被忽略；不承诺完整字体权重映射。 |
| 块级标签的 `margin`、`margin-bottom` | 仅取合法的 0–100 px 底部段距；行内标签的 `margin` 不改段距。 | 其他方向的 margin、padding、行高、对齐和布局属性均不呈现。 |
| `<a>` 等未知/未专门处理的标签 | 通常去掉标签、保留可读内部文字。 | 不生成链接或点击行为；`<CustomClickableSpan>` 当前也只保留文字，不保留可交互范围和底部虚线。 |
| HTML `<img>` | 保留 `alt` 文字（有值时），不使用 `src`。 | 无 `alt` 时没有可见图片内容；不会下载或显示 HTML 图片。独立 `IMG` 块属于项目数据层，未由本样本验证。 |
| `script`、`style`、`iframe`、`object`、`embed`、`form`、`video`、`audio`、`svg`、`math`、`template` | 标签及其内部内容被丢弃。 | 不执行脚本、嵌入内容或外部资源。 |
| HTML 实体 | 仅显式解码 `&lt;`、`&gt;`、`&quot;`、`&#39;`、`&amp;`。 | 十进制/十六进制数字字符实体及其他命名实体没有完整解码支持。 |

上述实现位于 [`GMarkHTMLSanitizer.swift`](../../Sources/Visitor/Helpers/GMarkHTMLSanitizer.swift)。它不是严格 HTML 解析器；残缺标签、特殊空白、复杂嵌套以及浏览器布局不能按完整 HTML 规范推断结果。

## 渲染入口差异

| 入口 | 现状 | 验收结论 |
| --- | --- | --- |
| `GMarkdownMultiView` 的 HTML 块 | 使用共享清理器；真实文章样本和整篇 UI 已验证。 | 本轮正式验收路径。 |
| `GMarkdownMultiView` 的行内 HTML | 使用共享状态处理行内标签及相邻文本；已有针对样式栈的单测。 | 尚未用独立的真实行内 HTML 文章做整页视觉验收。 |
| `MarkdownTextView` 的 HTML 块 | 使用同一清理器。 | 没有本轮整页视觉验收。 |
| `MarkdownTextView` 的行内 HTML | 仍由旧插件直接输出原始标签文本。 | **不具备与 `GMarkdownMultiView` 一致的受控 HTML 展示能力**；需要单独修复和回归。 |

## 后续开发顺序

1. **先补现有业务契约已提出的缺口，再考虑扩展通用标签。** 已给出的另一类编辑器样本含 `<html>`、`<body>`、数字字符实体、`dir` 和 `<CustomClickableSpan>`。其中 `html/body` 的文字可读，但数字实体、方向样式和自定义标记范围/虚线尚不满足契约。应取得可复现的脱敏原文和期望画面，逐项实现并测试。
2. **完成项目输入与降级契约。** 在数据适配层实现 `richTxt` 非空优先、否则 `txt` 的规则。组件现有 `GMarkChunkGenerator.onRenderIssue` 已报告部分公式与图片降级，异步图片失败需加载器实现 `GMarkReportingImageLoader`；HTML 解析失败尚无完整事件，宿主接入和真实页面回归也未完成。独立图片沿用项目自定义 Cell 方案，但需有图片资源和失败预期才能验收。
3. **按需要统一渲染入口。** 若项目会使用 `MarkdownTextView` 展示行内 HTML，先修复其旧插件路径并做一致性回归；若只使用 `GMarkdownMultiView`，以实际入口为验收基准。
4. **新标签或 CSS 由真实数据驱动。** 对每种新输入记录原文、所属字段、目标画面、缺失资源和可接受降级，再增加最小实现及回归。`ol` 编号、复杂嵌套、更多颜色/单位、链接与图片加载等，都不因“HTML”名称而自动纳入当前承诺。

本清单用于确定现阶段能力和后续投入，不表示上述待办已经开发或验收。业务契约原文见 [`ProjectIntegrationCapabilityGap.md`](./ProjectIntegrationCapabilityGap.md)；本轮修复与证据见 [`RichTxtRenderHandoff.md`](./RichTxtRenderHandoff.md)。
