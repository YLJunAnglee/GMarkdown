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
}
