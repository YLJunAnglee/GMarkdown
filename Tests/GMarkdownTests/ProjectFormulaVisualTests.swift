import XCTest

final class ProjectFormulaVisualTests: XCTestCase {
    private func attach(_ image: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openChapter(position: Int, named title: String, in app: XCUIApplication) {
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

    func testProjectBookTaggedFormulaIsReachableThroughChunkRenderer() {
        let app = XCUIApplication(bundleIdentifier: "com.giki.markdown")
        app.launch()

        XCTAssertTrue(app.staticTexts["项目书籍测试"].waitForExistence(timeout: 10))
        app.staticTexts["项目书籍测试"].tap()

        let book = app.tables.cells.element(boundBy: 0)
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        book.tap()

        let comparison = app.buttons["公式对照"]
        XCTAssertTrue(comparison.waitForExistence(timeout: 10))
        comparison.tap()

        let originalFormula = app.staticTexts["4. 公式 (4.1) · 原文"]
        XCTAssertTrue(originalFormula.waitForExistence(timeout: 10))
        originalFormula.tap()

        XCTAssertTrue(app.segmentedControls.buttons["分块渲染"].isSelected)
        attach(app.screenshot(), named: "TAG-01 分块渲染")
    }

    func testTAG02AppearsInChapterChunkRenderer() {
        let app = XCUIApplication(bundleIdentifier: "com.giki.markdown")
        openChapter(position: 151, named: "151. t分布与F分布介绍", in: app)
        attach(app.screenshot(), named: "TAG-02 分块渲染")
    }

    func testTAG03AppearsAfterHTMLInChapterChunkRenderer() {
        let app = XCUIApplication(bundleIdentifier: "com.giki.markdown")
        openChapter(position: 244, named: "244. 双因素等重复试验设定", in: app)
        for _ in 0..<6 { app.swipeUp() }
        attach(app.screenshot(), named: "TAG-03 分块渲染")
    }

    func testTAG04AppearsInChapterChunkRenderer() {
        let app = XCUIApplication(bundleIdentifier: "com.giki.markdown")
        openChapter(position: 285, named: "285. Bootstrap置信区间方法", in: app)
        attach(app.screenshot(), named: "TAG-04 编号公式")
        for _ in 0..<6 { app.swipeUp() }
        attach(app.screenshot(), named: "TAG-04 长 aligned 公式")
    }
}
