# GMarkdown 最小宿主样板

这是源码文件夹分发的最小接入样板，不是已构建的发布工程。它只接入首发主路径 `GMarkdownMultiView`；TextView、Mermaid 预览和 iPhone 横屏不在样板承诺内。

## 从干净 Xcode 工程接入

1. 新建 iOS App，Deployment Target 设为 iOS 14.0，Swift 5。
2. 将交付目录中的 `Sources`、依赖源码和资源按 `Delivery/GMarkdown-0.1.1/SourceManifest.md` 加入同一 target；不要从业务工程散改组件源码。
3. 把下方控制器加入 target，并确认 `GMarkdown` 模块可见。
4. 宿主实现 `ImageLoader`，只允许经过业务白名单的 `https` 图片；未配置 loader 时图片应保持降级行为。
5. 业务页面退出或切换大章节时调用 `clearContent()`。

## 最小控制器

可直接复制的样板文件是 [`MinimalReaderViewController.swift`](MinimalReaderViewController.swift)。

```swift
import UIKit
import GMarkdown

final class MinimalReaderViewController: UIViewController {
    private let markdownView = GMarkdownMultiView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(markdownView)
        markdownView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            markdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            markdownView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func render(markdown: String) {
        var style = MarkdownStyle.defaultStyle()
        style.maxContainerWidth = markdownView.bounds.width

        let generator = GMarkChunkGenerator()
        generator.style = style
        generator.addImageHandler()
        generator.addLaTexHandler()

        let processor = GMarkProcessor(
            parser: GMarkParser(),
            chunkGenerator: generator
        )
        let chunks = processor.process(markdown: markdown)

        precondition(Thread.isMainThread)
        markdownView.updateMarkdown(chunks)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        markdownView.clearContent()
    }
}
```

## 宿主验收清单

- [ ] iOS 14 最低版本、Release/Debug 配置和 Swift 5 已确认。
- [ ] 首发只使用分块路径；TextView 仅作为诊断工具。
- [ ] Markdown、用户输入和第三方 HTML 按不可信输入处理。
- [ ] HTML 非执行式展示、Mermaid 代码展示/复制、无 WebView 预览。
- [ ] 链接通过宿主校验后处理；组件不直接导航。
- [ ] 图片 loader 校验 scheme/domain、重定向、MIME、大小、超时和失败占位。
- [ ] 内容替换和退出后无旧 chunk；大章节退出调用 `clearContent()`。
- [ ] 完成 [ReleaseBaseline.md](../../Docs/Performance/ReleaseBaseline.md) 的真机测量后，才可判断 L1/L2。

当前状态：**用户已确认模拟器构建/启动正常**；真机、Release 性能/内存和正式交付目录验证仍待补。
