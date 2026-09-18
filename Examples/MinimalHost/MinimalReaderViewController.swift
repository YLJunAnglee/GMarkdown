import UIKit
import GMarkdown

/// Minimal host sample for the first-release block renderer.
/// The host owns loading, navigation, and content refresh policy.
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
