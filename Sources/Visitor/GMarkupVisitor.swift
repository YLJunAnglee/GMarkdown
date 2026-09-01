//
//  GMarkupVisitor.swift
//  GMarkRender
//
//  Created by GIKI on 2024/7/25.
//

import Markdown
import UIKit
#if canImport(MPITextKit)
import MPITextKit
#endif
import SwiftMath

public struct GMarkupVisitor: MarkupVisitor {
    
    // MARK: - Properties
    
    public var ignoreLatex: Bool = false
    public var beginLatex: Bool = false
    public var beginSupTag: Bool = false
    /// Number of LaTeX fragments that fell back to plain text during this visit.
    public private(set) var latexFailureCount: Int = 0
    /// Time spent in the LaTeX renderer during this visit.
    public private(set) var latexRenderDuration: TimeInterval = 0
    /// Sanitized per-formula outcomes produced by an injected renderer.
    public private(set) var formulaDiagnostics: [GMarkFormulaDiagnostic] = []
    
    private let style: Style
    private let formulaRenderer: (any GMarkFormulaRendering)?
    private let formulaCellLocation: GMarkFormulaCellLocation?
    private let formulaTraitCollection: UITraitCollection
    private let formulaDisplayScale: CGFloat
    private var nextFormulaOrdinal: Int
    public var referLoader: ReferLoader?
    public var imageLoader: ImageLoader?
     
    public init(style: Style) {
        self.style = style
        formulaRenderer = nil
        formulaCellLocation = nil
        formulaTraitCollection = .current
        formulaDisplayScale = UIScreen.main.scale
        nextFormulaOrdinal = 0
    }

    init(
        style: Style,
        formulaRenderer: any GMarkFormulaRendering,
        formulaCellLocation: GMarkFormulaCellLocation,
        startingFormulaOrdinal: Int,
        traitCollection: UITraitCollection,
        displayScale: CGFloat
    ) {
        self.style = style
        self.formulaRenderer = formulaRenderer
        self.formulaCellLocation = formulaCellLocation
        formulaTraitCollection = traitCollection
        formulaDisplayScale = displayScale
        nextFormulaOrdinal = startingFormulaOrdinal
    }
    
    public typealias Result = NSAttributedString
    
    // MARK: - MarkupVisitor Protocol Implementation (不可修改)
    
