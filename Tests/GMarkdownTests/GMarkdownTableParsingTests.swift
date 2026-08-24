import Markdown
import XCTest

@testable import GMarkdown

final class GMarkdownTableParsingTests: XCTestCase {
    func testFiveColumnTableStructureAndInlineLatex() throws {
        let table = try parseSingleTable(fixture: "table_five_columns")
        let headers = Array(table.head.cells)
        let rows = Array(table.body.rows)

        XCTAssertEqual(table.maxColumnCount, 5)
        XCTAssertEqual(headers.count, 5)
        XCTAssertEqual(rows.count, 4)
        XCTAssertTrue(rows.allSatisfy { Array($0.cells).count == 5 })
        XCTAssertEqual(headers.map { markupText($0) }, ["球队编号", "比赛场次", "胜场数", "负场数", "积分"])

        let formulaRow = try XCTUnwrap(rows.last)
        XCTAssertTrue(Array(formulaRow.cells).allSatisfy {
            markupText($0) == "<LaTex>$\\cdots$</LaTex>"
        })
    }

    func testShortTableKeepsEmptyHeaderCell() throws {
        let table = try parseSingleTable(fixture: "table_short")
        let headers = Array(table.head.cells)
        let rows = Array(table.body.rows)

        XCTAssertEqual(table.maxColumnCount, 4)
        XCTAssertEqual(headers.count, 4)
        XCTAssertEqual(headers.map { markupText($0) }, ["", "A", "B", "C"])
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy { Array($0.cells).count == 4 })
    }

    func testSupportedEdgeCasesKeepTheirTableShape() throws {
        let markdown = try fixture(named: "table_edge_cases")
        let supportedMarkdown = try section(named: "Supported edge cases", in: markdown)
        let table = try parseSingleTable(markdown: supportedMarkdown)
        let headers = Array(table.head.cells)
        let bodyRows = Array(table.body.rows)

        XCTAssertEqual(table.maxColumnCount, 3)
        XCTAssertEqual(headers.count, 3)
        XCTAssertEqual(bodyRows.count, 6)
        XCTAssertTrue(bodyRows.allSatisfy { Array($0.cells).count == 3 })

        let rows = bodyRows.map { row in
            Array(row.cells).map { markupText($0) }
        }
        XCTAssertEqual(rows[1][1], "")
        XCTAssertEqual(rows[4][1], "第一行<br>第二行")
        XCTAssertEqual(rows[5][1], "左|右")
        XCTAssertTrue(rows[0][1].contains("<LaTex>$v=s/t$</LaTex>"))
        XCTAssertTrue(rows[0][2].contains("粗体"))
        XCTAssertTrue(rows[0][2].contains("斜体"))
        XCTAssertTrue(rows[0][2].contains("删除线"))
    }

    func testLongLatexKeepsTableStructureDuringPreprocessing() throws {
        let markdown = try fixture(named: "table_edge_cases")
        let longLatexMarkdown = try section(named: "Known long LaTeX issue", in: markdown)

        let rawTable = try parseSingleTableWithoutPreprocessing(markdown: longLatexMarkdown)
        let processedTable = try parseSingleTable(markdown: longLatexMarkdown)

        let rawShape = tableShape(rawTable)
        let processedShape = tableShape(processedTable)

        XCTAssertEqual(rawShape, TableShape(columns: 3, bodyRows: 2, cellsPerRow: [3, 3]))
        XCTAssertEqual(processedShape, rawShape)

        let processedRows = Array(processedTable.body.rows)
        let longFormulaRow = try XCTUnwrap(processedRows.last)
        XCTAssertEqual(Array(longFormulaRow.cells).map { markupText($0) }, [
            "长公式",
            "<LaTex>$\\frac{x_1+x_2+x_3+x_4+x_5}{y_1+y_2+y_3+y_4+y_5}$</LaTex>",
            "当前预处理会插入换行",
        ])
    }

    func testLongLatexInTableHeaderKeepsTableStructure() throws {
        let expression = "$\\frac{x_1+x_2+x_3+x_4+x_5}{y_1+y_2+y_3+y_4+y_5}$"
        let markdown = """
        | \(expression) | 备注 |
        | --- | --- |
        | 结果 | 正常 |
        """

        let table = try parseSingleTable(markdown: markdown)
        XCTAssertEqual(tableShape(table), TableShape(columns: 2, bodyRows: 1, cellsPerRow: [2]))
        XCTAssertEqual(
            markupText(try XCTUnwrap(Array(table.head.cells).first)),
            "<LaTex>\(expression)</LaTex>"
        )
    }

    func testLongLatexOutsideTableKeepsExistingBlockFormatting() {
        let expression = "$\\frac{x_1+x_2+x_3+x_4+x_5}{y_1+y_2+y_3+y_4+y_5}$"
        let markdown = "正文 A | B 中的长公式 \(expression) 结束"

        XCTAssertEqual(
            LaTeXPreprocessor().process(markdown),
            "正文 A | B 中的长公式 \n <LaTex>\(expression)</LaTex> \n 结束"
        )
    }

    func testUnevenRowsAreNormalizedToHeaderWidth() throws {
        let markdown = try fixture(named: "table_edge_cases")
        let unevenMarkdown = try section(named: "Uneven rows", in: markdown)
        let table = try parseSingleTable(markdown: unevenMarkdown)
        let headers = Array(table.head.cells)
        let rows = Array(table.body.rows)

        XCTAssertEqual(table.maxColumnCount, 3)
        XCTAssertEqual(headers.count, 3)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.map { Array($0.cells).count }, [3, 3])
        XCTAssertEqual(Array(rows[0].cells).map { markupText($0) }, ["少一列", "only two cells", ""])
        XCTAssertEqual(Array(rows[1].cells).map { markupText($0) }, ["多一列", "second", "third"])
    }
}

