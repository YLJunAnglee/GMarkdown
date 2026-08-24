import GMarkdown
import XCTest

final class NativeMarkdownTableViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NativeMarkdownTableView.clearRenderCache()
    }

    func testRendersOneTableWithoutExposingInternalTypes() throws {
        let view = NativeMarkdownTableView()
        let result = view.render(
            markdown: try fixture(named: "table_five_columns"),
            containerWidth: 370
        )

        let metrics = try XCTUnwrap(result.metrics)
        XCTAssertTrue(result.isSuccess)
        XCTAssertNil(result.failure)
        XCTAssertEqual(metrics.columnCount, 5)
        XCTAssertEqual(metrics.bodyRowCount, 4)
        XCTAssertEqual(metrics.requiredSize.width, 370)
        XCTAssertGreaterThan(metrics.requiredSize.height, 0)
        XCTAssertEqual(view.intrinsicContentSize, metrics.requiredSize)
    }

    func testRerenderUsesTheNewContainerWidth() throws {
        let view = NativeMarkdownTableView()
        let markdown = try fixture(named: "table_short")

        let firstResult = view.render(markdown: markdown, containerWidth: 370)
        let secondResult = view.render(markdown: markdown, containerWidth: 280)

        XCTAssertEqual(firstResult.metrics?.requiredSize.width, 370)
        XCTAssertEqual(secondResult.metrics?.requiredSize.width, 280)
        XCTAssertEqual(view.intrinsicContentSize.width, 280)
        XCTAssertEqual(firstResult.metrics?.columnCount, secondResult.metrics?.columnCount)
        XCTAssertEqual(firstResult.metrics?.bodyRowCount, secondResult.metrics?.bodyRowCount)
    }

    func testRerenderReflowsCompleteContentForTheNewWidth() throws {
        var tableStyle = DefaultTableStyle()
        tableStyle.cellMaximumWidth = 120
        tableStyle.maximumNumberOfLines = 0
        var style = MarkdownStyle.defaultStyle()
        style.tableStyle = tableStyle
        let markdown = """
        | 类型 | 内容 |
        | --- | --- |
        | 长文本 | 这是一段用于验证容器宽度变化后重新换行并计算完整行高的中文内容 |
        """
        let view = NativeMarkdownTableView()

        let wideResult = view.render(markdown: markdown, style: style, containerWidth: 370)
        let narrowResult = view.render(markdown: markdown, style: style, containerWidth: 280)

        let wideHeight = try XCTUnwrap(wideResult.metrics?.requiredSize.height)
        let narrowHeight = try XCTUnwrap(narrowResult.metrics?.requiredSize.height)
        XCTAssertGreaterThan(narrowHeight, wideHeight)
        XCTAssertEqual(view.intrinsicContentSize.height, narrowHeight)
    }

    func testRendersLongLatexTableThroughPublicAPI() throws {
        let markdown = try fixture(named: "table_edge_cases")
        let longLatexTable = try section(named: "Known long LaTeX issue", in: markdown)
        let view = NativeMarkdownTableView()

        let result = view.render(markdown: longLatexTable, containerWidth: 370)

        XCTAssertEqual(result.metrics?.columnCount, 3)
        XCTAssertEqual(result.metrics?.bodyRowCount, 2)
        XCTAssertGreaterThan(result.metrics?.requiredSize.height ?? 0, 0)
    }

    func testReturnsExplicitFailuresForUnsupportedInputs() throws {
        let view = NativeMarkdownTableView()

        XCTAssertEqual(
            view.render(markdown: "", containerWidth: 370),
            .failure(.emptyMarkdown)
        )
        XCTAssertEqual(
            view.render(markdown: "plain text", containerWidth: 370),
            .failure(.tableNotFound)
        )
        XCTAssertEqual(
            view.render(markdown: try fixture(named: "table_short"), containerWidth: 0),
            .failure(.invalidContainerWidth)
        )
        XCTAssertEqual(
            view.render(markdown: try fixture(named: "table_edge_cases"), containerWidth: 370),
            .failure(.multipleTables(count: 3))
        )

        let tableWithHeading = """
        # Heading

        | A | B |
        | --- | --- |
        | 1 | 2 |
        """
        XCTAssertEqual(
            view.render(markdown: tableWithHeading, containerWidth: 370),
            .failure(.containsUnsupportedContent)
        )
        XCTAssertEqual(view.intrinsicContentSize, .zero)
    }

    func testReturnsExplicitFailureForInvalidCalculatedSize() throws {
        var tableStyle = DefaultTableStyle()
        tableStyle.padding.top = .infinity
        var style = MarkdownStyle.defaultStyle()
        style.tableStyle = tableStyle

        XCTAssertEqual(
            NativeMarkdownTableView().render(
                markdown: try fixture(named: "table_short"),
                style: style,
                containerWidth: 370
            ),
            .failure(.invalidCalculatedSize)
        )
    }

    func testClearRemovesTheCurrentRenderResult() throws {
        let view = NativeMarkdownTableView()
        XCTAssertTrue(
            view.render(markdown: try fixture(named: "table_short"), containerWidth: 370).isSuccess
        )

        view.clear()

        XCTAssertEqual(view.lastRenderResult, .failure(.emptyMarkdown))
        XCTAssertEqual(view.intrinsicContentSize, .zero)
    }

    func testRepeatedRenderUsesCacheAndRecordsStableHeight() throws {
        let view = NativeMarkdownTableView()
        let markdown = try fixture(named: "table_short")

        let first = try XCTUnwrap(view.render(markdown: markdown, containerWidth: 370).metrics)
        let second = try XCTUnwrap(view.render(markdown: markdown, containerWidth: 370).metrics)

        XCTAssertFalse(first.performance.cacheHit)
        XCTAssertGreaterThanOrEqual(first.performance.parseDuration, 0)
        XCTAssertGreaterThanOrEqual(first.performance.formulaRenderDuration, 0)
        XCTAssertGreaterThanOrEqual(first.performance.layoutDuration, 0)
        XCTAssertGreaterThanOrEqual(first.performance.totalDuration, 0)
        XCTAssertTrue(second.performance.cacheHit)
        XCTAssertEqual(second.performance.parseDuration, 0)
        XCTAssertEqual(second.performance.formulaRenderDuration, 0)
        XCTAssertEqual(second.performance.layoutDuration, 0)
        XCTAssertEqual(second.heightDelta, 0)
        XCTAssertEqual(first.requiredSize, second.requiredSize)
        XCTAssertTrue(second.warnings.isEmpty)
    }

    func testCacheSeparatesContentWidthAndStyle() throws {
        let view = NativeMarkdownTableView()
        let shortTable = try fixture(named: "table_short")
        let wideTable = try fixture(named: "table_five_columns")

        XCTAssertFalse(
            try XCTUnwrap(view.render(markdown: shortTable, containerWidth: 370).metrics)
                .performance.cacheHit
        )
        XCTAssertFalse(
            try XCTUnwrap(view.render(markdown: shortTable, containerWidth: 280).metrics)
                .performance.cacheHit
        )
        XCTAssertFalse(
            try XCTUnwrap(view.render(markdown: wideTable, containerWidth: 280).metrics)
                .performance.cacheHit
        )

        var tableStyle = DefaultTableStyle()
        tableStyle.headerBackgroundColor = .systemRed
        var style = MarkdownStyle.defaultStyle()
        style.tableStyle = tableStyle
        XCTAssertFalse(
            try XCTUnwrap(
                view.render(markdown: shortTable, style: style, containerWidth: 370).metrics
            ).performance.cacheHit
        )
        XCTAssertTrue(
            try XCTUnwrap(
                view.render(markdown: shortTable, style: style, containerWidth: 370).metrics
            ).performance.cacheHit
        )
    }

    func testNewestAsyncRenderWinsDuringViewReuse() throws {
        let view = NativeMarkdownTableView()
        let staleCompletion = expectation(description: "obsolete render must not complete")
        staleCompletion.isInverted = true
        let newestCompletion = expectation(description: "newest render completes")

        let staleTask = view.renderAsync(
            markdown: try fixture(named: "table_five_columns"),
            containerWidth: 370
        ) { _ in
            staleCompletion.fulfill()
        }
        _ = view.renderAsync(
            markdown: try fixture(named: "table_short"),
            containerWidth: 280
        ) { result in
            XCTAssertEqual(result.metrics?.columnCount, 4)
            XCTAssertEqual(result.metrics?.requiredSize.width, 280)
            newestCompletion.fulfill()
        }

        XCTAssertTrue(staleTask.isCancelled)
        wait(for: [newestCompletion, staleCompletion], timeout: 0.2)
        XCTAssertEqual(view.lastRenderResult.metrics?.columnCount, 4)
        XCTAssertEqual(view.intrinsicContentSize.width, 280)
    }

    func testClearCancelsPendingAsyncWriteBack() throws {
        let view = NativeMarkdownTableView()
        let obsoleteCompletion = expectation(description: "cleared render must not complete")
        obsoleteCompletion.isInverted = true
        let task = view.renderAsync(
            markdown: try fixture(named: "table_short"),
            containerWidth: 370
        ) { _ in
            obsoleteCompletion.fulfill()
        }

        view.clear()

        XCTAssertTrue(task.isCancelled)
        wait(for: [obsoleteCompletion], timeout: 0.1)
        XCTAssertEqual(view.lastRenderResult, .failure(.emptyMarkdown))
        XCTAssertEqual(view.intrinsicContentSize, .zero)
    }
}

private extension NativeMarkdownTableViewTests {
    func fixture(named name: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "md", subdirectory: "Fixtures"),
            "Missing fixture: \(name).md",
            file: file,
            line: line
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    func section(named name: String, in markdown: String) throws -> String {
        let marker = "## \(name)"
        let markerRange = try XCTUnwrap(markdown.range(of: marker), "Missing section: \(name)")
        let remainder = markdown[markerRange.upperBound...]
        let end = remainder.range(of: "\n## ")?.lowerBound ?? markdown.endIndex
        return String(markdown[markerRange.upperBound..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