    public mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }
    
    public mutating func visitText(_ text: Text) -> NSAttributedString {
        if beginLatex {
            return processLatexText(text)
        }
        
        if beginSupTag {
            return processSupTagText(text)
        }
        
        return createDefaultAttributedString(from: text.plainText)
    }
    
    public mutating func visitImage(_ image: Image) -> NSAttributedString {
        guard style.useMPTextKit, let source = image.source else {
            return NSMutableAttributedString(string: "")
        }
        return processImageElement(source: source)
    }
    
    public mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let attributedString = processMarkupChildren(emphasis)
        MarkdownStyleProcessor.applyItalicFont(to: attributedString)
        return attributedString
    }
    
    public mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
        let attributedString = processMarkupChildren(strong)
        MarkdownStyleProcessor.applyBoldFont(to: attributedString)
        return attributedString
    }
    
    public mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let attributedString = processMarkupChildren(paragraph)
        MarkdownStyleProcessor.appendSplitBreakIfNeeded(for: paragraph, to: attributedString, style: style)
        return attributedString
    }
    
    public mutating func visitHeading(_ heading: Heading) -> NSAttributedString {
        let attributedString = processMarkupChildren(heading)
        MarkdownStyleProcessor.applyHeadingStyle(to: attributedString, heading: heading, style: style)
        MarkdownStyleProcessor.appendSplitBreakIfNeeded(for: heading, to: attributedString, style: style)
        return attributedString
    }
    
    public mutating func visitLink(_ link: Link) -> NSAttributedString {
        let attributedString = processMarkupChildren(link)
        MarkdownStyleProcessor.applyLinkStyle(to: attributedString,
                                              destination: link.destination,
                                              linkColor: style.colors.link,
                                              useMPTextKit: style.useMPTextKit)
        return attributedString
    }
    
    public mutating func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        let attributedString = createDefaultAttributedString(from: inlineCode.code)
        MarkdownStyleProcessor.applyInlineCodeStyle(to: attributedString, style: style)
        return attributedString
    }
    
    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        return processCodeBlock(codeBlock)
    }
    
    public mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let attributedString = processMarkupChildren(strikethrough)
        attributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
        return attributedString
    }
    
    public mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        var visitor: any MarkupVisitor = self
        let result = MarkdownListProcessor.processUnorderedList(
            unorderedList,
            style: style,
            visitor: &visitor
        )
        MarkdownStyleProcessor.appendSplitBreakIfNeeded(for: unorderedList, to: result, style: style)
        return result
    }
    
    public mutating func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        var visitor: any MarkupVisitor = self
        let result = MarkdownListProcessor.processOrderedList(
            orderedList,
            style: style,
            visitor: &visitor
        )
        MarkdownStyleProcessor.appendSplitBreakIfNeeded(for: orderedList, to: result, style: style)
        return result
    }

    public mutating func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        let attributedString = processMarkupChildren(listItem)
        MarkdownStyleProcessor.appendSplitBreakIfNeeded(for: listItem, to: attributedString, style: style)
        return attributedString
    }
    
    public mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        let attributedString = MarkdownBlockQuoteProcessor.processBlockQuote(blockQuote,style: style, visitor:self)
        MarkdownStyleProcessor.appendSplitBreakIfNeeded(for: blockQuote, to: attributedString, style: style)
        return attributedString
    }
    
    public mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> Result {
        return processInlineHTML(inlineHTML)
    }
    
    public mutating func visitHTMLBlock(_ html: HTMLBlock) -> Result {
        return processHTMLBlock(html)
    }
    
    public mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSAttributedString {
        return createDefaultAttributedString(from: lineBreak.plainText)
    }
    
    public mutating func visitSoftBreak(_: SoftBreak) -> NSAttributedString {
        return NSAttributedString.singleNewline(withStyle: style)
    }
}

// MARK: - Child Processing
extension GMarkupVisitor {
    
    private mutating func processMarkupChildren(_ markup: Markup) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }
}

// MARK: - Text Processing
extension GMarkupVisitor {
    
    private mutating func processLatexText(_ text: Text) -> NSAttributedString {
        guard let formulaRenderer, let formulaCellLocation else {
            return processLatexTextWithLegacyRenderer(text)
        }

        let ordinal = nextFormulaOrdinal
        nextFormulaOrdinal += 1
        let request = GMarkFormulaRenderRequest(
            latex: GMarkLaTexRender.trimBrackets(from: text.plainText),
            container: .tableCell,
            font: style.fonts.current,
            textColor: style.colors.current,
            maximumWidth: max(0, style.maxContainerWidth - 40),
            displayScale: formulaDisplayScale,
            traitCollection: formulaTraitCollection
        )
        let start = ProcessInfo.processInfo.systemUptime
        let renderResult = formulaRenderer.renderFormula(request)
        let duration = ProcessInfo.processInfo.systemUptime - start
        latexRenderDuration += duration

        switch renderResult {
        case let .success(image, intrinsicSize, backendRevision):
            guard image.size.width.isFinite,
                  image.size.height.isFinite,
                  image.size.width > 0,
                  image.size.height > 0 else {
                recordFormulaFallback(
                    reasonCode: .invalidImageSize,
                    backendRevision: backendRevision,
                    ordinal: ordinal,
                    location: formulaCellLocation,
                    duration: duration
                )
                return createDefaultAttributedString(from: text.plainText)
            }
            guard intrinsicSize.width.isFinite,
                  intrinsicSize.height.isFinite,
                  intrinsicSize.width > 0,
                  intrinsicSize.height > 0 else {
                recordFormulaFallback(
                    reasonCode: .invalidIntrinsicSize,
                    backendRevision: backendRevision,
                    ordinal: ordinal,
                    location: formulaCellLocation,
                    duration: duration
                )
                return createDefaultAttributedString(from: text.plainText)
            }
            formulaDiagnostics.append(GMarkFormulaDiagnostic(
                ordinal: ordinal,
                row: formulaCellLocation.row,
                column: formulaCellLocation.column,
                isHeader: formulaCellLocation.isHeader,
                container: .tableCell,
                reasonCode: nil,
                backendRevision: backendRevision,
                duration: duration
            ))
            return createLatexImageAttributedString(image: image, intrinsicSize: intrinsicSize)
        case let .fallback(reasonCode, backendRevision):
            recordFormulaFallback(
                reasonCode: reasonCode,
                backendRevision: backendRevision,
                ordinal: ordinal,
                location: formulaCellLocation,
                duration: duration
            )
            return createDefaultAttributedString(from: text.plainText)
        }
    }

