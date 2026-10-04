# 源码与资源交付清单

这是 0.1.1 候选版本的交付清单。2026-10-04 已将仓库提交 `f5a71c8c29918fb83becfc961993cc69c4e58f7a` 的 `Sources/` 全量同步到本目录，包含展示实现提交 `5be60d3a14def6f83181ee8542b7d62c9214ddd0`。组件源码、锁定 revision 的依赖源码、资源和许可证均在本目录；`Checksums.sha256` 记录本轮候选内容完整性。候选尚未冻结或发布。

## 组件源码

- `Sources/Generator/`
- `Sources/Helper/`
- `Sources/MarkdownTextView/`（诊断路径，仍随源码交付但不进入首发承诺）
- `Sources/Parser/`
- `Sources/Render/`
- `Sources/Visitor/`
- 新增公开入口 `Sources/Parser/GMarkHTMLProcessor.swift`、Markdown 失败/降级事件 `Sources/Render/GMarkRenderIssue.swift`；HTML 标记解析与 MultiView 虚线绘制所需文件均在上述目录内。
- `Package.swift`（仅用于验证交付源码和本地依赖能独立构建；不改变源码文件夹接入契约）

## 组件资源

- `Sources/Assets/Highlighter/highlight.min.js`
- `Sources/Assets/styles/` 的 90 个代码主题资源，包含默认浅色 `github-gist` 与深色 `dark`；交付包验证清单以 `.process` 将 CSS 放到资源 bundle 根目录，匹配高亮器的查找路径

Mermaid 执行资源、HTML/WebView 预览资源不应出现在首发交付目录。

## 依赖与许可证

- swift-markdown 0.4.0（revision `4aae40bf6fff5286e0e1672329d17824ce16e081`）
- swift-cmark 0.4.0（revision `3bc2f3e25df0cecc5dc269f7ccae65d0f386f06a`，swift-markdown 传递依赖）
- MPITextKit 0.2.4（revision `6b2e616f2648bcb7e3bc1c739bac3fb4a2626eec`）
- SwiftMath 2.0.0（revision `1e49ab4e85eeb0986d0a63d1ca68f8a4b0b964d5`）
- MathJaxSwift 3.4.0（revision `e23d6eab941da699ac4a60fb0e60f3ba5c937459`）
- `highlight.js` 9.13.1 资源（`Sources/Assets/Highlighter/highlight.min.js`）与 BSD 3-Clause 许可证
- `Licenses/` 中逐项保存许可证和来源 URL

本候选目录已包含 `Sources/`、`Dependencies/`、`Licenses/` 和组件资源。依赖清单的 revision 与仓库 `Package.resolved` 一致；本轮核对了目录、许可证、哈希和构建，未重新向第三方仓库溯源每份依赖源码。源码文件夹接入不要求这些依赖仓库的 Package manifest，但本目录的验证清单会使用它们检查依赖图。真机性能/内存基线不在本候选的声明范围内。

## 本轮候选记录

```text
候选仓库提交：f5a71c8c29918fb83becfc961993cc69c4e58f7a（展示实现 5be60d3a14def6f83181ee8542b7d62c9214ddd0）
版本：GMarkdown-0.1.1
组件源码与资源：162 个文件，和仓库 Sources/ 逐文件一致
依赖与许可证：5 个依赖源码目录；8 份许可证文件
文件总数：以 Checksums.sha256 条目为准（不含清单自身）
哈希清单生成时间：2026-10-04（候选完整性记录，非冻结版本）
交付包构建：iOS 15 Simulator Debug/Release 均通过（Xcode 27.0；资源清单修正后重建）
最小宿主构建：Examples/MinimalHost iOS 15 Simulator Debug/Release 均通过（使用修正后的交付包）
资源核对：Debug/Release 产物均包含 90 个根目录 CSS 主题及 highlight.min.js
构建警告：第三方依赖的弃用/Sendable 警告与组件现有 Sendable/弃用等警告；无构建错误
真机基线报告：待补
```
