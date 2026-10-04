import Foundation
import UIKit

/// Syntax helpers for the editor HTML subset. No resource loading or DOM execution.
enum GMarkHTMLTokens {
    struct Tag {
        let name: String
        let attributes: [String: String]
        let closing: Bool
        let selfClosing: Bool
    }

    enum Token {
        case text(String)
        case tag(Tag)
    }

    static let blocks: Set<String> = ["p", "div", "blockquote", "li", "ul", "ol"]
    static let contexts: Set<String> = ["html", "body"]
    static let discarded: Set<String> = ["head", "script", "style", "iframe", "object", "embed", "form", "video", "audio", "svg", "math", "template"]
    static let voids: Set<String> = ["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"]

    static func isSpace(_ c: Character) -> Bool {
        c == " " || c == "\t" || c == "\n" || c == "\r" || c == "\r\n" || c == "\u{000C}"
    }

    static func tag(_ token: String) -> Tag? {
        guard token.first == "<", token.last == ">" else { return nil }
        let chars = Array(token.dropFirst().dropLast())
        var i = 0
        func skipSpace() { while i < chars.count, isSpace(chars[i]) { i += 1 } }
        skipSpace()
        let closing = i < chars.count && chars[i] == "/"
        if closing { i += 1 }
        guard i < chars.count, chars[i].isASCII, chars[i].isLetter else { return nil }
        let start = i
        while i < chars.count, chars[i].isASCII,
              chars[i].isLetter || chars[i].isNumber || chars[i] == "-" { i += 1 }
        let name = String(chars[start..<i]).lowercased()
        guard i == chars.count || isSpace(chars[i]) || chars[i] == "/" else { return nil }
        var attributes: [String: String] = [:]
        var selfClosing = false
        while i < chars.count {
            skipSpace()
            guard i < chars.count else { break }
            if chars[i] == "/", chars[(i + 1)...].allSatisfy({ isSpace($0) }) {
                selfClosing = true
                break
            }
            let keyStart = i
            while i < chars.count, !isSpace(chars[i]), chars[i] != "=", chars[i] != "/" { i += 1 }
            guard i > keyStart else { i += 1; continue }
            let key = String(chars[keyStart..<i]).lowercased()
            skipSpace()
            var value = ""
            if i < chars.count, chars[i] == "=" {
                i += 1
                skipSpace()
                if i < chars.count, chars[i] == "\"" || chars[i] == "'" {
                    let quote = chars[i]
                    i += 1
                    let valueStart = i
                    while i < chars.count, chars[i] != quote { i += 1 }
                    value = String(chars[valueStart..<i])
                    if i < chars.count { i += 1 }
                } else {
                    let valueStart = i
                    while i < chars.count, !isSpace(chars[i]) { i += 1 }
                    value = String(chars[valueStart..<i])
                }
            }
            if attributes[key] == nil { attributes[key] = decode(value) }
        }
        return Tag(name: name, attributes: attributes, closing: closing, selfClosing: selfClosing)
    }

