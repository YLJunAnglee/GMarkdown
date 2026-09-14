import XCTest
@testable import GMarkdown

final class SVGTextOutlinerTests: XCTestCase {
    func testCJKClassificationDoesNotRouteOrdinaryMathAway() {
        XCTAssertTrue(GMarkSVGTextOutliner.containsCJK(#"A \text{包含的基本事件数}"#))
        XCTAssertFalse(GMarkSVGTextOutliner.containsCJK(#"x^2 \tag{4.1}"#))
        XCTAssertFalse(GMarkSVGTextOutliner.containsCJK(#"\alpha+\beta"#))
    }

    func testChineseNodesBecomeNonemptyPathsAndKeepTheirPositions() throws {
        let original = #"<svg><text transform="translate(250,0) scale(1,-1)" font-size="884px" font-family="serif">包</text><text transform="translate(1250,0) scale(1,-1)" font-size="884px" font-family="serif">含</text></svg>"#
        let output = try GMarkSVGTextOutliner.outline(original)
        XCTAssertEqual(output.components(separatedBy: "<path d=").count - 1, 2)
        XCTAssertFalse(output.contains("<text"))
        XCTAssertTrue(output.contains(#"transform="translate(250,0) scale(1,-1)""#))
        XCTAssertTrue(output.contains(#"transform="translate(1250,0) scale(1,-1)""#))
        XCTAssertNotEqual(try GMarkSVGTextOutliner.pathData(text: "包", fontSize: 884),
                          try GMarkSVGTextOutliner.pathData(text: "含", fontSize: 884))
    }

    func testEnglishAndNumberingAreUnchanged() throws {
        let source = #"<svg><text font-size="884px">event (4.1)</text><path d="M0 0L1 1"/></svg>"#
        XCTAssertEqual(try GMarkSVGTextOutliner.outline(source), source)
    }

    func testUnsupportedPositioningDoesNotSilentlyDropChinese() {
        let source = #"<svg><text x="10" font-size="884px">包</text></svg>"#
        XCTAssertThrowsError(try GMarkSVGTextOutliner.outline(source))
    }
}
