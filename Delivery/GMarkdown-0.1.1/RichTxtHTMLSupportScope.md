# richTxt HTML 展示范围与后续缺口（2026-09-30）

## 结论与接入方式

当前实现支持受控的编辑器 HTML 展示子集。GMarkdown 接收调用方传入的字符串；业务自行决定使用 `richTxt`、`txt` 或其他来源，组件不读取业务字段，也不自动切换输入。

完整 HTML 使用显式入口，避免 Markdown 的公式、代码围栏和分段预处理影响 HTML 内容：

```swift
let processor = GMarkHTMLProcessor(style: style)
let chunks = processor.process(html: richText)
markdownView.updateMarkdown(chunks) // GMarkdownMultiView，主线程更新
```

Markdown 继续使用原有 `GMarkProcessor` / `GMarkChunkGenerator`。输入格式由调用方指定，不通过字符串内容猜测。新入口输出沿用现有 `GMarkChunk`，没有修改 `ChunkGenerator` 协议。处理器应先配置再调用；不要一边处理一边并发修改其配置。

本文描述仓库 `Sources` 的当前状态。交付目录中的源码副本、校验清单和较早接入文档尚未同步，不能视为本轮更新后的打包产物。

## 当前行为

| 输入 | 展示行为 | 边界与降级 |
| --- | --- | --- |
| `html`、`body` | 保留正文并继承有限文本样式、方向。 | `head` 及其内容丢弃；不提供浏览器页面布局。 |
| `p`、`div`、`blockquote`、`br` | 保留可读文字与基本换行，按完整段落设置方向和间距。 | 空段及连续空换行不按浏览器逐一保留。 |
| 普通空白、NBSP | ASCII 空白跨行内节点折叠，段落首尾排版空白去除；NBSP 保留为 U+00A0。 | 视觉为空的列表项仍去除，含仅 NBSP 的列表项。 |
| `ul`、`li`、`ol` | `li` 显示项目符号，空列表项去除。 | `ol` 暂无数字序号；嵌套列表不保证分级缩进。 |
| `span`、`strong`/`b`、`em`/`i`、`u`、`s`/`del` | 保留文字及对应样式。 | 有限样式继承，不承诺完整 CSS。 |
| `sup`、`sub`、`code`、`pre` | 沿用上/下标与代码字体处理。 | 未做本轮视觉验收；`pre` 不保留浏览器式空白。 |
| `font-size`、`color` | 接受 8–72 px 字号和 3/6 位十六进制颜色。 | 其他单位、命名色和 `rgb()` 等忽略。 |
| `font-weight`、`font-style` | 支持 `bold`、`bolder`、不小于 600 的数值、`italic`、`oblique` 和有限正常值。 | 不支持完整字重映射。 |
| 块级 `margin`、`margin-bottom` | 仅取合法的 0–100 px 底部段距；行内 margin 不改段距。 | 其他 margin、padding、行高与布局属性忽略。 |
| HTML 实体 | 支持带分号的十进制/十六进制数字实体，以及 `lt`、`gt`、`quot`、`apos`、`amp`、`nbsp`。 | 只解码一次；非法数字码点替换为 U+FFFD，HTML C1 控制字符按映射转换；未知或无分号实体保留原文。 |
| `dir="ltr/rtl/auto"` | 段落方向按作用域继承；auto 使用整个元素的首个强方向字符，跳过另有方向的子元素，无强方向字符时采用 LTR。行内方向单独应用。 | 行内使用原生 writingDirection embedding，不承诺浏览器完整双向隔离语义；不注入隐形控制字符。 |
| `CustomClickableSpan` | 保留可见文字、标记范围与底部 #4F5CE7 点状虚线，虚线随文字自动折行，在 MultiView 文本块中于整行文字布局框下方留 2 pt 间距；标记内普通下划线合并为虚线，文字颜色保持原样。 | 不提供点击、隐藏/恢复、业务 ID。范围约定见下节。 |
| `<a>` 等未专门支持的标签 | 去掉标签，保留可读内部文字。 | 不生成链接或点击行为。 |
| HTML `<img>` | 保留 `alt`（有值时），不使用 `src`。 | 不下载图片；无 alt 时不可见。本轮没有新增图片或失败通知能力。 |
| `script`、`style`、`iframe`、`object`、`embed`、`form`、`video`、`audio`、`svg`、`math`、`template` | 丢弃对应标签和内容，不执行或加载资源。 | 解析器面向受控编辑器输出，不是通用浏览器 DOM 或 HTML 安全清洗接口。 |

