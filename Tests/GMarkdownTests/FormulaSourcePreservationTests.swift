import XCTest
import Markdown
@testable import GMarkdown

final class FormulaSourcePreservationTests: XCTestCase {
    private func formulas(_ source: String) -> [String] {
        var results: [String] = []
        var inside = false
        func walk(_ node: Markup) {
            if let html = node as? InlineHTML {
                if html.rawHTML == "<LaTex>" { inside = true; results.append("") }
                if html.rawHTML == "</LaTex>" { inside = false }
            } else if inside, let text = node as? Text {
                results[results.count - 1] += text.string
            }
            for child in node.children { walk(child) }
        }
        walk(GMarkParser().parseMarkdown(from: source))
        return results
    }

    func testVisibleBracesAndGroupingRemainDifferent() {
        let visible = #"$$P(\{e_i\})$$"#
        let grouped = #"$$P({e_i})$$"#
        XCTAssertEqual(formulas(visible + "\n\n" + grouped), [visible, grouped])
        var stringifier = GMarkupStringifier()
        let document = GMarkParser().parseMarkdown(from: visible)
        XCTAssertEqual(stringifier.visit(document).trimmingCharacters(in: .whitespacesAndNewlines), visible)
    }

    func testPunctuationUnicodeAndEntitySpellingRemainLiteral() {
        let source = #"$$\{a_b\} * c ** d &amp; <x> | 中文 \text{事件}$$"#
        XCTAssertEqual(formulas(source), [source])
    }

    func testMultilineAndAdjacentFormulasPreservePayloads() {
        let block = "$$\n\\begin{aligned}a&=b\\\\\nc&=d\\end{aligned}\n$$"
        let inline = #"$P(\{e_i\})$"#
        XCTAssertEqual(formulas(block + "\n\n正文 " + inline + inline), [block, inline, inline])
    }

    func testTableKeepsLongFormulaAndPipeInOneCell() {
        let formula = #"$P(\{e_i\})=\frac{123456789}{987654321}\mid |x|$"#
        let source = "| 公式 | 说明 |\n| --- | --- |\n| \(formula) | 原文 |"
        let document = GMarkParser().parseMarkdown(from: source)
        XCTAssertTrue(document.child(at: 0) is Table)
        XCTAssertEqual(formulas(source), [formula])
        if let table = document.child(at: 0) as? Table {
            XCTAssertEqual(table.body.childCount, 1)
            XCTAssertEqual(table.body.child(at: 0)?.childCount, 2)
        }
    }

    func testCodeRegionsAreNotWrappedAndDoNotConsumeFollowingFormula() {
        let real = #"$P(\{e_i\})$"#
        let source = "`$ unmatched`\n\n```latex\n$$x_y$$\n```\n\n    $$z_w$$\n\n正文 " + real
        XCTAssertEqual(formulas(source), [real])
        let processed = LaTeXPreprocessor().process(source)
        XCTAssertTrue(processed.contains("`$ unmatched`"))
        XCTAssertTrue(processed.contains("```latex\n$$x_y$$\n```"))
        XCTAssertTrue(processed.contains("    $$z_w$$"))
    }

    func testBackslashDelimitersArePreservedDuringParsing() {
        let source = #"\(P(\{e_i\})\)"#
        XCTAssertEqual(formulas(source), [source])
    }

    func testFormulaTrailingBackslashIsNotRewrittenByStringifier() {
        let source = "$$a \\\n$$"
        var stringifier = GMarkupStringifier()
        XCTAssertEqual(stringifier.visit(GMarkParser().parseMarkdown(from: source))
            .trimmingCharacters(in: .whitespacesAndNewlines), source)
    }
}
