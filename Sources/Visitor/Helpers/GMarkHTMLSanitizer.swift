//
//  GMarkHTMLSanitizer.swift
//  GMarkdown
//
//  Display-only HTML subset. Only text styles used by editor-generated content
//  are interpreted; URLs are never emitted and embedded/executable containers
//  are removed with their contents.
//

import Foundation
import UIKit

struct GMarkHTMLSanitizer {
    fileprivate struct TextStyle {
        var fontSize: CGFloat?
        var color: UIColor?
        var bold: Bool?
        var italic: Bool?
        var paragraphSpacing: CGFloat?
    }

    fileprivate struct StyleFrame {
        let tag: String
        let style: TextStyle
        let hasStyle: Bool
    }

    struct InlineState {
        fileprivate var ignoredDepth = 0
        fileprivate var boldDepth = 0
        fileprivate var italicDepth = 0
        fileprivate var underlineDepth = 0
        fileprivate var strikeDepth = 0
        fileprivate var superscriptDepth = 0
        fileprivate var subscriptDepth = 0
        fileprivate var codeDepth = 0
        fileprivate var styleFrames: [StyleFrame] = []

        var isIgnoringContent: Bool { ignoredDepth > 0 }
        var isInHTMLContext: Bool { styleFrames.contains { $0.hasStyle } }

        fileprivate func currentStyle() -> TextStyle {
            var value = TextStyle()
            for frame in styleFrames {
                let next = frame.style
                if let fontSize = next.fontSize { value.fontSize = fontSize }
                if let color = next.color { value.color = color }
                if let bold = next.bold { value.bold = bold }
                if let italic = next.italic { value.italic = italic }
                if let spacing = next.paragraphSpacing { value.paragraphSpacing = spacing }
            }
            return value
        }
    }

    private enum TokenAction {
        case none
        case lineBreak
        case listItem
        case listItemEnd
        case imageFallback(String)
    }

    private static let discardedContainers: Set<String> = [
        "script", "style", "iframe", "object", "embed", "form", "video", "audio", "svg", "math", "template"
    ]
    private static let voidTags: Set<String> = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"]

    static func attributedString(from rawHTML: String,
                                 style: Style,
                                 onImageFallback: ((Bool) -> Void)? = nil) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        var state = InlineState()
        var listItemStarts: [(start: Int, hasContent: Bool)] = []
        var textStart = rawHTML.startIndex
        var index = rawHTML.startIndex

        func appendText(_ text: String) {
            guard !state.isIgnoringContent, !text.isEmpty else { return }
            let decoded = decodeEntities(in: text)
            // HTML indentation/newline-only nodes are formatting, not readable
            // content. Dropping them prevents source indentation from becoming
            // large visual gaps after paragraph styling is applied.
            guard !decoded.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else { return }
            result.append(attributedText(from: decoded, style: style, state: state, htmlMode: true))
            for item in listItemStarts.indices { listItemStarts[item].hasContent = true }
        }

