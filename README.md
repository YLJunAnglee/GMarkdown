# GMarkdown

GMarkdown is a native iOS Markdown renderer built on swift-markdown, MPITextKit, SwiftMath and Highlightr.

## Current integration contract

- Minimum deployment target: iOS 14.0.
- Primary supported renderer: `GMarkdownMultiView` block rendering.
- iPhone portrait and iPad portrait/landscape/split view are supported; iPhone landscape is not a first-release target.
- Mermaid is displayed as code only; it is not executed or previewed.
- HTML is display-only and sanitized. Scripts, WebView previews, arbitrary URLs and external HTML resources are not executed or loaded.
- TextView rendering remains an experimental/diagnostic path and is not covered by the first-release acceptance contract.

## Source-folder integration

The first-release delivery is a source folder. Create separate framework/module targets for GMarkdown and its required dependencies (`Markdown`/`swift-cmark`, `MPITextKit`, `SwiftMath`, and `MathJaxSwift`), then make the host application depend on GMarkdown. Add the delivered resources to the GMarkdown target. CocoaPods and Swift Package Manager are not part of this integration contract.

The delivery must retain the dependency licenses and resource files listed by the release manifest. Do not copy only the GMarkdown Swift files while omitting MPITextKit, SwiftMath, Highlightr, swift-markdown or their resources.

## Basic usage

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

Prepare and parse content away from the main thread when the host's parser/dependencies permit it, then call `updateMarkdown(_:)` on the main thread. The component owns rendering and layout; loading, pagination, streaming and business refresh policy remain the host's responsibility.

Call `clearContent()` on page exit or before releasing a large document when the host wants to drop the current chunk snapshot early.

## Supported content and degradation

Headings, paragraphs, emphasis, lists, blockquotes, code blocks with Copy, tables, Markdown images, LaTeX formulas, links and restricted HTML are supported by the block path. Failed images use the configured fallback behavior. HTML code fences are shown and copied as source text, never previewed.

Malformed formulas or unsupported TeX extensions may degrade to readable text. The renderer does not rewrite arbitrary unmatched `$` or unknown macros.

## Dependencies

- [swift-markdown](https://github.com/apple/swift-markdown)
- [SwiftMath](https://github.com/mgriebling/SwiftMath)
- [MPITextKit](https://github.com/meitu/MPITextKit)
- [Highlightr](https://github.com/raspu/Highlightr)

## License

GMarkdown is released under the MIT license. See [LICENSE](./LICENSE).
