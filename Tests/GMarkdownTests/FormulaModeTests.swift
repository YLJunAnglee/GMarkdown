import XCTest
import Markdown
import UIKit
@testable import GMarkdown

final class FormulaModeTests: XCTestCase {
    func testDelimitersSelectModeBeforeTheyAreRemoved() {
        for source in ["$x^2$", #"\(x^2\)"#] {
            XCTAssertEqual(GMarkFormulaMode.detect(source), .inline)
            XCTAssertEqual(GMarkLaTexRender.trimBrackets(from: source), "x^2")
        }
        for source in ["$$x^2$$", #"\[x^2\]"#] {
            XCTAssertEqual(GMarkFormulaMode.detect(source), .block)
            XCTAssertEqual(GMarkLaTexRender.trimBrackets(from: source), "x^2")
        }
    }

    func testInlineParagraphDoesNotBecomeLatexChunk() {
        for source in ["$x^2$", "前 $x^2$ 后"] {
            let nodes = GMarkParser().parseMarkdownToMarkups(markdown: source)
            XCTAssertEqual(nodes.count, 1)
            XCTAssertFalse(LaTexMarkupHandler().canHandle(nodes[0]))
        }
    }

    func testDisplaySplitsTextAndAdjacentBlocksWithoutLosingPayload() {
        let source = #"前$$P(\{e_i\})$$$$y^2$$后"#
        let nodes = GMarkParser().parseMarkdownToMarkups(markdown: source)
        XCTAssertEqual(nodes.count, 4)
        XCTAssertEqual(nodes.map { LaTexMarkupHandler().canHandle($0) }, [false, true, true, false])
        var stringifier = GMarkupStringifier()
        XCTAssertEqual(stringifier.visit(nodes[1]).trimmingCharacters(in: .whitespacesAndNewlines), #"$$P(\{e_i\})$$"#)
    }

    func testListAndQuoteKeepTheirContainers() {
        let document = GMarkParser().parseMarkdown(from: "- 前 $$x^2$$ 后\n\n> 前 $$y^2$$ 后")
        XCTAssertTrue(document.child(at: 0) is UnorderedList)
        XCTAssertEqual(document.child(at: 0)?.child(at: 0)?.childCount, 3)
        XCTAssertTrue(document.child(at: 1) is BlockQuote)
        XCTAssertEqual(document.child(at: 1)?.childCount, 3)
    }

    func testTableDisplayStaysInCellWithLocalBreaks() {
        let document = GMarkParser().parseMarkdown(from: "| 类型 | 内容 |\n| --- | --- |\n| 块 | 前 $$x^2$$ 后 |")
        guard let table = document.child(at: 0) as? Table,
              let row = table.body.child(at: 0), let cell = row.child(at: 1) else {
            return XCTFail("Table structure must survive formula normalization")
        }
        XCTAssertEqual(row.childCount, 2)
        XCTAssertEqual(cell.children.filter { $0 is LineBreak }.count, 2)
        XCTAssertFalse(cell.children.contains { $0 is Paragraph })
    }

    func testCodeAndOrdinaryTextAreUnaffected() {
        let document = GMarkParser().parseMarkdown(from: "`$$x^2$$`\n\n```latex\n$$y^2$$\n```\n\n普通正文")
        XCTAssertEqual(document.childCount, 3)
        XCTAssertTrue(document.child(at: 0)?.child(at: 0) is InlineCode)
        XCTAssertTrue(document.child(at: 1) is CodeBlock)
    }

    func testAttachmentViewportAndInlineScalingHaveDifferentPolicies() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 60)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 60))
        }
        var style = MarkdownStyle.defaultStyle()
        style.maxContainerWidth = 300
        let container = NSTextContainer(size: CGSize(width: 300, height: 1000))
        container.lineFragmentPadding = 0
        let behavior = MarkdownAttachingBehavior()
        for mode in [GMarkFormulaMode.inline, .block] {
            let provider = MDLaTexAttachedProvider(laTexImage: image, style: style, mode: mode)
            let attachment = MarkdownAttachment(viewProvider: provider)
            let bounds = provider.bounds(for: attachment, textContainer: container,
                                         proposedLineFragment: CGRect(x: 0, y: 0, width: 300, height: 100), glyphPosition: .zero)
            XCTAssertEqual(bounds.width, 300)
            let view = provider.instantiateView(for: attachment, in: behavior)
            view.frame = bounds
            view.layoutIfNeeded()
            if mode == .block {
                XCTAssertGreaterThanOrEqual(bounds.height, 60)
                guard let scroll = view as? UIScrollView else { return XCTFail("Display equation needs a scroll viewport") }
                XCTAssertEqual(scroll.contentSize.width, 600)
                XCTAssertTrue(scroll.isScrollEnabled)
            } else {
                XCTAssertEqual(bounds.height, 30)
                XCTAssertTrue(view is UIImageView)
            }
        }
    }

    func testBackendModeDoesNotReuseOtherModeCache() {
        GMarkCachedManager.shared.clearAllCache()
        defer { GMarkCachedManager.shared.clearAllCache() }
        let inline = GMarkLaTexRender.renderLatexImage(#"$\sum_{i=1}^{n}i$"#)
        let block = GMarkLaTexRender.renderLatexImage(#"$$\sum_{i=1}^{n}i$$"#)
        XCTAssertTrue(inline.success)
        XCTAssertTrue(block.success)
        XCTAssertNotEqual(inline.size, block.size)
        let again = GMarkLaTexRender.renderLatexImage(#"$\sum_{i=1}^{n}i$"#)
        XCTAssertEqual(again.size, inline.size)
    }
}