        while index < rawHTML.endIndex {
            guard rawHTML[index] == "<" else {
                index = rawHTML.index(after: index)
                continue
            }

            guard let tagEnd = endOfTag(startingAt: index, in: rawHTML) else {
                index = rawHTML.index(after: index)
                continue
            }
            appendText(String(rawHTML[textStart..<index]))

            let token = String(rawHTML[index...tagEnd])
            switch apply(token: token, to: &state) {
            case .lineBreak:
                appendLineBreak(to: result)
            case .listItem:
                let start = result.length
                appendLineBreak(to: result)
                if !state.isIgnoringContent {
                    result.append(attributedText(from: "• ", style: style, state: state, htmlMode: true))
                    listItemStarts.append((start, false))
                }
            case .listItemEnd:
                if let item = listItemStarts.popLast() {
                    if !item.hasContent {
                        result.deleteCharacters(in: NSRange(location: item.start, length: result.length - item.start))
                        break
                    }
                }
                appendLineBreak(to: result)
            case let .imageFallback(alt):
                onImageFallback?(!alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                guard !state.isIgnoringContent, !alt.isEmpty else { break }
                let decodedAlt = decodeEntities(in: alt)
                result.append(attributedText(from: decodedAlt, style: style, state: state, htmlMode: true))
                if !decodedAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    for item in listItemStarts.indices { listItemStarts[item].hasContent = true }
                }
            case .none:
                break
            }

            index = rawHTML.index(after: tagEnd)
            textStart = index
        }
        appendText(String(rawHTML[textStart...]))
        return result
    }

    /// Applies one InlineHTML token to the visitor state. The caller renders
    /// ordinary Markdown Text only while `isIgnoringContent` is false.
    static func applyInlineToken(_ rawHTML: String,
                                 to state: inout InlineState,
                                 style: Style,
                                 onImageFallback: ((Bool) -> Void)? = nil) -> NSAttributedString? {
        let action = apply(token: rawHTML, to: &state)
        switch action {
        case .none:
            return nil
        case .lineBreak:
            return NSAttributedString.singleNewline(withStyle: style)
        case .listItem:
            return attributedText(from: "• ", style: style, state: state)
        case .listItemEnd:
            return NSAttributedString.singleNewline(withStyle: style)
        case let .imageFallback(alt):
            onImageFallback?(!alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            return attributedText(from: decodeEntities(in: alt), style: style, state: state)
        }
    }

    static func attributedText(from text: String, style: Style, state: InlineState, htmlMode: Bool = false) -> NSMutableAttributedString {
        let result = MarkdownStyleProcessor.buildDefaultAttributedString(from: text, style: style)
        guard result.length > 0 else { return result }

        let textStyle = state.currentStyle()
        let isHTML = htmlMode || state.isInHTMLContext
        if isHTML {
            // Markdown's default 16pt paragraph spacing belongs to Markdown
            // blocks, not to HTML list rows or editor-controlled paragraphs.
            let paragraph = (result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?
                .mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            paragraph.paragraphSpacing = textStyle.paragraphSpacing ?? 0
            if let fontSize = textStyle.fontSize {
                paragraph.lineSpacing = max(0, 25 - fontSize)
                let font = (result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont ?? style.fonts.current)
                    .withSize(fontSize)
                result.addAttribute(.font, value: font)
            }
            result.addAttribute(.paragraphStyle, value: paragraph)
            if let color = textStyle.color { result.addAttribute(.foregroundColor, value: color) }
        }

        if state.boldDepth > 0 || textStyle.bold == true { MarkdownStyleProcessor.applyBoldFont(to: result) }
        if state.italicDepth > 0 || textStyle.italic == true { MarkdownStyleProcessor.applyItalicFont(to: result) }
        if state.underlineDepth > 0 {
            result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
        }
        if state.strikeDepth > 0 {
            result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
        }
        if state.codeDepth > 0 {
            result.addAttribute(.font, value: style.codeBlockStyle.font)
            result.addAttribute(.foregroundColor, value: style.codeBlockStyle.foregroundColor)
        }
        if state.superscriptDepth > 0 || state.subscriptDepth > 0 {
            let offset = state.superscriptDepth > 0 ? style.fonts.current.pointSize * 0.3 : -style.fonts.current.pointSize * 0.2
            result.addAttribute(.baselineOffset, value: offset)
            result.addAttribute(.font, value: style.fonts.current.withSize(style.fonts.current.pointSize * 0.75))
        }
        return result
    }

    private static func apply(token: String, to state: inout InlineState) -> TokenAction {
        guard let tag = parseTag(token) else { return .none }
        let name = tag.name

        if discardedContainers.contains(name) {
            if tag.isClosing {
                state.ignoredDepth = max(0, state.ignoredDepth - 1)
            } else if !tag.isSelfClosing {
                state.ignoredDepth += 1
            }
            return .none
        }

        if state.isIgnoringContent { return .none }
        if name == "img", !tag.isClosing {
            return .imageFallback(attribute(named: "alt", in: tag.attributes) ?? "")
        }

        if tag.isClosing {
            if let index = state.styleFrames.lastIndex(where: { $0.tag == name }) {
                state.styleFrames.remove(at: index)
            }
        } else if !tag.isSelfClosing && !voidTags.contains(name) {
            let rawStyle = attribute(named: "style", in: tag.attributes)
            let isBlock = name == "p" || name == "div" || name == "blockquote" || name == "li"
            state.styleFrames.append(StyleFrame(tag: name,
                                                style: rawStyle.map { parseTextStyle($0, allowsParagraphSpacing: isBlock) } ?? TextStyle(),
                                                hasStyle: rawStyle != nil))
        }

        switch name {
        case "br":
            return .lineBreak
        case "p", "div", "blockquote":
            return tag.isClosing ? .lineBreak : .none
        case "li":
            return tag.isClosing ? .listItemEnd : .listItem
        case "strong", "b":
            update(&state.boldDepth, closing: tag.isClosing)
        case "em", "i":
            update(&state.italicDepth, closing: tag.isClosing)
        case "u":
            update(&state.underlineDepth, closing: tag.isClosing)
        case "s", "del":
            update(&state.strikeDepth, closing: tag.isClosing)
        case "sup":
            update(&state.superscriptDepth, closing: tag.isClosing)
        case "sub":
            update(&state.subscriptDepth, closing: tag.isClosing)
        case "code", "pre":
            update(&state.codeDepth, closing: tag.isClosing)
        default:
            break // Unknown tags, including <a>, retain only their readable text.
        }
        return .none
    }

    private static func update(_ depth: inout Int, closing: Bool) {
        depth = closing ? max(0, depth - 1) : depth + 1
    }

    private static func appendLineBreak(to result: NSMutableAttributedString) {
        guard result.length > 0 else { return }
        let lastCharacter = result.attributedSubstring(from: NSRange(location: result.length - 1, length: 1)).string
        guard lastCharacter != "\n" else { return }
        result.append(NSAttributedString(string: "\n"))
    }

    private static func endOfTag(startingAt start: String.Index, in source: String) -> String.Index? {
        var index = source.index(after: start)
        var quote: Character?
        while index < source.endIndex {
            let character = source[index]
            if let activeQuote = quote {
                if character == activeQuote { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return index
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func parseTag(_ token: String) -> (name: String, attributes: String, isClosing: Bool, isSelfClosing: Bool)? {
        guard token.hasPrefix("<"), token.hasSuffix(">") else { return nil }
        let inner = String(token.dropFirst().dropLast())
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !inner.hasPrefix("!") && !inner.hasPrefix("?") else { return nil }

        let isClosing = inner.hasPrefix("/")
        let bodyStart = isClosing ? inner.index(after: inner.startIndex) : inner.startIndex
        let body = String(inner[bodyStart...])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard let end = body.firstIndex(where: { $0.isWhitespace || $0 == "/" }) else {
            let name = body.lowercased()
            return (name, "", isClosing, body.hasSuffix("/"))
        }
        let name = String(body[..<end]).lowercased()
        guard name.range(of: #"^[a-z][a-z0-9-]*$"#, options: String.CompareOptions.regularExpression) != nil else { return nil }
        let attributes = String(body[end...])
        return (name, attributes, isClosing, attributes.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).hasSuffix("/"))
    }

    private static func attribute(named name: String, in attributes: String) -> String? {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: attributes, range: NSRange(attributes.startIndex..., in: attributes)) else {
            return nil
        }
        for index in 1...3 where match.range(at: index).location != NSNotFound {
            return String(attributes[Range(match.range(at: index), in: attributes)!])
        }
        return nil
    }

    private static func parseTextStyle(_ raw: String, allowsParagraphSpacing: Bool) -> TextStyle {
        var style = TextStyle()
        for declaration in raw.split(separator: ";") {
            guard let separator = declaration.firstIndex(of: ":") else { continue }
            let name = declaration[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = declaration[declaration.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch name {
            case "font-size":
                if let size = pixelValue(value), (8...72).contains(size) { style.fontSize = size }
            case "color":
                style.color = hexColor(value)
            case "font-weight":
                if value == "bold" || value == "bolder" || (Int(value) ?? 0) >= 600 {
                    style.bold = true
                } else if value == "normal" || value == "400" { style.bold = false }
            case "font-style":
                if value == "italic" || value == "oblique" { style.italic = true }
                else if value == "normal" { style.italic = false }
            case "margin-bottom":
                if allowsParagraphSpacing, let spacing = pixelValue(value), (0...100).contains(spacing) {
                    style.paragraphSpacing = spacing
                }
            case "margin":
                guard allowsParagraphSpacing else { continue }
                let parts = value.split(whereSeparator: \.isWhitespace)
                guard !parts.isEmpty else { continue }
                let bottom = parts.count == 1 ? parts[0] : parts.count >= 3 ? parts[2] : parts[0]
                if let spacing = pixelValue(String(bottom)), (0...100).contains(spacing) {
                    style.paragraphSpacing = spacing
                }
            default:
                break
            }
        }
        return style
    }

    private static func pixelValue(_ value: String) -> CGFloat? {
        guard value.hasSuffix("px"), let number = Double(value.dropLast(2)), number.isFinite else { return nil }
        return CGFloat(number)
    }

    private static func hexColor(_ value: String) -> UIColor? {
        guard value.hasPrefix("#") else { return nil }
        let hex = String(value.dropFirst())
        guard hex.count == 3 || hex.count == 6,
              hex.allSatisfy({ $0.isHexDigit }),
              let number = UInt32(hex, radix: 16) else { return nil }
        let red: UInt32
        let green: UInt32
        let blue: UInt32
        if hex.count == 3 {
            red = ((number >> 8) & 0xF) * 17
            green = ((number >> 4) & 0xF) * 17
            blue = (number & 0xF) * 17
        } else {
            red = (number >> 16) & 0xFF
            green = (number >> 8) & 0xFF
            blue = number & 0xFF
        }
        return UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255,
                       blue: CGFloat(blue) / 255, alpha: 1)
    }

    private static func decodeEntities(in text: String) -> String {
        text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
