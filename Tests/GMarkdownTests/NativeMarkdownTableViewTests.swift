import GMarkdown
import XCTest

final class NativeMarkdownTableViewTests: XCTestCase {
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

    func testClearRemovesTheCurrentRenderResult() throws {
        let view = NativeMarkdownTableView()
        XCTAssertTrue(
            view.render(markdown: try fixture(named: "table_short"), containerWidth: 370).isSuccess
        )

        view.clear()

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
