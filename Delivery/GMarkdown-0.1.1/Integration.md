# GMarkdown 0.1.1 接入说明

## 固定契约

- iOS 15.0 起，Swift 5；源码文件夹集成，不承诺 SPM/CocoaPods。
- 首发路径为 `GMarkdownMultiView` 分块渲染；TextView 仅诊断。
- iPhone 仅竖屏；iPad 支持横竖屏和约定分屏；不扩大到 iPhone 横屏。
- Mermaid 只展示/复制源码；HTML 为受限、非执行式展示；不使用 WebView 预览。
- 链接交给宿主处理；图片必须经过宿主 `ImageLoader`。

## 升级与回退

业务工程不得在交付目录内散改组件源码。升级时整体替换 `GMarkdown-<semver>/`，保留旧目录直到新版本完成构建与冒烟；回退时整体切回上一版本目录。任何影响解析、布局、异步、资源或公开 API 的修改都必须使受影响门槛重新验证。

## 构建前检查

源码文件夹接入遇到模块、C 头文件、资源 bundle 或 Xcode 缓存错误时，先参阅[源码接入排错手册](SourceIntegrationTroubleshooting.md)，再按本文的依赖结构继续配置。

1. 建立独立的 `GMarkdown` framework target，将 `Sources/` 和 `Sources/Assets/` 加入其中；不要把组件源码直接混入业务 App target。
2. 将 `Dependencies/` 中的 `Markdown`（含 `swift-cmark` C target）、`MPITextKit`、`SwiftMath`、`MathJaxSwift` 分别建立为可导入模块，并让 `GMarkdown` target 显式依赖它们。
3. 检查 `Licenses/` 是否包含 swift-markdown、swift-cmark、MPITextKit、SwiftMath、MathJaxSwift 和 highlight.js 许可证。
4. 编译 Debug 和 Release；确认最低 iOS 15，且没有把 Mermaid/HTML WebView 资源带入首发包。
5. 使用 `Examples/MinimalHost/` 的最小控制器完成干净构建/启动，再运行固定回归集。
6. 真机 Release 完成性能/内存基线后，才填写候选版本的验收记录。

当前状态：全新最小宿主已由用户确认通过本地 Package 在模拟器中构建、启动、换行、深色模式和 Dynamic Type 验证；源码文件夹复制、许可证汇总、资源包大小、Release 构建和真机基线仍待阶段 E/D 完成。
