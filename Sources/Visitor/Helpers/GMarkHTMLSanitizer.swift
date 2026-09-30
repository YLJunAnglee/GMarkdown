import Foundation
import UIKit

public extension NSAttributedString.Key {
    /// String ID of a display-only mark. Ranges are UTF-16 offsets in this
    /// attributed string, not source HTML. IDs are local to a parse operation.
    static let gmarkCustomClickableSpan = NSAttributedString.Key("GMark.CustomClickableSpan")
}

/// Shared styles for editor HTML. Full documents use a bounded element tree
/// and paragraph assembly; Markdown InlineHTML uses scoped style frames.
struct GMarkHTMLSanitizer {
    fileprivate struct TextStyle {
        var fontSize: CGFloat?
        var color: UIColor?
        var bold: Bool?
        var italic: Bool?
        var paragraphSpacing: CGFloat?
        var underline = false
        var strike = false
        var superscript = false
        var subscriptText = false
        var code = false
        var mark: String?
        var direction: NSWritingDirection?
        var inlineDirections: [Int] = []
    }

    fileprivate struct Frame {
        let tag: String
        let style: TextStyle
        let hasExplicitStyle: Bool
    }

    struct InlineState {
        fileprivate var frames: [Frame] = []
        fileprivate var ignoredTag: String?
        fileprivate var markSequence = 0
        fileprivate let scope = UUID().uuidString
        var isIgnoringContent: Bool { ignoredTag != nil }
        // Preserve Markdown paragraph spacing for unstyled inline tags.
        // Complete HTML rendering explicitly opts into HTML paragraph rules.
        var isInHTMLContext: Bool { frames.contains { $0.hasExplicitStyle } }
        fileprivate var current: TextStyle { frames.last?.style ?? TextStyle() }
        fileprivate var paragraph: TextStyle {
            frames.last(where: { GMarkHTMLTokens.blocks.contains($0.tag) || GMarkHTMLTokens.contexts.contains($0.tag) })?.style ?? TextStyle()
        }

        fileprivate mutating func close(_ name: String) {
            if let index = frames.lastIndex(where: { $0.tag == name }) { frames.removeSubrange(index...) }
        }

        fileprivate mutating func push(_ tag: GMarkHTMLTokens.Tag, autoDirection: NSWritingDirection? = nil) {
            var value = current
            let block = GMarkHTMLTokens.blocks.contains(tag.name) || GMarkHTMLTokens.contexts.contains(tag.name)
            if block {
                value.paragraphSpacing = nil
                value.inlineDirections = []
                value.mark = nil
            }
            switch tag.name {
            case "strong", "b": value.bold = true
            case "em", "i": value.italic = true
            case "u": value.underline = true
            case "s", "del": value.strike = true
            case "sup": value.superscript = true; value.subscriptText = false
            case "sub": value.subscriptText = true; value.superscript = false
            case "code", "pre": value.code = true
            case "customclickablespan":
                if value.mark == nil {
                    markSequence += 1
                    value.mark = "\(scope)-\(markSequence)"
                }
            default: break
            }
            if let raw = tag.attributes["style"] {
                let css = parseTextStyle(raw, allowsParagraphSpacing: block)
                if let v = css.fontSize { value.fontSize = v }
                if let v = css.color { value.color = v }
                if let v = css.bold { value.bold = v }
                if let v = css.italic { value.italic = v }
                if let v = css.paragraphSpacing { value.paragraphSpacing = v }
            }
            let direction: NSWritingDirection?
            switch tag.attributes["dir"]?.lowercased() {
            case "ltr": direction = .leftToRight
            case "rtl": direction = .rightToLeft
            case "auto": direction = autoDirection
            default: direction = nil
            }
            if let direction {
                if block { value.direction = direction }
                else { value.inlineDirections.append(direction.rawValue | NSWritingDirectionFormatType.embedding.rawValue) }
            }
            frames.append(Frame(tag: tag.name, style: value, hasExplicitStyle: tag.attributes["style"] != nil))
        }
    }

    private final class Node {
        let tag: GMarkHTMLTokens.Tag?
        let text: String?
        var children: [Node] = []
        var firstStrong: NSWritingDirection?
        init(tag: GMarkHTMLTokens.Tag? = nil, text: String? = nil) {
            self.tag = tag
            self.text = text
        }