    private mutating func processLatexTextWithLegacyRenderer(_ text: Text) -> NSAttributedString {
        let start = ProcessInfo.processInfo.systemUptime
        let renderResult = GMarkLaTexRender.renderLatexSmart(from: text.plainText, style: style)
        latexRenderDuration += ProcessInfo.processInfo.systemUptime - start

        if renderResult.success, let image = renderResult.image {
            return createLatexImageAttributedString(image: image, intrinsicSize: nil)
        } else {
            latexFailureCount += 1
            return createDefaultAttributedString(from: text.plainText)
        }
    }

    private mutating func recordFormulaFallback(
        reasonCode: GMarkFormulaFallbackReasonCode,
        backendRevision: GMarkFormulaBackendRevision,
        ordinal: Int,
        location: GMarkFormulaCellLocation,
        duration: TimeInterval
    ) {
        latexFailureCount += 1
        formulaDiagnostics.append(GMarkFormulaDiagnostic(
            ordinal: ordinal,
            row: location.row,
            column: location.column,
            isHeader: location.isHeader,
            container: .tableCell,
            reasonCode: reasonCode,
            backendRevision: backendRevision,
            duration: duration
        ))
    }
    
    private mutating func processSupTagText(_ text: Text) -> NSAttributedString {
        guard let referLoader = referLoader,
              let link = referLoader.referQuoteLink(from: text.plainText),
              let webSite = referLoader.referQuoteWebSite(from: text.plainText),
              !webSite.isEmpty else {
            return createDefaultAttributedString(from: "")
        }
        
        return createSupTagAttributedString(webSite: webSite, link: link)
    }
    
    private mutating func createLatexImageAttributedString(
        image: UIImage,
        intrinsicSize: CGSize?
    ) -> NSAttributedString {
        let resizedImage: UIImage
        let attachmentSize: CGSize
        if let intrinsicSize {
            resizedImage = image
            attachmentSize = fittedLatexSize(intrinsicSize)
        } else {
            resizedImage = image.resized(toMaxWidth: style.maxContainerWidth - 40)
            attachmentSize = resizedImage.size
        }
        let result = NSMutableAttributedString(string: "")
        
        if style.useMPTextKit {
            let attachment = MPITextAttachment()
            attachment.content = resizedImage
            attachment.contentSize = attachmentSize
            attachment.contentMode = .left
            attachment.verticalAligment = .center
            let attrString = NSMutableAttributedString(attachment: attachment)
            applyLatexImageStyle(to: attrString)
            result.append(attrString)
        } else {
            let attachment = NSTextAttachment()
            attachment.image = resizedImage
            attachment.bounds = CGRect(origin: .zero, size: attachmentSize)
            let attrString = NSMutableAttributedString(attachment: attachment)
            applyLatexImageStyle(to: attrString)
            result.append(attrString)
        }
        
        return result
    }

    private func fittedLatexSize(_ intrinsicSize: CGSize) -> CGSize {
        let maximumWidth = max(0, style.maxContainerWidth - 40)
        guard maximumWidth > 0, intrinsicSize.width > maximumWidth else { return intrinsicSize }
        let scale = maximumWidth / intrinsicSize.width
        return CGSize(width: maximumWidth, height: intrinsicSize.height * scale)
    }
    
