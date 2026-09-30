import XCTest
import UIKit
import MPITextKit
@testable import GMarkdown

final class HTMLSanitizerTests: XCTestCase {
    private let style = MarkdownStyle.defaultStyle()

    func testEntitiesDecodeOnceAndKeepNBSPAcrossInlineTags() {
        let html = "<p>&#20013;&#x1F600; &amp;#65; &lt;b&gt;<span>&nbsp;</span><b>A</b> <i>B</i></p>"
        let result = GMarkHTMLSanitizer.attributedString(from: html, style: style)
        XCTAssertEqual(result.string, "中😀 &#65; <b>\u{00A0}A B\n")
        XCTAssertEqual(GMarkHTMLTokens.decode("&#0;&#xD800;&#1114112;&#9999999999999999999999;&#x80;"), "����€")
        XCTAssertEqual(GMarkHTMLTokens.decode("&unknown; &#xNO; &#65 &amp;lt;"), "&unknown; &#xNO; &#65 &lt;")
    }

    func testAttributesCommentsAndMismatchedClosingKeepScopesBounded() {
        let html = #"<p data-dir="rtl" data-style="color:#ff0000"><span style="color:#4F5CE7"><b>甲</span>乙<!-- > 隐藏 <b> -->丙</p><head><title>隐藏标题</title></head>"#
        let result = GMarkHTMLSanitizer.attributedString(from: html, style: style)
        XCTAssertEqual(result.string, "甲乙丙\n")
        let first = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let second = result.attribute(.font, at: 1, effectiveRange: nil) as? UIFont
        XCTAssertTrue(first?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertFalse(second?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        let paragraph = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(paragraph?.baseWritingDirection, .natural)
        XCTAssertEqual(result.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? UIColor, style.colors.current)
    }

    func testExplicitHTMLNeverUsesMarkdownPreprocessingAndKeepsOuterDirectionAcrossBlankLines() {
        let html = "<html dir='rtl'><body>\n\n<p>$x$ **文字** ```</p>\n\n<p>第二段</p></body></html>"
        let chunks = GMarkHTMLProcessor(style: style, maxAttributedStringLength: 8).process(html: html)
        XCTAssertEqual(chunks.map { $0.attributedText.string }.joined(), "$x$ **文字** ```\n第二段\n")
        XCTAssertEqual(chunks.count, 2)
        for chunk in chunks {
            XCTAssertGreaterThan(chunk.attributedText.length, 0)
            let paragraph = chunk.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            XCTAssertEqual(paragraph?.baseWritingDirection, .rightToLeft)
        }
    }

    func testAutoDirectionUsesWholeElementAndSkipsExplicitChildDirections() {
        let html = "<div dir='auto'><p><span dir='ltr'>ABC</span><b>123 </b>שלום</p><p>English</p></div><p dir='ltr'>שלום</p>"
        let result = GMarkHTMLSanitizer.attributedString(from: html, style: style)
        let string = result.string as NSString
        let first = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let second = result.attribute(.paragraphStyle, at: string.range(of: "English").location, effectiveRange: nil) as? NSParagraphStyle
        let third = result.attribute(.paragraphStyle, at: string.range(of: "שלום", options: .backwards).location, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(first?.baseWritingDirection, .rightToLeft)
        XCTAssertEqual(second?.baseWritingDirection, .rightToLeft)
        XCTAssertEqual(third?.baseWritingDirection, .leftToRight)
        XCTAssertEqual(result.attribute(.writingDirection, at: 0, effectiveRange: nil) as? [Int], [NSWritingDirection.leftToRight.rawValue])
    }

    func testMarkedRangesUseDecodedUTF16AndSurviveChunkingAndFontScaling() {
        let html = "<p>前<CustomClickableSpan>&#x1F600;<b>中文</b><u>下划线</u></CustomClickableSpan><CustomClickableSpan>后</CustomClickableSpan></p><p>未标记</p>"
        let chunks = GMarkHTMLProcessor(style: style, maxAttributedStringLength: 4).process(html: html)
        XCTAssertEqual(chunks.count, 2)
        let text = chunks[0].attributedText
        var ranges: [NSRange] = []
        var ids: [String] = []
        text.enumerateAttribute(.gmarkCustomClickableSpan, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if let id = value as? String { ranges.append(range); ids.append(id) }
        }
        XCTAssertEqual(ranges, [NSRange(location: 1, length: 7), NSRange(location: 8, length: 1)])
        XCTAssertNotEqual(ids.first, ids.last)
        XCTAssertEqual(text.attribute(.underlineStyle, at: 5, effectiveRange: nil) as? Int,
                       NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue)
        let scaled = text.scaledFonts(compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        XCTAssertEqual(scaled.string, text.string)
        XCTAssertEqual(scaled.attribute(.gmarkCustomClickableSpan, at: 1, effectiveRange: nil) as? String, ids.first)
        XCTAssertNil(chunks[1].attributedText.attribute(.gmarkCustomClickableSpan, at: 0, effectiveRange: nil))
    }

    func testUnclosedMarksStopAtParagraphBoundariesAndNestedMarksDoNotLeak() {
        let html = "<p><CustomClickableSpan>A<CustomClickableSpan>B</CustomClickableSpan>C</p><p>D<CustomClickableSpan/></p>"
        let result = GMarkHTMLSanitizer.attributedString(from: html, style: style)
        XCTAssertEqual(result.string, "ABC\nD\n")
        XCTAssertEqual(result.attribute(.gmarkCustomClickableSpan, at: 0, effectiveRange: nil) as? String,
                       result.attribute(.gmarkCustomClickableSpan, at: 2, effectiveRange: nil) as? String)
        XCTAssertNil(result.attribute(.gmarkCustomClickableSpan, at: 4, effectiveRange: nil))
        let deep = String(repeating: "<span>", count: 500) + "可读" + String(repeating: "</span>", count: 500)
        XCTAssertEqual(GMarkHTMLSanitizer.attributedString(from: deep, style: style).string, "可读")
    }

    func testRemovedEmptyListItemsStillReportExistingImageFallbacks() {
        var fallbacks: [Bool] = []
        let result = GMarkHTMLSanitizer.attributedString(from: "<ul><li><img alt=''></li><li><img alt='&#20013;'></li></ul>", style: style) {
            fallbacks.append($0)
        }
        XCTAssertEqual(fallbacks, [false, true])
        XCTAssertEqual(result.string, "• 中\n")
    }

    func testMarkAcrossBreakKeepsIdentityWithoutMarkingTheBreak() {
        let chunks = GMarkHTMLProcessor(style: style, maxAttributedStringLength: 2)
            .process(html: "<p><CustomClickableSpan>A<br>😀</CustomClickableSpan>B</p>")
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks.map { $0.attributedText.string }.joined(), "A\n😀B\n")
        let first = chunks[0].attributedText
        let second = chunks[1].attributedText
        XCTAssertNotNil(first.attribute(.gmarkCustomClickableSpan, at: 0, effectiveRange: nil))
        XCTAssertEqual(first.attribute(.gmarkCustomClickableSpan, at: 0, effectiveRange: nil) as? String,
                       second.attribute(.gmarkCustomClickableSpan, at: 0, effectiveRange: nil) as? String)
        XCTAssertNil(first.attribute(.gmarkCustomClickableSpan, at: 1, effectiveRange: nil))
        XCTAssertNil(second.attribute(.gmarkCustomClickableSpan, at: 2, effectiveRange: nil))
    }

    func testUnstyledInlineHTMLPreservesMarkdownParagraphSpacingAndDecodedText() {
        var state = GMarkHTMLSanitizer.InlineState()
        let plain = GMarkHTMLSanitizer.attributedText(from: "&#65;", style: style, state: state)
        _ = GMarkHTMLSanitizer.applyInlineToken("<b>", to: &state, style: style)
        let bold = GMarkHTMLSanitizer.attributedText(from: "&#65;", style: style, state: state)
        XCTAssertEqual(bold.string, "&#65;")
        XCTAssertEqual((bold.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacing,
                       (plain.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacing)
        XCTAssertTrue((bold.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    func testMarkDecorationAlignsAcrossRunsAndReflowsWithoutClipping() throws {
        var wideStyle = style
        wideStyle.maxContainerWidth = 600
        let chunk = try XCTUnwrap(GMarkHTMLProcessor(style: wideStyle).process(html:
            "<p style='font-size:32px'><CustomClickableSpan>中文ABC</CustomClickableSpan><CustomClickableSpan>第二处😀</CustomClickableSpan><u>普通</u></p>").first)
        let original = chunk.attributedText
        let wide = try XCTUnwrap(chunk.textRender as? GMarkMarkedTextRenderer)
        XCTAssertEqual(wide.markLines.count, 2)
        XCTAssertEqual(wide.markLines[0].minY, wide.markLines[1].minY, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(wide.markLines[0].minY,
                                    wide.lineFragmentUsedRectForCharacter(at: 0, effectiveRange: nil).maxY + 2)
        XCTAssertNil(wide.renderAttributes.attributedText?.attribute(.underlineStyle, at: 0, effectiveRange: nil))
        XCTAssertNotNil(original.attribute(.underlineStyle, at: 0, effectiveRange: nil))
        let ordinary = (original.string as NSString).range(of: "普通").location
        XCTAssertEqual(wide.renderAttributes.attributedText?.attribute(.underlineStyle, at: ordinary, effectiveRange: nil) as? Int,
                       NSUnderlineStyle.single.rawValue)
        XCTAssertTrue(chunk.relayout(for: 110, preserving: wideStyle))
        let narrow = try XCTUnwrap(chunk.textRender as? GMarkMarkedTextRenderer)
        XCTAssertGreaterThan(narrow.markLines.count, wide.markLines.count)
        XCTAssertTrue(chunk.attributedText.isEqual(to: original))
        for line in narrow.markLines {
            XCTAssertGreaterThanOrEqual(line.minX, 0)
            XCTAssertLessThanOrEqual(line.maxX, 110)
            XCTAssertLessThanOrEqual(line.maxY, chunk.itemSize.height)
        }
        let plain = try XCTUnwrap(GMarkHTMLProcessor(style: style).process(html: "<p><u>普通下划线</u></p>").first)
        XCTAssertFalse(plain.textRender is GMarkMarkedTextRenderer)
    }

    @MainActor
    func testSameIdentityStyleUpdateReconfiguresVisibleText() throws {
        func settleDisplay() {
            let settled = expectation(description: "Collection view applied its snapshot")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { settled.fulfill() }
            wait(for: [settled], timeout: 2)
        }
        let controller = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let view = GMarkdownMultiView(frame: window.bounds)
        controller.view.addSubview(view)
        var fixedStyle = style
        fixedStyle.maxContainerWidth = 320
        let processor = GMarkHTMLProcessor(style: fixedStyle, identifier: "same-document")
        let first = processor.process(html: "<p style='color:#ff0000'>同一段文字</p>")
        let second = processor.process(html: "<p style='color:#0000ff'>同一段文字</p>")
        XCTAssertEqual(first.first?.hashKey, second.first?.hashKey)
        view.updateMarkdown(first)
        settleDisplay()
        view.updateMarkdown(second)
        view.layoutIfNeeded()
        settleDisplay()
        func labels(_ parent: UIView) -> [MPILabel] {
            parent.subviews.flatMap { child in (child as? MPILabel).map { [$0] } ?? labels(child) }
        }
        let label = try XCTUnwrap(labels(view).first)
        XCTAssertEqual(label.attributedText?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .blue)
        view.updateMarkdown(processor.process(html: "<p><CustomClickableSpan>同一段文字</CustomClickableSpan></p>"))
        settleDisplay()
        let markedLabel = try XCTUnwrap(labels(view).first)
        XCTAssertTrue(markedLabel.textRenderer is GMarkMarkedTextRenderer)
        view.updateMarkdown(second)
        settleDisplay()
        let plainLabel = try XCTUnwrap(labels(view).first)
        XCTAssertFalse(plainLabel.textRenderer is GMarkMarkedTextRenderer)
    }

    func testMarkGeometryStaysOnItsLineWithParagraphSpacingAndRTL() throws {
        for direction in ["ltr", "rtl"] {
            for spacing in [0, 100] {
                var constrained = style
                constrained.maxContainerWidth = 140
                let html = "<p dir='\(direction)' style='margin-bottom:\(spacing)px'><CustomClickableSpan>שלום ABC 中文 😀 123</CustomClickableSpan></p><p>后面的普通段落</p>"
                let chunk = try XCTUnwrap(GMarkHTMLProcessor(style: constrained).process(html: html).first)
                let renderer = try XCTUnwrap(chunk.textRender as? GMarkMarkedTextRenderer)
                let markedLength = (chunk.attributedText.string as NSString).range(of: "\n").location
                var expectedYs: Set<CGFloat> = []
                var offset = 0
                while offset < markedLength {
                    var lineRange = NSRange()
                    let line = renderer.lineFragmentUsedRectForCharacter(at: UInt(offset), effectiveRange: &lineRange)
                    expectedYs.insert(line.maxY + 2)
                    XCTAssertGreaterThan(NSMaxRange(lineRange), offset)
                    offset = NSMaxRange(lineRange)
                }
                XCTAssertFalse(renderer.markLines.isEmpty)
                XCTAssertEqual(Set(renderer.markLines.map(\.minY)), expectedYs)
            }
        }
    }

    func testMarkGeometryFitsVeryNarrowContainersAndBlankMarks() throws {
        for width: CGFloat in [1, 8, 16, 80] {
            for content in ["😀", "&nbsp;&nbsp;&nbsp;"] {
                var constrained = style
                constrained.maxContainerWidth = width
                let chunk = try XCTUnwrap(GMarkHTMLProcessor(style: constrained).process(html:
                    "<p style='font-size:72px'><CustomClickableSpan>\(content)</CustomClickableSpan></p>").first)
                let renderer = try XCTUnwrap(chunk.textRender as? GMarkMarkedTextRenderer)
                XCTAssertFalse(renderer.markLines.isEmpty)
                for line in renderer.markLines {
                    XCTAssertGreaterThanOrEqual(line.minX, 0)
                    XCTAssertLessThanOrEqual(line.maxX, width)
                    XCTAssertLessThanOrEqual(line.maxY, chunk.itemSize.height)
                }
            }
        }
    }

    func testRepeatedDynamicTypeKeepsBaseTextAndAcceptsReplacement() throws {
        let chunk = try XCTUnwrap(GMarkHTMLProcessor(style: style).process(html:
            "<p><CustomClickableSpan>中文😀</CustomClickableSpan></p>").first)
        let source = chunk.attributedText
        let large = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        func rescale(_ traits: UITraitCollection) {
            var nextStyle = chunk.style
            nextStyle.fonts = DynamicTypeFontStyle(base: nextStyle.fonts, compatibleWith: traits)
            chunk.applyDynamicType(style: nextStyle, baseAttributedText: chunk.unscaledAttributedText,
                                   baseTable: nil, baseAttachmentSizes: [], baseTableAttachmentSizes: nil,
                                   compatibleWith: traits)
        }
        rescale(large)
        let firstSize = chunk.itemSize
        let firstFont = try XCTUnwrap(chunk.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        for _ in 0..<3 { rescale(large) }
        XCTAssertEqual(chunk.itemSize, firstSize)
        XCTAssertEqual((chunk.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, firstFont.pointSize)
        XCTAssertTrue(chunk.unscaledAttributedText.isEqual(to: source))
        XCTAssertEqual(chunk.style.fonts.current.pointSize, firstFont.pointSize)
        rescale(UITraitCollection(preferredContentSizeCategory: .large))
        XCTAssertEqual((chunk.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 18)

        let replacement = NSMutableAttributedString(attributedString: source)
        replacement.addAttributes([.font: UIFont.systemFont(ofSize: 24), .foregroundColor: UIColor.red],
                                  range: NSRange(location: 0, length: replacement.length))
        chunk.attributedText = replacement
        rescale(UITraitCollection(preferredContentSizeCategory: .large))
        XCTAssertEqual((chunk.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 24)
        XCTAssertEqual(chunk.attributedText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
    }

    func testAllowedTextStructureIsReadableWithoutAttributes() {
        let source = #"<div class="ignored"><strong>粗体</strong><br><em>斜体</em><ul><li>第一项</li><li>第二项</li></ul><blockquote>引用</blockquote></div>"#
        let result = GMarkHTMLSanitizer.attributedString(from: source, style: style)

        XCTAssertTrue(result.string.contains("粗体\n斜体"))
        XCTAssertTrue(result.string.contains("• 第一项\n• 第二项"))
        XCTAssertTrue(result.string.contains("引用"))
        XCTAssertFalse(result.string.contains("class="))
    }

    func testDangerousContainersLinksAndImagesCannotCarryExecutableOrNavigationData() {
        let source = #"安全<script>alert('不能执行')</script><iframe src="https://evil.example">不能显示</iframe><img src="https://evil.example/pixel" alt="图片替代文字"><a href="https://evil.example">仅保留链接文字</a>结束"#
        let result = GMarkHTMLSanitizer.attributedString(from: source, style: style)

        XCTAssertEqual(result.string, "安全图片替代文字仅保留链接文字结束")
        XCTAssertFalse(result.string.contains("alert"))
        XCTAssertFalse(result.string.contains("不能显示"))
        XCTAssertFalse(result.string.contains("evil.example"))
        XCTAssertNil(result.attribute(.link, at: 0, effectiveRange: nil))
    }

    func testInlineDangerousContainerSuppressesItsMarkdownTextUntilClosingTag() {
        var state = GMarkHTMLSanitizer.InlineState()
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("<script>", to: &state, style: style))
        XCTAssertTrue(state.isIgnoringContent)
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("</script>", to: &state, style: style))
        XCTAssertFalse(state.isIgnoringContent)
    }

    func testEmptyListItemsAndNestedContent() {
        let source = #"<ul><li></li><li><span>  </span><br></li><li><img alt=""></li><li><img alt="图片"></li><li><ul><li></li></ul></li><li>正文</li></ul>"#
        let result = GMarkHTMLSanitizer.attributedString(from: source, style: style)

        XCTAssertEqual(result.string, "• 图片\n• 正文\n")
    }

    func testEditorTextStylesAndBlockOnlySpacing() {
        let source = #"<p style="font-size:18px;margin-bottom:12px"><span style="font-weight:bold;color:#4F5CE7;margin-bottom:90px">标题</span><span style="font-style:italic">文字</span></p>"#
        let result = GMarkHTMLSanitizer.attributedString(from: source, style: style)

        XCTAssertEqual(result.string, "标题文字\n")
        let firstFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(firstFont?.pointSize, 18)
        XCTAssertTrue(firstFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        let secondFont = result.attribute(.font, at: 2, effectiveRange: nil) as? UIFont
        XCTAssertTrue(secondFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
        let paragraph = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(paragraph?.paragraphSpacing, 12)
        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, UIColor(red: 79 / 255, green: 92 / 255, blue: 231 / 255, alpha: 1))
    }

    func testUnstyledNestedTagDoesNotCloseOuterInlineStyle() {
        var state = GMarkHTMLSanitizer.InlineState()
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken(#"<span style="color:#4F5CE7">"#, to: &state, style: style))
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("<span>", to: &state, style: style))
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("</span>", to: &state, style: style))
        let inside = GMarkHTMLSanitizer.attributedText(from: "保留颜色", style: style, state: state)
        XCTAssertEqual(inside.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
                       UIColor(red: 79 / 255, green: 92 / 255, blue: 231 / 255, alpha: 1))
        XCTAssertNil(GMarkHTMLSanitizer.applyInlineToken("</span>", to: &state, style: style))
        XCTAssertFalse(state.isInHTMLContext)
    }
}
