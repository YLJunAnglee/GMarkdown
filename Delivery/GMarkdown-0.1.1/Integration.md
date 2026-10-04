# GMarkdown 0.1.1 接入说明

## 固定契约

- iOS 15.0 起，Swift 5；源码文件夹集成，不承诺 SPM/CocoaPods。
- 首发路径为 `GMarkdownMultiView` 分块渲染；TextView 仅诊断。
- iPhone 仅竖屏；iPad 支持横竖屏和约定分屏；不扩大到 iPhone 横屏。
- Mermaid 只展示/复制源码；HTML 为受限、非执行式展示；不使用 WebView 预览。
- 链接交给宿主处理；图片必须经过宿主 `ImageLoader`。

## 展示入口与业务边界

业务按自身字段规则选择输入：`richTxt` 有内容时可走受控编辑器 HTML 入口，为空时可走原有 Markdown `txt` 入口。组件只接收字符串，不读取业务字段，也不在渲染失败时自动切换输入。完整 HTML 不应送入 Markdown 预处理路径。

```swift
let htmlChunks = GMarkHTMLProcessor(style: style).process(html: richTxt)
markdownView.updateMarkdown(htmlChunks) // GMarkdownMultiView；在主线程更新
```

Markdown 继续使用 `GMarkProcessor`、`GMarkChunkGenerator` 和 `GMarkdownMultiView`。`CustomClickableSpan` 在 HTML 文本块中保留文字与 UTF-16 属性范围，并绘制 `#4F5CE7` 点状虚线；宿主可从 chunk 的 `attributedText` 以 `NSAttributedString.Key("GMark.CustomClickableSpan")` 读取标记值和范围。点击、隐藏及恢复尚未实现。支持的标签、CSS、分块和降级边界见 [RichTxtHTMLSupportScope.md](./RichTxtHTMLSupportScope.md)。

Markdown 路径可在 `GMarkChunkGenerator` 配置 `onRenderIssue` 接收可识别的渲染失败或降级。事件包含文档标识、顶层源块序号、原因和实际展示的降级类型；回调可能来自后台线程或异步图片加载，宿主更新 UI 前须切回主线程，并忽略旧内容版本的回调。旧版 `ImageLoader` 仍可用；若需报告图片异步失败，宿主 loader 应实现 `GMarkReportingImageLoader`。该通知不等于所有 HTML、图片或视觉问题均可被自动发现。

## 升级与回退

业务工程不得在交付目录内散改组件源码。升级时整体替换 `GMarkdown-<semver>/`，保留旧目录直到新版本完成构建与冒烟；回退时整体切回上一版本目录。任何影响解析、布局、异步、资源或公开 API 的修改都必须使受影响门槛重新验证。

## 构建前检查

源码文件夹接入遇到模块、C 头文件、资源 bundle 或 Xcode 缓存错误时，先参阅[源码接入排错手册](SourceIntegrationTroubleshooting.md)，再按本文的依赖结构继续配置。

1. 建立独立的 `GMarkdown` framework target，将 `Sources/` 和 `Sources/Assets/` 加入其中；代码高亮资源须能从组件 bundle 根目录按 `highlight.min.js`、`github-gist.min.css`、`dark.min.css` 等文件名查到。不要把组件源码直接混入业务 App target。
2. 将 `Dependencies/` 中的 `Markdown`（含 `swift-cmark` C target）、`MPITextKit`、`SwiftMath`、`MathJaxSwift` 分别建立为可导入模块，并让 `GMarkdown` target 显式依赖它们。
3. 检查 `Licenses/` 是否包含 swift-markdown、swift-cmark、MPITextKit、SwiftMath、MathJaxSwift 和 highlight.js 许可证。
4. 编译 Debug 和 Release；确认最低 iOS 15，且没有把 Mermaid/HTML WebView 资源带入首发包。
5. `Examples/MinimalHost/` 是后续最小宿主接入样板。该目录的 `Package.swift` 只使用交付目录本地依赖，可单独编译，不改变源码文件夹接入契约。
6. 真机 Release 完成性能/内存基线后，才填写候选版本的验收记录。

交付包当前构建记录见 [SourceManifest.md](./SourceManifest.md)。独立 SwiftPM 编译不替代干净原生 Xcode framework target 接入、业务页面验证、真机 Release 性能/内存或 iOS 15 实机运行。
