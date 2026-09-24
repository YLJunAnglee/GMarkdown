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

    func testMalformedAlignedDisplayDelimiterDoesNotConsumeFollowingTableCell() {
        let malformed = #"""
| 类型 | 公式 |
| --- | --- |
| 人工 | $\begin{aligned}a&=b\\c&=d\end{aligned}$$ |
| 后续 | $\begin{aligned}e&=f\end{aligned}$ |
"""#
        let expected = #"$$\begin{aligned}a&=b\\c&=d\end{aligned}$$"#
        XCTAssertEqual(formulas(malformed), [expected, #"$\begin{aligned}e&=f\end{aligned}$"#])
        let document = GMarkParser().parseMarkdown(from: malformed)
        guard let table = document.child(at: 0) as? Table else { return XCTFail("Table must survive recovery") }
        XCTAssertEqual(table.body.childCount, 2)
    }

    func testMalformedAlignedRecoveryDoesNotConsumeAnAdjacentFormula() {
        let adjacent = #"$\begin{aligned}a&=b\end{aligned}$$x^2$"#
        XCTAssertEqual(formulas(adjacent), [#"$\begin{aligned}a&=b\end{aligned}$"#, #"$x^2$"#])
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

    // MARK: - Real project-book numbered formulas

    func testProjectBookTagKeepsChineseVisibleBracesAndNumber() {
        // projectBook.jsonl / chapter 20 / block 6aa0cd5e0b9538772a926c23
        let source = "$$\n"
            + #"P(A) = \sum_{j=1}^k P(\{e_{i_j}\}) = \frac{k}{n}"# + "\n"
            + #"= \frac{A \text{ 包含的基本事件数}}{S \text{ 中基本事件的总数}}. \tag{4.1}"# + "\n$$"

        XCTAssertEqual(formulas(source), [source])
        var stringifier = GMarkupStringifier()
        XCTAssertEqual(stringifier.visit(GMarkParser().parseMarkdown(from: source))
            .trimmingCharacters(in: .whitespacesAndNewlines), source)
    }

    func testProjectBookTagKeepsCasesAndChineseText() {
        // projectBook.jsonl / chapter 151 / block 6aa0cd6b0b9538772a926d2d
        let source = #"$$\psi(y)= \begin{cases}\frac{\Gamma\left[\left(n_{1}+n_{2}\right) / 2\right]}{\Gamma\left(n_{1} / 2\right) \Gamma\left(n_{2} / 2\right)}, & y>0, \\ 0, & \text { 其他. }\end{cases} \tag{3.15}$$"#

        XCTAssertEqual(formulas(source), [source])
        var stringifier = GMarkupStringifier()
        XCTAssertEqual(stringifier.visit(GMarkParser().parseMarkdown(from: source))
            .trimmingCharacters(in: .whitespacesAndNewlines), source)
    }

    func testProjectBookConsecutiveTaggedFormulasStaySeparate() {
        // projectBook.jsonl / chapter 285 / block 6aa0cd820b9538772a926f15
        let first = #"$$\hat{\theta}_{(1)}^{*} \leqslant \hat{\theta}_{(B)}^{*}. \tag{1.4}$$"#
        let second = #"$$P\{\hat{\theta}_{a/2}^{*}<\theta<\hat{\theta}_{1-a/2}^{*}\}=1-\alpha. \tag{1.5}$$"#
        let source = first + "\n\n正文。\n\n" + second

        XCTAssertEqual(formulas(source), [first, second])
        let nodes = GMarkParser().parseMarkdownToMarkups(markdown: source)
        XCTAssertEqual(nodes.filter { LaTexMarkupHandler().canHandle($0) }.count, 2)
    }

    func testProjectBookCompactTaggedInputDoesNotConsumeFollowingText() {
        // book-68F258…jsonl / chapter 60 / block 6a9d753c0b953867aebb0a5b
        let first = #"$$x_1x_2 = \frac{p^2}{4}, y_1y_2 = - p^2; \tag{1}$$"#
        let second = #"$$|AB| = \frac{2 p}{\sin^2 q}; \tag{2}$$"#
        let third = #"$$\frac{1}{|FA|} + \frac{1}{|FB|} = \frac{2}{P}. \tag{5}$$"#
        let source = "关于抛物线焦点弦：" + first + second + "后续正文。" + third

        XCTAssertEqual(formulas(source), [first, second, third])
        var stringifier = GMarkupStringifier()
        let renderedSource = stringifier.visit(GMarkParser().parseMarkdown(from: source))
        XCTAssertTrue(renderedSource.contains("后续正文。"))
        XCTAssertTrue(renderedSource.contains(#"\tag{5}"#))
    }
}
