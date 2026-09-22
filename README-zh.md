# GMarkdown

GMarkdown 是基于 swift-markdown、MPITextKit、SwiftMath 和 Highlightr 的原生 iOS Markdown 渲染组件。

## 当前接入约定

- 最低系统版本：iOS 15.0。
- 首发主路径：`GMarkdownMultiView` 分块渲染。
- 支持 iPhone 竖屏，以及 iPad 竖屏、横屏和分屏；iPhone 横屏不属于首发范围。
- Mermaid 只展示代码，不执行、不预览。
- HTML 仅做受限的安全展示；脚本、WebView 预览、任意 URL 和外部 HTML 资源均不执行或加载。
- TextView 渲染暂作为实验/诊断路径，不纳入首发验收。

## 源码文件夹接入

首发交付形式为源码文件夹。将交付目录中的 `Sources`、依赖源码和所需资源整体加入 Xcode target。当前接入约定不使用 CocoaPods 或 Swift Package Manager。

交付时必须保留发布清单列出的依赖许可证和资源文件。不能只复制 GMarkdown 的 Swift 文件而遗漏 MPITextKit、SwiftMath、Highlightr、swift-markdown 或其资源。

## 基本用法

```swift
import GMarkdown

final class ReaderViewController: UIViewController {
    private let markdownView = GMarkdownMultiView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(markdownView)
        markdownView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            markdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            markdownView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func render(_ markdown: String) {
        let generator = GMarkChunkGenerator()
        generator.style = MarkdownStyle.defaultStyle()
        generator.addImageHandler()
        generator.addLaTexHandler()

        let processor = GMarkProcessor(
            parser: GMarkParser(),
            chunkGenerator: generator
        )
        let chunks = processor.process(markdown: markdown)

        DispatchQueue.main.async { [weak self] in
            self?.markdownView.updateMarkdown(chunks)
        }
    }
}
```

内容较长时，宿主可在依赖允许的前提下将读取和解析放到后台线程，再在主线程调用 `updateMarkdown(_:)`。组件负责渲染和布局；数据加载、分页、流式追加和业务刷新策略由宿主负责。

页面退出或需要尽早释放大章节时，宿主可调用 `clearContent()` 主动清空当前分块快照。

## 支持内容与降级

分块路径支持标题、正文、强调、列表、引用、带 Copy 的代码块、表格、Markdown 图片、LaTeX 公式、链接和受限 HTML。图片加载失败时使用配置的替代显示。HTML 代码块只展示和复制源码，不进行预览。

损坏公式或不支持的 TeX 扩展可能降级为可读文本；渲染器不会为任意未配对的 `$` 或未知宏自动补写定界符。

## 依赖

- [swift-markdown](https://github.com/apple/swift-markdown)
- [SwiftMath](https://github.com/mgriebling/SwiftMath)
- [MPITextKit](https://github.com/meitu/MPITextKit)
- [Highlightr](https://github.com/raspu/Highlightr)

## 许可证

GMarkdown 使用 MIT 许可证，详见 [LICENSE](./LICENSE)。