    static func scan(_ source: String, emit: (Token) -> Void) {
        var i = source.startIndex
        var textStart = i
        while i < source.endIndex {
            guard source[i] == "<" else { i = source.index(after: i); continue }
            if source[i...].hasPrefix("<!--") {
                if textStart < i { emit(.text(String(source[textStart..<i]))) }
                i = source.range(of: "-->", range: i..<source.endIndex)?.upperBound ?? source.endIndex
                textStart = i
                continue
            }
            var end = source.index(after: i)
            var quote: Character?
            while end < source.endIndex {
                let c = source[end]
                if let q = quote { if c == q { quote = nil } }
                else if c == "\"" || c == "'" { quote = c }
                else if c == ">" { break }
                end = source.index(after: end)
            }
            guard end < source.endIndex else { break }
            let raw = String(source[i...end])
            guard let parsed = tag(raw) else {
                if raw.hasPrefix("<!") || raw.hasPrefix("<?") {
                    if textStart < i { emit(.text(String(source[textStart..<i]))) }
                    i = source.index(after: end)
                    textStart = i
                } else { i = source.index(after: end) }
                continue
            }
            if textStart < i { emit(.text(String(source[textStart..<i]))) }
            i = source.index(after: end)
            if discarded.contains(parsed.name), !parsed.closing,
               !parsed.selfClosing, !voids.contains(parsed.name) {
                // Contents of these containers are opaque, including apparent tags in script text.
                let closing = "</" + parsed.name
                var search = i
                var foundEnd: String.Index?
                while let match = source.range(of: closing, options: .caseInsensitive, range: search..<source.endIndex) {
                    let next = match.upperBound
                    if next < source.endIndex, source[next] == ">" || isSpace(source[next]) {
                        foundEnd = source[next...].firstIndex(of: ">").map { source.index(after: $0) }
                        break
                    }
                    search = next
                }
                i = foundEnd ?? source.endIndex
            } else { emit(.tag(parsed)) }
            textStart = i
        }
        if textStart < source.endIndex { emit(.text(String(source[textStart...]))) }
    }

    /// One pass, semicolon-terminated references only. Decoded text is never tokenized again.
    static func decode(_ text: String) -> String {
        let named = ["lt": "<", "gt": ">", "quot": "\"", "apos": "'", "amp": "&", "nbsp": "\u{00A0}"]
        let controls: [UInt32: UInt32] = [0x80:0x20AC, 0x82:0x201A, 0x83:0x0192, 0x84:0x201E,
            0x85:0x2026, 0x86:0x2020, 0x87:0x2021, 0x88:0x02C6, 0x89:0x2030, 0x8A:0x0160,
            0x8B:0x2039, 0x8C:0x0152, 0x8E:0x017D, 0x91:0x2018, 0x92:0x2019, 0x93:0x201C,
            0x94:0x201D, 0x95:0x2022, 0x96:0x2013, 0x97:0x2014, 0x98:0x02DC, 0x99:0x2122,
            0x9A:0x0161, 0x9B:0x203A, 0x9C:0x0153, 0x9E:0x017E, 0x9F:0x0178]
        var result = ""
        var i = text.startIndex
        while i < text.endIndex {
            guard text[i] == "&" else { result.append(text[i]); i = text.index(after: i); continue }
            var end = text.index(after: i)
            while end < text.endIndex, text[end].isASCII,
                  text[end].isLetter || text[end].isNumber || text[end] == "#" {
                end = text.index(after: end)
            }
            guard end < text.endIndex, text[end] == ";" else {
                result.append(contentsOf: text[i..<end])
                i = end
                continue
            }
            let body = String(text[text.index(after: i)..<end])
            var decoded = named[body]
            if body.hasPrefix("#") {
                var digits = body.dropFirst()
                let hex = digits.first == "x" || digits.first == "X"
                if hex { digits = digits.dropFirst() }
                if !digits.isEmpty, digits.allSatisfy({ hex ? $0.isHexDigit : ($0 >= "0" && $0 <= "9") }) {
                    var value = UInt32(digits, radix: hex ? 16 : 10) ?? 0xFFFD
                    if value == 0 || value > 0x10FFFF || (0xD800...0xDFFF).contains(value) { value = 0xFFFD }
                    value = controls[value] ?? value
                    decoded = UnicodeScalar(value).map { String($0) }
                }
            }
            result += decoded ?? String(text[i...end])
            i = text.index(after: end)
        }
        return result
    }

    private static let strong = try! NSRegularExpression(pattern: #"[\p{Bidi_Class=L}\p{Bidi_Class=R}\p{Bidi_Class=AL}]"#)
    private static let rtl = try! NSRegularExpression(pattern: #"[\p{Bidi_Class=R}\p{Bidi_Class=AL}]"#)

    static func firstStrongDirection(_ text: String) -> NSWritingDirection? {
        guard let match = strong.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return rtl.firstMatch(in: text, range: match.range) == nil ? .leftToRight : .rightToLeft
    }
}