    private func applyLatexImageStyle(to attrString: NSMutableAttributedString) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 25 - style.fonts.current.pointSize
        paragraphStyle.paragraphSpacing = 16
        attrString.addAttribute(.paragraphStyle, value: paragraphStyle)
        attrString.addAttribute(.font, value: style.fonts.current)
        attrString.addAttribute(.foregroundColor, value: style.colors.current)
    }
    
    private mutating func createSupTagAttributedString(webSite: String, link: String) -> NSAttributedString {
        let tagWidth = calculateSupTagWidth(for: webSite)
        let tagImage = Renderer().drawTagImage(
            text: webSite,
            font: style.fonts.quoteFont,
            width: tagWidth,
            height: 28,
            backgroundColor: style.colors.quoteBackground,
            textColor: style.colors.quoteForeground,
            cornerRadius: 14
        )
        
        guard let image = tagImage else {
            return createDefaultAttributedString(from: "")
        }
        
        let attachment = MPITextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -7, width: image.size.width, height: image.size.height)
        let attrString = NSMutableAttributedString(attachment: attachment)
        attrString.insert(NSAttributedString(string: " "), at: 0)
        
        if let url = URL(string: link) {
            let mpiLink = MPITextLink()
            mpiLink.value = url as any NSObjectProtocol
            attrString.addAttribute(.MPILink, value: mpiLink)
        }
        
        return attrString
    }
    
    private func calculateSupTagWidth(for text: String) -> CGFloat {
        let textWidth = (text as NSString).size(withAttributes: [.font: style.fonts.quoteFont]).width
        let padding: CGFloat = 12
        return min(textWidth + 18 + padding * 2, 180)
    }
}

// MARK: - Code Block Processing
extension GMarkupVisitor {
    
    private mutating func processCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let code = codeBlock.code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if style.codeBlockStyle.customRender {
            return renderCustomCodeBlock(code, language: codeBlock.language)
        }
        
        if style.codeBlockStyle.useHighlight {
            return renderHighlightedCodeBlock(code, language: codeBlock.language, hasSuccessor: codeBlock.hasSuccessorForSplit)
        }
        
        return renderPlainCodeBlock(code, hasSuccessor: codeBlock.hasSuccessorForSplit)
    }
    
    private mutating func renderCustomCodeBlock(_ code: String, language: String?) -> NSAttributedString {
        if style.codeBlockStyle.useHighlight {
            if let highlighted = GMarkCodeHighlight.shared.generateAttributeText(code, language: language ?? ""),
               !highlighted.string.hasPrefix("undefined") {
                let attributed = NSMutableAttributedString(attributedString: highlighted)
                attributed.addAttribute(.font, value: style.codeBlockStyle.font)
                return attributed
            }
        }
        
        let attributed = createDefaultAttributedString(from: code)
        attributed.addAttribute(.font, value: style.codeBlockStyle.font)
        attributed.addAttribute(.foregroundColor, value: style.codeBlockStyle.foregroundColor)
        return attributed
    }
    
    private mutating func renderHighlightedCodeBlock(_ code: String, language: String?, hasSuccessor: Bool) -> NSAttributedString {
        guard let highlighted = GMarkCodeHighlight.shared.generateAttributeText(code, language: language ?? ""),
              !highlighted.string.hasPrefix("undefined") else {
            return renderPlainCodeBlock(code, hasSuccessor: hasSuccessor)
        }
        
        let attributed = NSMutableAttributedString(string: "")
        attributed.append(.singleNewline(withStyle: style))
        attributed.append(highlighted)
        attributed.addAttribute(.font, value: style.codeBlockStyle.font)
        
        applyCodeBlockBackground(to: attributed)
        
        if hasSuccessor {
            attributed.append(.singleNewline(withStyle: style))
        }
        attributed.append(.singleNewline(withStyle: style))
        return attributed
    }
    
    private mutating func renderPlainCodeBlock(_ code: String, hasSuccessor: Bool) -> NSAttributedString {
        let attributed = createDefaultAttributedString(from: "\n\(code)")
        attributed.addAttribute(.font, value: style.codeBlockStyle.font)
        attributed.addAttribute(.foregroundColor, value: style.codeBlockStyle.foregroundColor)
        
        applyCodeBlockBackground(to: attributed)
        
        if hasSuccessor {
            attributed.append(.singleNewline(withStyle: style))
        }
        return attributed
    }
    
    private func applyCodeBlockBackground(to attributed: NSMutableAttributedString) {
        if style.useMPTextKit {
            let background = MPITextBackground(fill: style.codeBlockStyle.backgroundColor, cornerRadius: 4)
            attributed.addAttribute(.MPIBlockBackground, value: background)
        } else {
            attributed.addAttribute(.backgroundColor, value: style.codeBlockStyle.backgroundColor)
        }
    }
}

