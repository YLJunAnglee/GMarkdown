@testable import GMarkdown
import Markdown
import UIKit
import XCTest

final class GMarkTableLayoutTests: XCTestCase {
    func testShortTableFillsAvailableContainerWidth() throws {
        let markdown = try fixture(named: "table_short")

        let wideLayout = try makeLayout(markdown: markdown, containerWidth: 370)
        let narrowLayout = try makeLayout(markdown: markdown, containerWidth: 280)

        XCTAssertEqual(wideLayout.tableContentSize.width, 370, accuracy: 0.01)
        XCTAssertEqual(narrowLayout.tableContentSize.width, 280, accuracy: 0.01)
        XCTAssertEqual(wideLayout.columnWidths.count, 4)
        XCTAssertTrue(wideLayout.columnWidths.allSatisfy { $0 > 60 })
    }

    func testWideTableKeepsReadableColumnsAndOverflowsHorizontally() throws {
        let layout = try makeLayout(
            markdown: try fixture(named: "table_five_columns"),
            containerWidth: 370
        )

        XCTAssertEqual(layout.columnWidths.count, 5)
        XCTAssertGreaterThan(layout.tableContentSize.width, 370)
        XCTAssertTrue(layout.columnWidths.allSatisfy { $0 >= 60 })
    }

    func testUnlimitedLinesUseTheCompleteMeasuredRowHeight() throws {
        var tableStyle = DefaultTableStyle()
        tableStyle.cellMaximumWidth = 90
        tableStyle.maximumNumberOfLines = 0
        let markdown = """
        | 类型 | 内容 |
        | --- | --- |
        | 长文本 | 这是一段必须完整换行显示而不能只保留两行的中文内容 |
        """
        let layout = try makeLayout(
            markdown: markdown,
            containerWidth: 150,
            tableStyle: tableStyle
        )

        let renderer = try XCTUnwrap(layout.bodyRenders.first?[safe: 1])
        let bodyHeight = try XCTUnwrap(layout.rowHeights[safe: 1])
        XCTAssertEqual(renderer.renderAttributes.maximumNumberOfLines, 0)
        XCTAssertGreaterThan(renderer.size().height, tableStyle.cellHeight)
        XCTAssertEqual(
            bodyHeight,
            renderer.size().height + tableStyle.cellPadding.top + tableStyle.cellPadding.bottom,
            accuracy: 0.01
        )
    }

    func testColumnAlignmentAndHeaderTextColorAreApplied() throws {
        var tableStyle = DefaultTableStyle()
        tableStyle.headerTextColor = .systemRed
        let markdown = """
        | 左 | 中 | 右 |
        | :--- | :---: | ---: |
        | A | B | C |
        """
        let layout = try makeLayout(
            markdown: markdown,
            containerWidth: 370,
            tableStyle: tableStyle
        )

        let expectedAlignments: [NSTextAlignment] = [.left, .center, .right]
        for (index, expectedAlignment) in expectedAlignments.enumerated() {
            let attributedText = try XCTUnwrap(
                layout.headerRenders[safe: index]?.renderAttributes.attributedText
            )
            let paragraphStyle = try XCTUnwrap(
                attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                    as? NSParagraphStyle
            )
            let color = try XCTUnwrap(
                attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil)
                    as? UIColor
            )
            XCTAssertEqual(paragraphStyle.alignment, expectedAlignment)
            XCTAssertTrue(color.isEqual(UIColor.systemRed))
        }
    }

    func testTableViewUsesFullScrollableContentWidth() {
        let dataSource = FixedTableDataSource(columnWidth: 200)
        let tableView = GMarkTableView(frame: CGRect(x: 0, y: 0, width: 300, height: 46))
        let style = GMarkTableStyle()
        style.borderWidth = 1
        style.colGap = 1
        style.rowGap = 1
        tableView.style = style
        tableView.dataSource = dataSource
        tableView.register(GMarkTableViewCell.self, forCellReuseIdentifier: "cell")

        tableView.reloadData()
        tableView.layoutIfNeeded()

        XCTAssertEqual(tableView.brScrollView.contentSize.width, 401, accuracy: 0.01)
        XCTAssertEqual(tableView.brScrollView.bounds.width, 298, accuracy: 0.01)
        XCTAssertTrue(tableView.brScrollView.isScrollEnabled)
        XCTAssertTrue(tableView.brScrollView.showsHorizontalScrollIndicator)

        let fittingDataSource = FixedTableDataSource(columnWidth: 100)
        let fittingTableView = GMarkTableView(frame: CGRect(x: 0, y: 0, width: 300, height: 46))
        fittingTableView.style = style
        fittingTableView.dataSource = fittingDataSource
        fittingTableView.register(GMarkTableViewCell.self, forCellReuseIdentifier: "cell")
        fittingTableView.reloadData()
        fittingTableView.layoutIfNeeded()

        XCTAssertFalse(fittingTableView.brScrollView.isScrollEnabled)
        XCTAssertFalse(fittingTableView.brScrollView.showsHorizontalScrollIndicator)
    }
}

private extension GMarkTableLayoutTests {
    func makeLayout(
        markdown: String,
        containerWidth: CGFloat,
        tableStyle: DefaultTableStyle = DefaultTableStyle()
    ) throws -> GMarkTableLayout {
        let table = try XCTUnwrap(
            GMarkParser().parseMarkdownToMarkups(markdown: markdown).first as? Table
        )
        var style = MarkdownStyle.defaultStyle()
        style.maxContainerWidth = containerWidth
        style.tableStyle = tableStyle
        var visitor = GMarkupTableVisitor(style: style)
        return GMarkTableLayout(markTable: visitor.visit(table), style: style)
    }

    func fixture(named name: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "md", subdirectory: "Fixtures"),
            "Missing fixture: \(name).md",
            file: file,
            line: line
        )
        return try String(contentsOf: url, encoding: .utf8)
    }
}

private final class FixedTableDataSource: NSObject, GMarkTableViewDataSource {
    private let columnWidth: CGFloat

    init(columnWidth: CGFloat) {
        self.columnWidth = columnWidth
    }

    func numberOfRows(in _: GMarkTableView) -> Int { 1 }
    func numberOfCols(in _: GMarkTableView) -> Int { 2 }
    func table(_: GMarkTableView, lengthForRow _: Int) -> CGFloat { 44 }
    func table(_: GMarkTableView, lengthForCol _: Int) -> CGFloat { columnWidth }

    func table(
        _ table: GMarkTableView,
        cellForIndexPath indexPath: TabIndexPath
    ) -> GMarkTableViewCell? {
        table.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    }
}