## 标记、分块与异常输入约定

- 标记通过 `NSAttributedString.Key.gmarkCustomClickableSpan` 暴露，值是 String；用 `enumerateAttribute` 可读取。范围是**最终 chunk 富文本的 UTF-16 坐标**，不对应源 HTML 偏移。
- 标记 ID 仅在一次解析内有效。嵌套标记使用外层 ID，相邻标记分别生成 ID；相同 ID 可能因 `<br>` 或分块形成多个范围。换行符不属于标记。
- 文本解码、空白折叠先完成，再生成属性范围；emoji 不按 Swift Character 数量计算 NSRange。不插入额外方向控制字符，保证显示字符串与范围一致。
- 段落边界关闭未闭合的行内标签。完整 HTML 使用有限元素树，深度上限 128；超过上限降级处理，不承诺异常嵌套的浏览器恢复结果。
- 分块长度默认 2000 UTF-16 单元，为软上限；单段过长时保留整个段落，不截断字符。HTML `<br>` 输出原生换行，可成为分块边界。超长单段的布局成本仍由原生文本引擎承担。
- MultiView 文本块按 MPITextKit 实际排版区域单独绘制标记虚线；只在渲染副本中替换原生标记下划线，并为标记段落预留至少 5 pt 行间距、为末行预留绘制高度。源富文本的文字/范围保持不变；其他渲染入口仍使用原生下划线回退。
- 同文档、同文字与尺寸但仅样式变化时，页面会重新配置已有条目，避免颜色、方向或标记更新后仍显示旧内容。

## 验证范围

- 原文章样本 `markdownBookRichTxt` 保持不变：来自真实导出的 4 段 `TXT.richTxt`；两个缺少资源的独立 `IMG` 块没有加入。
- 新增 `editorHTMLDemo` 合成样本，覆盖数字实体、NBSP、Markdown 字面字符、跨行标记、普通下划线、相邻标记与方向继承。
- iPhone 17 / iOS 27 Simulator：最终 20 项 HTML 单测通过；另有 2 项 UI 测试通过，并人工检查原文章首/中/末屏及新样本截图。最后一轮 Review 修复重复使用 chunk 的字体二次缩放异常，并统一样式参数、消除重复段落处理，复跑了全部 20 项 HTML 单测及 2 项 UI 测试。
- 单测覆盖一次解码、非法数字、UTF-16/emoji 范围、跨 br/分块标记、方向继承与 auto、精确属性名、注释、闭合恢复、深层输入、字号缩放、空列表图片降级回调及同身份样式刷新。
- 完整第二类业务原文及期望截图尚未取得；合成样本验证不能替代其最终业务视觉验收。未在所有系统版本和设备上回归。

## 入口差异与暂缓工作

| 入口 | 当前范围 |
| --- | --- |
| `GMarkHTMLProcessor` → `GMarkdownMultiView` | 本轮完整 HTML 的正式验证路径；Demo 两个 HTML 样本均使用此入口。 |
| Markdown 中的 HTMLBlock | 使用共享清理器，但 Markdown 分段可能拆开 HTML 上下文；完整 HTML 应使用显式入口。 |
| `GMarkdownMultiView` 的 Markdown 行内 HTML | 保留共享样式处理；没有承诺跨 Markdown 块的 HTML 状态或完整 auto 方向。 |
| `MarkdownTextView` 的行内 HTML | 旧插件仍直接输出原始标签文本，入口统一本轮暂缓。 |

本轮仅完成用户确认的第 1 项展示能力。宿主工程接入、图片/新增失败通知、MarkdownTextView 入口统一均未开展；点击隐藏/恢复、更多标签和 CSS 也不在范围。后续工作等待用户确认。

实现约定见 [EditorHTMLImplementationPlan.md](./EditorHTMLImplementationPlan.md)，历史修复与续接记录见 [RichTxtRenderHandoff.md](./RichTxtRenderHandoff.md)。

本轮独立审查、问题复现与架构说明见 [CustomClickableSpanReview.md](./CustomClickableSpanReview.md)。
