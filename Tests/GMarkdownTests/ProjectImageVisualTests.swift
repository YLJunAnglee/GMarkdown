import XCTest

final class ProjectImageVisualTests: XCTestCase {
    private func openProjectChapter(position: Int, named title: String, in app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.staticTexts["项目书籍测试"].waitForExistence(timeout: 10))
        app.staticTexts["项目书籍测试"].tap()

        let book = app.tables.cells.element(boundBy: 0)
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        book.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(String(position))
        let chapter = app.staticTexts[title]
        XCTAssertTrue(chapter.waitForExistence(timeout: 10))
        chapter.tap()
        XCTAssertTrue(app.segmentedControls.buttons["分块渲染"].waitForExistence(timeout: 10))
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMarkdownImagePlaceholderKeepsAltAndFollowingText() {
        let app = XCUIApplication(bundleIdentifier: "com.giki.markdown")
        openProjectChapter(position: 224, named: "224. 假设检验p值讲解", in: app)

        for _ in 0..<3 { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["图8-7"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["若显著性水平"].waitForExistence(timeout: 10))
        attach(app.screenshot(), named: "IMG-01 Markdown 占位图降级")
    }

    func testHTMLImageAltIsRetainedInTableContent() {
        let app = XCUIApplication(bundleIdentifier: "com.giki.markdown")
        openProjectChapter(position: 364, named: "364. 平稳过程习题解答", in: app)

        XCTAssertTrue(app.staticTexts["自相关函数图，峰值为"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["谱密度图，区间"].waitForExistence(timeout: 10))
        attach(app.screenshot(), named: "IMG-02 HTML 表格图 alt 降级")
    }
}
