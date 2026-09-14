import XCTest
@testable import GMarkdown

final class SVGViewportTests: XCTestCase {
    func testNumberedRootAndChildrenHaveExplicitViewports() {
        let original = #"<svg style="vertical-align: -0.717ex; min-width: 15.205ex;" width="100%" height="2.565ex"><g><svg data-table="true" viewBox="504.3 -817 1 1133.9"></svg><svg data-labels="true" preserveAspectRatio="xMaxYMid" viewBox="2056 -817 1 1133.9"><text>(4.1)</text></svg></g></svg>"#
        let expected = original.replacingOccurrences(of: #" width="100%""#, with: #" width="15.205ex""#)
            .replacingOccurrences(of: #"viewBox="504.3 -817 1 1133.9">"#,
                                  with: #"viewBox="504.3 -817 1 1133.9" width="15.205" height="2.565">"#)
            .replacingOccurrences(of: #"viewBox="2056 -817 1 1133.9">"#,
                                  with: #"viewBox="2056 -817 1 1133.9" width="15.205" height="2.565">"#)
        XCTAssertEqual(GMarkSVGViewport.standalone(original), expected)
        XCTAssertEqual(GMarkSVGViewport.standalone(expected), expected)
    }

    func testFixedWidthAndNestedPercentageWidthsStayUntouched() {
        let original = #"<svg width="12ex" style="min-width: 15ex;"><svg width="100%"></svg></svg>"#
        XCTAssertEqual(GMarkSVGViewport.standalone(original), original)
    }

    func testMissingOrUnusableMinimumIsNotGuessed() {
        for style in ["", "min-width: 0ex;", "min-width: -3ex;", "min-width: 100%;", "min-width: auto;"] {
            let original = "<svg width=\"100%\" style=\"\(style)\"></svg>"
            XCTAssertEqual(GMarkSVGViewport.standalone(original), original)
        }
    }
}
