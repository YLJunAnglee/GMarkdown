# `wordIndexBeans` 候选接入规格（待业务确认）

状态：已完成真实数据索引契约核验，尚未改动组件或 Demo 渲染代码。`wordIndexBeans` 只是原文位置元数据，当前数据没有定义其究竟代表关键词、高亮、挖空或其它业务语义；因此本文只保留候选契约，**暂不接入、不展示、不创建自定义块**。

## 已验证的导出契约

扫描「项目书籍测试」的全部 9 本脱敏书籍后得到：

| 项目 | 结果 |
| --- | ---: |
| `wordIndexBeans` 条目数 | 28,063 |
| 实际范围数 | 42,587 |
| 空范围、越界范围、关键词不匹配 | 0 / 0 / 0 |
| 无位置范围的条目 | 1,274 |
| 至少有一对范围相交的内容块 | 797 |
| 词范围与 `$…$` / `$$…$$` 公式词法区间相交 | 10,581 |
| 词范围与围栏代码词法区间相交 | 63 |

核验以 `NSString` 读取原始 `dataBaseBean.txt`：每个范围都满足
`substring(with: NSRange(location: startIndex, length: endIndex - startIndex)) == word`。
因此第一期把索引定义为 **原始 UTF-16 文本的半开区间 `[startIndex, endIndex)`**。不能将它当成 Swift 字符数、`Character` 偏移或解析后 `NSAttributedString` 的位置。

公式/代码统计是保守的词法扫描，用于确定实现风险，不取代 Markdown AST 分类。它已经足以排除“解析完成后直接套用原始范围”的实现方案。

## 若业务确认“关键词高亮”后的第一期开关与行为

以下方案仅在业务明确 `wordIndexBeans` 用于“关键词高亮并将点击交给宿主”后适用；不改变 Markdown 内容、公式、图片、表格或代码。

1. 功能开关默认关闭；关闭时现有 GMarkdown 行为和性能不变。
2. 宿主将每个原始书籍块作为一个独立请求传入；不得跨块合并后继续使用旧索引。
3. 仅对成功映射到普通可展示文本的标注应用高亮和点击。
4. 命中公式附件、代码、图片替代文本、表格结构或无法一一映射的 Markdown 语法时，第一期不强行高亮；可选地报告为“未展示标注”。
5. 无范围条目、越界范围或映射失败都只记录诊断，不影响该块 Markdown 的正常展示。
6. 重叠范围使用“最长优先、同长度按导出顺序优先”；只画一层高亮。宿主仍收到所有原始标注，便于后续改为菜单或多标签交互。

## 业务确认后的建议数据模型与接口

以下类型放在业务工程/适配层；名称仅为草案：

```swift
import Foundation

struct ProjectTextRange: Hashable, Sendable {
    let startUTF16: Int
    let endUTF16: Int       // exclusive
}

struct ProjectKeywordTag: Hashable, Sendable {
    let word: String
    let ranges: [ProjectTextRange]
}

struct ProjectMarkdownBlock: Sendable {
    let bookID: String
    let chapterID: String
    let blockID: String
    let markdown: String
    let keywordTags: [ProjectKeywordTag]
}

struct ProjectKeywordActivation: Sendable {
    let bookID: String
    let chapterID: String
    let blockID: String
    let word: String
    let sourceRangeUTF16: ProjectTextRange
}
```

组件侧需要一个**源范围映射**扩展，而非让宿主修改 `GMarkChunk` 的 Cell 生命周期：

```swift
protocol GMarkdownSourceAnnotationResolver: Sendable {
    func annotations(for source: String) -> [GMarkdownSourceAnnotation]
}

struct GMarkdownSourceAnnotation: Hashable, Sendable {
    let id: String
    let sourceRangeUTF16: NSRange
}

enum GMarkdownAnnotationMappingFailure: Sendable {
    case invalidSourceRange
    case unsupportedRenderedContent
    case sourceLocationUnavailable
}

protocol GMarkdownSourceAnnotationDelegate: AnyObject {
    func markdownView(_ view: GMarkdownMultiView,
                      didActivate annotationID: String,
                      renderedSourceRangeUTF16: NSRange)
    func markdownView(_ view: GMarkdownMultiView,
                      didFailToMap annotationID: String,
                      reason: GMarkdownAnnotationMappingFailure)
}
```

实际公开 API 的命名可按仓库约定调整，但必须保持三个边界：源范围属于原始块、组件负责 AST 到可展示文本的映射、宿主负责 `annotationID` 对应的业务行为。

## 业务确认后的实现顺序

1. 在 Demo 导入模型保留 `bookID`、`chapterID`、`blockID` 和 `wordIndexBeans`，但暂不改变默认展示。
2. 为组件增加只读源范围映射与失败原因；为正文普通文本建立最小映射测试。
3. 接入高亮外观和点击回调，只开启一个真实章节作回归样本。
4. 分别补充公式、代码、表格、HTML 图片及重叠范围测试，确认它们按上述“安全跳过/诊断”规则处理。
5. 最后由业务决定：未展示标注是否需要列表、搜索或其它独立入口；这不应反向改变 Markdown 原文。

## 非目标

- 不把关键词包装为 Markdown 或 HTML 再重新解析。
- 不猜测 OCR 损坏文字、不根据关键词内容重写公式。
- 不由宿主接管 `GMarkdownMultiView` 内部 Cell。
- 不在本阶段接入现有业务源码、创建 framework target 或进行真机验证。
