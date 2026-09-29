//
//  GMarkHTMLSanitizer.swift
//  GMarkdown
//
//  The first-release HTML policy is intentionally display-only. This is not an
//  HTML renderer: attributes are never interpreted, URLs are never emitted and
//  embedded/executable containers are removed with their contents.
//

import Foundation
import UIKit

struct GMarkHTMLSanitizer {
    struct InlineState {
        fileprivate var ignoredDepth = 0
        fileprivate var boldDepth = 0
        fileprivate var italicDepth = 0
        fileprivate var underlineDepth = 0
        fileprivate var strikeDepth = 0
        fileprivate var superscriptDepth = 0
        fileprivate var subscriptDepth = 0
        fileprivate var codeDepth = 0

        var isIgnoringContent: Bool { ignoredDepth > 0 }
    }

    private enum TokenAction {
        case none
        case lineBreak
        case listItem
        case imageFallback(String)
    }

    private static let discardedContainers: Set<String> = [
        "script", "style", "iframe", "object", "embed", "form", "video", "audio", "svg", "math", "template"
    ]

    static func attributedString(from rawHTML: String,
                                 style: Style,
                                 onImageFallback: ((Bool) -> Void)? = nil) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        var state = InlineState()
        var textStart = rawHTML.startIndex
        var index = rawHTML.startIndex

        func appendText(_ text: String) {
            guard !state.isIgnoringContent, !text.isEmpty else { return }
            let decoded = decodeEntities(in: text)
            // HTML indentation/newline-only nodes are formatting, not readable
            // content. Dropping them prevents source indentation from becoming
            // large visual gaps after paragraph styling is applied.
            guard !decoded.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else { return }
            result.append(attributedText(from: decoded, style: style, state: state))
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
                appendLineBreak(to: result)
                if !state.isIgnoringContent {
                    result.append(attributedText(from: "• ", style: style, state: state))
                }
            case let .imageFallback(alt):
                onImageFallback?(!alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                guard !state.isIgnoringContent, !alt.isEmpty else { break }
                result.append(attributedText(from: decodeEntities(in: alt), style: style, state: state))
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
        case let .imageFallback(alt):
            onImageFallback?(!alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            return attributedText(from: decodeEntities(in: alt), style: style, state: state)
        }
    }

    static func attributedText(from text: String, style: Style, state: InlineState) -> NSMutableAttributedString {
        let result = MarkdownStyleProcessor.buildDefaultAttributedString(from: text, style: style)
        guard result.length > 0 else { return result }

        if state.boldDepth > 0 { MarkdownStyleProcessor.applyBoldFont(to: result) }
        if state.italicDepth > 0 { MarkdownStyleProcessor.applyItalicFont(to: result) }
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

        switch name {
        case "br":
            return .lineBreak
        case "p", "div", "blockquote":
            return tag.isClosing ? .lineBreak : .none
        case "li":
            return tag.isClosing ? .lineBreak : .listItem
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
        guard result.length > 0, !result.string.hasSuffix("\n") else { return }
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

    private static func decodeEntities(in text: String) -> String {
        text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
