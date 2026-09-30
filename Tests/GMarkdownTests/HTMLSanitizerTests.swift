import XCTest
import UIKit
@testable import GMarkdown

final class HTMLSanitizerTests: XCTestCase {
    private let style = MarkdownStyle.defaultStyle()

    func testAllowedTextStructureIsReadableWithoutAttributes() {
        let source = #"<div class="ignored"><strong>粗体</strong><br><em>斜体</em><ul><li>第一项</li><li>第二项</li></ul><blockquote>引用</blockquote></div>"#
        let result = GMarkHTMLSanitizer.attributedString(from: source, style: style)

        XCTAssertTrue(result.string.contains("粗体\n斜体"))
        XCTAssertTrue(result.string.contains("• 第一项\n• 第二项"))
        XCTAssertTrue(result.string.contains("引用"))
        XCTAssertFalse(result.string.contains("class="))
    }

    func testDangerousContainersLinksAndImagesCannotCarryExecutableOrNavigationData() {
        let source = #"安全<script>alert('不能执行')</script><iframe src="https://evil.example">不能显示</iframe><img src="https://evil.example/pixel" alt="图片替代文字"><a href="https://evil.example">仅保留链接文字</a>结束"#
        let result = GMarkHTMLSanitizer.attributedString(from: source, style: style)

        XCTAssertEqual(result.string, "安全图片替代文字仅保留链接文字结束")
        XCTAssertFalse(result.string.contains("alert"))
        XCTAssertFalse(result.string.contains("不能显示"))
        XCTAssertFalse(result.string.contains("evil.example"))
        XCTAssertNil(result.attribute(.link, at: 0, effectiveRange: nil))
    }

    func testInlineDangerousContainerSuppressesItsMarkdownTextUntilClosingTag() {
        var state = GMarkHTMLSanitizer.InlineState()
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("<script>", to: &state, style: style))
        XCTAssertTrue(state.isIgnoringContent)
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("</script>", to: &state, style: style))
        XCTAssertFalse(state.isIgnoringContent)
    }

    func testEmptyListItemsAndNestedContent() {
        let source = #"<ul><li></li><li><span>  </span><br></li><li><img alt=""></li><li><img alt="图片"></li><li><ul><li></li></ul></li><li>正文</li></ul>"#
        let result = GMarkHTMLSanitizer.attributedString(from: source, style: style)

        XCTAssertEqual(result.string, "• 图片\n• 正文\n")
    }

    func testEditorTextStylesAndBlockOnlySpacing() {
        let source = #"<p style="font-size:18px;margin-bottom:12px"><span style="font-weight:bold;color:#4F5CE7;margin-bottom:90px">标题</span><span style="font-style:italic">文字</span></p>"#
        let result = GMarkHTMLSanitizer.attributedString(from: source, style: style)

        XCTAssertEqual(result.string, "标题文字\n")
        let firstFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(firstFont?.pointSize, 18)
        XCTAssertTrue(firstFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        let secondFont = result.attribute(.font, at: 2, effectiveRange: nil) as? UIFont
        XCTAssertTrue(secondFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
        let paragraph = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(paragraph?.paragraphSpacing, 12)
        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor(red: 79 / 255, green: 92 / 255, blue: 231 / 255, alpha: 1))
    }

    func testUnstyledNestedTagDoesNotCloseOuterInlineStyle() {
        var state = GMarkHTMLSanitizer.InlineState()
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken(#"<span style="color:#4F5CE7">"#, to: &state, style: style))
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("<span>", to: &state, style: style))
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("</span>", to: &state, style: style))
        let inside = GMarkHTMLSanitizer.attributedText(from: "保留颜色", style: style, state: state)
        XCTAssertEqual(inside.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
                       UIColor(red: 79 / 255, green: 92 / 255, blue: 231 / 255, alpha: 1))
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("</span>", to: &state, style: style))
        XCTAssertFalse(state.isInHTMLContext)
    }
}
