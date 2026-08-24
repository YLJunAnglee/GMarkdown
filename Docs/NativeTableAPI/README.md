# NativeMarkdownTableView 公共 API

## 使用方式

```swift
import GMarkdown

let tableView = NativeMarkdownTableView()
let result = tableView.render(
    markdown: tableMarkdown,
    style: .defaultStyle(),
    containerWidth: availableWidth
)

switch result {
case let .success(metrics):
    tableHeight = metrics.requiredSize.height
case .failure:
    showFallbackRenderer()
}
```

业务调用方只接触 Markdown 原文、`MarkdownStyle`、容器宽度、公开结果和 `UIView`，不需要使用 `GMarkChunk`、`GMarkupTableVisitor`、`GMarkTableLayout` 或内部 Cell。

## 输入与结果约定

- 一次只接收一个顶层 Markdown TABLE，符合 AIEndorser 一个 TABLE Block 对应一个渲染视图的边界。
- 成功结果只返回列数、正文行数和所需 View 尺寸，不泄漏内部解析或布局模型。
- 空输入、无效宽度、没有表格、多张表格，以及同时包含其他顶层 Markdown 内容都会返回明确失败。
- 失败会立即清空旧表格，避免 Cell 复用时残留上一次内容。
- 同一 View 可以使用新的容器宽度重新调用 `render`，并获得新的所需尺寸。
- 原始 Markdown 只读，不会被组件修改或写回。

## 验证结果

- 日期：2026-08-24。
- 设备：iPhone 16 Pro 模拟器，iOS 18.6。
- 第 6 步完成后共 18 个测试全部通过：7 个 TABLE 解析回归测试、6 个公共 API 测试和 5 个布局/样式测试。
- API 测试通过普通五列表格、短表格、宽度重渲染、清空，以及全部公开失败分支。
- Example 使用正常的 `import GMarkdown` 接入新 View，能够显示样例 A、B，并从边界样例 C 中独立显示长公式表。
- 样例 C 返回 3 列、2 行、370×165pt；长公式和备注保持在原行，公式没有显示源码。
- [样例 C 公共 API 页面](native_table_api_c.png)

## 本步骤不处理的范围

- 列宽、完整行高、横向滚动、颜色和列对齐已在第 6 步完成，证据见 `Docs/TableLayout/README.md`。
- 当前 `render` 是同步入口；缓存、异步任务、取消 Token 和复用防回写留到第 7 步。
- 当前只形成 GMarkdown 公共能力，不修改 AIEndorser，也不更新其 SPM revision。