        func resolveDirection() {
            let visibleText = text ?? (tag?.name == "img" ? tag?.attributes["alt"] : nil)
            firstStrong = visibleText.flatMap { GMarkHTMLTokens.firstStrongDirection($0) }
            for child in children {
                child.resolveDirection()
                let dir = child.tag?.attributes["dir"]?.lowercased()
                if firstStrong == nil, dir != "ltr", dir != "rtl", dir != "auto" {
                    firstStrong = child.firstStrong
                }
            }
        }

        var hasVisibleContent: Bool {
            if let text { return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if tag?.name == "img" {
                return !(tag?.attributes["alt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return children.contains { $0.hasVisibleContent }
        }
    }

    private static func parse(_ html: String) -> Node {
        let root = Node()
        var stack = [root]
        GMarkHTMLTokens.scan(html) { token in
            switch token {
            case let .text(text):
                stack.last?.children.append(Node(text: GMarkHTMLTokens.decode(text)))
            case let .tag(tag):
                if GMarkHTMLTokens.discarded.contains(tag.name) { return }
                if tag.closing {
                    if let index = stack.lastIndex(where: { $0.tag?.name == tag.name }), index > 0 {
                        stack.removeSubrange(index...)
                    }
                    return
                }
                if GMarkHTMLTokens.blocks.contains(tag.name) {
                    // New blocks close unfinished inline scopes. Entering a nested
                    // list retains the enclosing list item.
                    if let p = stack.lastIndex(where: { $0.tag?.name == "p" }) { stack.removeSubrange(p...) }
                    if tag.name == "li",
                       let li = stack.lastIndex(where: { $0.tag?.name == "li" }),
                       !stack[(li + 1)...].contains(where: { ["ul", "ol"].contains($0.tag?.name ?? "") }) {
                        stack.removeSubrange(li...)
                    }
                    while stack.count > 1, let name = stack.last?.tag?.name,
                          !GMarkHTMLTokens.blocks.contains(name), !GMarkHTMLTokens.contexts.contains(name) {
                        stack.removeLast()
                    }
                }
                let node = Node(tag: tag)
                stack.last?.children.append(node)
                if !tag.selfClosing, !GMarkHTMLTokens.voids.contains(tag.name), stack.count < 128 { stack.append(node) }
            }
        }
        root.resolveDirection()
        return root
    }

    static func attributedString(from rawHTML: String, style: Style,
                                 onImageFallback: ((Bool) -> Void)? = nil) -> NSMutableAttributedString {
        let renderer = ParagraphRenderer(style: style, onImageFallback: onImageFallback)
        renderer.render(parse(rawHTML))
        return renderer.finish()
    }

    private final class ParagraphRenderer {
        let style: Style
        let onImageFallback: ((Bool) -> Void)?
        var state = InlineState()
        var result = NSMutableAttributedString(string: "")
        var paragraph = NSMutableAttributedString(string: "")
        var paragraphStyle = TextStyle()
        var pendingSpace: NSAttributedString?

        init(style: Style, onImageFallback: ((Bool) -> Void)?) {
            self.style = style
            self.onImageFallback = onImageFallback
        }

        func render(_ node: Node) {
            if let text = node.text { append(text); return }
            guard let tag = node.tag else { node.children.forEach(render); return }
            if tag.name == "img" {
                let alt = tag.attributes["alt"] ?? ""
                onImageFallback?(!alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                append(alt)
                return
            }
            if tag.name == "br" { flush(lineBreak: true); return }
            if tag.name == "li", !node.hasVisibleContent {
                reportImages(in: node)
                return
            }
            let block = GMarkHTMLTokens.blocks.contains(tag.name)
            if block { flush(lineBreak: true) }
            let depth = state.frames.count
            state.push(tag, autoDirection: node.firstStrong ?? .leftToRight)
            if tag.name == "li" { append("• ") }
            node.children.forEach(render)
            if block { flush(lineBreak: true) }
            state.frames.removeSubrange(depth...)
        }

        func reportImages(in node: Node) {
            guard onImageFallback != nil else { return }
            if node.tag?.name == "img" {
                onImageFallback?(!(node.tag?.attributes["alt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            node.children.forEach { reportImages(in: $0) }
        }

        func append(_ text: String) {
            var run = ""
            func emitRun() {
                guard !run.isEmpty else { return }
                if paragraph.length == 0 { paragraphStyle = state.paragraph }
                else if let space = pendingSpace { paragraph.append(space) }
                pendingSpace = nil
                paragraph.append(attributedText(from: run, style: style, state: state, htmlMode: true))
                run = ""
            }
            for c in text {
                if GMarkHTMLTokens.isSpace(c) {
                    emitRun()
                    if pendingSpace == nil {
                        pendingSpace = attributedText(from: " ", style: style, state: state, htmlMode: true)
                    }
                } else { run.append(c) }
            }
            emitRun()
        }

        func flush(lineBreak: Bool) {
            pendingSpace = nil
            guard paragraph.length > 0 else { return }
            let p = NSMutableParagraphStyle()
            p.paragraphSpacing = paragraphStyle.paragraphSpacing ?? 0
            let font = paragraph.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            p.lineSpacing = max(0, 25 - (paragraphStyle.fontSize ?? font?.pointSize ?? style.fonts.current.pointSize))
            p.baseWritingDirection = paragraphStyle.direction ?? .natural
            p.alignment = .natural
            paragraph.addAttribute(.paragraphStyle, value: p, range: NSRange(location: 0, length: paragraph.length))
            result.append(paragraph)
            if lineBreak {
                result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: p, .font: font ?? style.fonts.current]))
            }
            paragraph = NSMutableAttributedString(string: "")
        }

        func finish() -> NSMutableAttributedString {
            flush(lineBreak: false)
            return result
        }
    }

    static func applyInlineToken(_ rawHTML: String, to state: inout InlineState, style: Style,
                                 onImageFallback: ((Bool) -> Void)? = nil) -> NSAttributedString? {
        guard let tag = GMarkHTMLTokens.tag(rawHTML) else { return nil }
        if let ignored = state.ignoredTag {
            if tag.closing, tag.name == ignored { state.ignoredTag = nil }
            return nil
        }
        if GMarkHTMLTokens.discarded.contains(tag.name) {
            if !tag.closing, !tag.selfClosing, !GMarkHTMLTokens.voids.contains(tag.name) { state.ignoredTag = tag.name }
            return nil
        }
        if tag.closing { state.close(tag.name) }
        else if !tag.selfClosing, !GMarkHTMLTokens.voids.contains(tag.name) { state.push(tag) }
        switch tag.name {
        case "br": return NSAttributedString.singleNewline(withStyle: style)
        case "li": return tag.closing ? NSAttributedString.singleNewline(withStyle: style) : attributedText(from: "• ", style: style, state: state)
        case "p", "div", "blockquote": return tag.closing ? NSAttributedString.singleNewline(withStyle: style) : nil
        case "img" where !tag.closing:
            let alt = tag.attributes["alt"] ?? ""
            onImageFallback?(!alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            return attributedText(from: alt, style: style, state: state)
        default: return nil
        }
    }

    /// CommonMark Text nodes have already been decoded. Never decode here.
    static func attributedText(from text: String, style: Style, state: InlineState, htmlMode: Bool = false) -> NSMutableAttributedString {
        let result = MarkdownStyleProcessor.buildDefaultAttributedString(from: text, style: style)
        guard result.length > 0 else { return result }
        let value = state.current
        if htmlMode || state.isInHTMLContext {
            let p = (result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            p.paragraphSpacing = value.paragraphSpacing ?? 0
            if let size = value.fontSize {
                p.lineSpacing = max(0, 25 - size)
                result.addAttribute(.font, value: style.fonts.current.withSize(size))
            }
            if let direction = value.direction { p.baseWritingDirection = direction; p.alignment = .natural }
            result.addAttribute(.paragraphStyle, value: p)
            if let color = value.color { result.addAttribute(.foregroundColor, value: color) }
        }
        if value.bold == true { MarkdownStyleProcessor.applyBoldFont(to: result) }
        if value.italic == true { MarkdownStyleProcessor.applyItalicFont(to: result) }
        if value.underline { result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue) }
        if let mark = value.mark {
            result.addAttribute(.gmarkCustomClickableSpan, value: mark)
            result.addAttribute(.underlineStyle, value: GMarkEditorMarkStyle.fallbackUnderline)
            result.addAttribute(.underlineColor, value: GMarkEditorMarkStyle.color)
        }
        if value.strike { result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue) }
        if value.code {
            result.addAttribute(.font, value: style.codeBlockStyle.font)
            result.addAttribute(.foregroundColor, value: style.codeBlockStyle.foregroundColor)
        }
        if value.superscript || value.subscriptText {
            result.addAttribute(.baselineOffset, value: style.fonts.current.pointSize * (value.superscript ? 0.3 : -0.2))
            result.addAttribute(.font, value: style.fonts.current.withSize(style.fonts.current.pointSize * 0.75))
        }
        if !value.inlineDirections.isEmpty { result.addAttribute(.writingDirection, value: value.inlineDirections) }
        return result
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

}
