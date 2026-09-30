# CustomClickableSpan 展示 Review（2026-09-30）

## 范围与结论

审查自定义标签解析、UTF-16 标记、点状虚线绘制、分块、容器重排、Dynamic Type、Cell 复用与同身份刷新，以及本轮全部改动涉及的调用链。保留用户确认的 #4F5CE7、2 pt 间距、1.2 pt 线宽、3.5 pt 点距。未开展业务交互、通用标签注册、TextView 统一或图片功能。

**结论：有条件通过（pass with risks）。** 复现并修复一个重复更新引发的字体缩放异常，另修正重复段落处理和样式参数分散问题。修复后已再次只读审查，当前支持路径没有发现未解决的阻断问题。限制见最后一节。

## 发现与处理

### 1. P1：重复使用已显示的文本 chunk 会再次缩放字体（已修复）

复现：视图先显示普通 chunk，切换为带标记的 chunk，再重新显示之前的普通 chunk。`updateMarkdown` 将已经缩放过的样式与富文本当作原始输入，`UIFontMetrics` 抛出 `NSInvalidArgumentException`：scaled font 不能再次用于 scaledFont。

最初异步 XCTest 用例表现为任务分配器崩溃；改用同步测试与 XCTest expectation 后得到上述明确异常，证明不能仅将其归为测试环境问题。

处理：

- `DynamicTypeFontStyle` 保存原始字体配置，再次构建时恢复原始配置。
- `GMarkChunk` 保存原始文本与不可变显示快照；同一 chunk 再次输入时恢复原始文本。调用方重新赋值的富文本被视为新输入。
- `GMarkdownMultiView` 从原始文本保存本轮字体及附件缩放来源。
- 快照属于 chunk 生命周期，不引入全局缓存或循环引用。显示快照与原始输入分离，重排仍复用现有 generator。

验证：普通 → 标记 → 原普通 chunk 的真实 View 流程通过；连续缩放四次尺寸不累积；从辅助功能大字号恢复默认字号通过；重新赋予 24 pt/红色的新文本不会被旧快照覆盖。

### 2. P2：同段多个标记重复扫描和修改整段（已修复）

原实现每遇到一个标记都会执行 paragraphRange 和段落属性遍历，长段中的相邻标记使相同内容反复被扫描。现在利用标记按 UTF-16 顺序枚举的性质，记录已处理段落末尾，每个涉及的段落只修改一次。每个标记自身的选择范围仍独立保存，不合并业务 ID。

### 3. 维护性：颜色和绘制参数分散（已修复）

新增内部 `GMarkEditorMarkStyle`，统一颜色、原生回退下划线、间距、线宽、点距与最低行间距。解析器与绘制器共享这份配置，后续视觉优化有单一修改位置。

同时把绘制器工厂限制为无限高度文本块的 text/width 输入，避免未来误用于有限行数截断、表格等不具备相同契约的入口。末行高度向上取整，覆盖完整笔画。

## 架构职责

| 层 | 职责 |
| --- | --- |
| HTML tokenizer / sanitizer | 标签和属性边界、文本解码、作用域、标记 ID 与最终 UTF-16 范围；保留原生下划线回退。 |
| GMarkEditorMarkStyle | 项目标签的展示参数，无业务操作。 |
| GMarkMarkedTextRenderer | 按 MPITextKit 实际选择区域与整行布局框绘制；处理换行、方向、最后一行尺寸；不改源文字和范围。 |
| Chunk / MultiView | 保存原始输入、按容器宽度与系统字号生成显示快照、刷新和复用。 |
| 业务方 | 选择输入、决定点击或答案隐藏行为。 |

MPITextKit 公共头文件前向声明了 selection rect 类型，但 umbrella 未导出其定义；Swift 通过隔离在绘制器文件中的既有 Objective-C selector 声明读取 UIKit 基类。没有私有 API、方法替换、依赖源码修改或另起一套文本布局。几何在构建时生成，绘制时只读；视图更新仍要求主线程。

这仍是针对 CustomClickableSpan 的项目扩展。后续增加第二类标签时可复用标记/样式/绘制的分层，再决定注册机制；当前没有新增通用插件协议或公开配置 API。

## 验证

- iPhone 17 / iOS 27 Simulator：20 项 HTML 单测、2 项 UI 测试通过。
- 本轮新增/扩展验证：1/8/16/80 pt 窄宽、72 pt 字号、NBSP 空白标记、RTL 混合文字、0/100 px 段距、重复输入、连续 Dynamic Type、替换文字属性、标记移除后的刷新。
- 既有验证继续覆盖中文/emoji UTF-16、实体、跨 br/分块、相邻/嵌套/未闭合标签、普通下划线、同身份颜色刷新、原文章展示。
- 人工检查新增样本及原文章首/中/末屏：用户确认的虚线样式和间距保持一致，原文章未见回归。
- `git diff --check` 通过；用户原有 11 个未提交样本的 SHA-256 全部一致。
- 结果包：`/private/tmp/gmarkdown-cloze-review-fixed.xcresult`；截图：`/private/tmp/gmarkdown-cloze-review-fixed-attachments`。临时路径可能过期。

## 剩余边界

- 本轮验证的是 MultiView 的完整 HTML 文本块路径。其他入口保留原生下划线回退，不承诺相同间距；没有扩展表格/截断渲染路径。
- 初次传入或重新赋值的样式/富文本应使用未经过 UIFontMetrics 缩放的字体；组件生成的显示快照按内部原始输入恢复。调用方不应并发修改正在显示的 chunk。
- 完整第二类业务原文及期望截图尚未取得，未做所有设备/系统版本回归；复杂双向隔离仍遵循前述有限支持范围。
- MPITextKit 升级时应回归公开选择区域接口和 used rect 不含行间距的约定。
- 原有 GMarkChunk 可变 Sendable 与 XCTest 最低部署版本警告仍存在；本轮未开启 Swift 6 严格并发迁移，也没有做独立性能基准或 Instruments 内存测试。

本轮提交状态以 Git 记录为准。下一项工作等待用户确认。
