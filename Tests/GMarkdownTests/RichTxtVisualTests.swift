import XCTest

final class RichTxtVisualTests: XCTestCase {
    func testEditorArticleRendersAcrossScrollPositions() {
        let app = XCUIApplication(bundleIdentifier: "com.giki.markdown")
        app.launch()

        let entry = app.staticTexts["Markdown Renderer"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.staticTexts["markdownBookRichTxt"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.5) // The sample is parsed on a background queue.

        for position in 0..<3 {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "richTxt position \(position)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if position < 2 {
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                start.press(forDuration: 0.1, thenDragTo: end)
            }
        }
    }
}