private extension GMarkdownTableParsingTests {
    struct TableShape: Equatable {
        let columns: Int
        let bodyRows: Int
        let cellsPerRow: [Int]
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

    func section(named name: String, in markdown: String) throws -> String {
        let marker = "## \(name)"
        let markerRange = try XCTUnwrap(markdown.range(of: marker), "Missing section: \(name)")
        let contentStart = markerRange.upperBound
        let remainder = markdown[contentStart...]
        let contentEnd = remainder.range(of: "\n## ")?.lowerBound ?? markdown.endIndex
        return String(markdown[contentStart..<contentEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parseSingleTable(
        fixture name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Table {
        try parseSingleTable(markdown: fixture(named: name), file: file, line: line)
    }

    func parseSingleTable(
        markdown: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Table {
        let markups = GMarkParser().parseMarkdownToMarkups(markdown: markdown)
        let tables = markups.compactMap { $0 as? Table }
        XCTAssertEqual(tables.count, 1, "Expected exactly one table", file: file, line: line)
        return try XCTUnwrap(tables.first, file: file, line: line)
    }

    func parseSingleTableWithoutPreprocessing(
        markdown: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Table {
        let document = Document(parsing: markdown)
        let tables = Array(document.children).compactMap { $0 as? Table }
        XCTAssertEqual(tables.count, 1, "Expected exactly one raw table", file: file, line: line)
        return try XCTUnwrap(tables.first, file: file, line: line)
    }

    func markupText(_ markup: Markup) -> String {
        if let text = markup as? Text {
            return text.plainText
        }
        if let inlineHTML = markup as? InlineHTML {
            return inlineHTML.rawHTML
        }
        if let lineBreak = markup as? LineBreak {
            return lineBreak.plainText
        }
        if markup is SoftBreak {
            return "\n"
        }
        return markup.children.map(markupText).joined()
    }

    func tableShape(_ table: Table) -> TableShape {
        let rows = Array(table.body.rows)
        return TableShape(
            columns: table.maxColumnCount,
            bodyRows: rows.count,
            cellsPerRow: rows.map { Array($0.cells).count }
        )
    }
}