// MARK: - HTML Processing
extension GMarkupVisitor {
    
    private mutating func processInlineHTML(_ inlineHTML: InlineHTML) -> Result {
        if !ignoreLatex {
            switch inlineHTML.plainText {
            case "<LaTex>":
                beginLatex = true
            case "</LaTex>":
                beginLatex = false
            default:
                break
            }
        }
        
        switch inlineHTML.plainText {
        case "<br>":
            return .singleNewline(withStyle: style)
        case "<sup>":
            beginSupTag = true
            return defaultVisit(inlineHTML)
        case "</sup>":
            beginSupTag = false
            return defaultVisit(inlineHTML)
        default:
            return defaultVisit(inlineHTML)
        }
    }
    
    private mutating func processHTMLBlock(_ html: HTMLBlock) -> Result {
        return createDefaultAttributedString(from: html.rawHTML)
    }
}

// MARK: - Image Processing
extension GMarkupVisitor {
    
    private func processImageElement(source: String) -> NSAttributedString {
        if Thread.isMainThread {
            return createImageAttributedString(source: source)
        } else {
            let semaphore = DispatchSemaphore(value: 0)
            var resultString: NSAttributedString!
            DispatchQueue.main.async {
                resultString = self.createImageAttributedString(source: source)
                semaphore.signal()
            }
            
            semaphore.wait()
            return resultString
        }
    }
    
    private func createImageAttributedString(source: String) -> NSAttributedString {
        return MarkdownStyleProcessor.createImageAttributedString(
            source: source,
            style: style,
            imageLoader: imageLoader
        )
    }
}

// MARK: - Default Attribute Creation
extension GMarkupVisitor {
    
    public func buildAttributedText(from text: String) -> NSMutableAttributedString {
        createDefaultAttributedString(from: text)
    }
    
    private func createDefaultAttributedString(from text: String) -> NSMutableAttributedString {
        return MarkdownStyleProcessor.buildDefaultAttributedString(from: text, style: style)
    }
}


// MARK: - Renderer Helper

private struct Renderer {
    
    func drawTagImage(text: String, font: UIFont, width: CGFloat, height: CGFloat, backgroundColor: UIColor, textColor: UIColor, cornerRadius: CGFloat) -> UIImage? {
        let size = CGSize(width: width, height: height)
        let iconName = "detail_quote_ic"
        let iconSize = CGSize(width: 16, height: 16)
        let iconTextSpacing: CGFloat = 2
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Draw background
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            backgroundColor.setFill()
            path.fill()
            
            // Draw icon
            if let icon = UIImage(named: iconName) {
                let iconY = (size.height - iconSize.height) / 2
                let iconRect = CGRect(x: 10, y: iconY, width: iconSize.width, height: iconSize.height)
                icon.draw(in: iconRect)
            }
            
            // Draw text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail
            paragraphStyle.alignment = .left
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
            
            let textX: CGFloat = 10 + iconSize.width + iconTextSpacing
            let availableWidth = size.width - textX - 10
            let textRect = CGRect(
                x: textX,
                y: (size.height - font.lineHeight) / 2,
                width: availableWidth,
                height: font.lineHeight
            )
            
            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }
}
