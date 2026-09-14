// Created on 2026/9/9.
import Foundation
import UIKit
import CoreText

/// Outline the leaf CJK text nodes emitted by MathJax, retaining SVG positioning.
/// Avoid asking the SVG decoder to shape fallback-font Unicode text itself.
enum GMarkSVGTextOutliner {
    static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            (0x3400...0x9FFF).contains($0.value) || (0xF900...0xFAFF).contains($0.value)
                || (0x20000...0x323AF).contains($0.value)
        }
    }

    static func outline(_ svg: String) throws -> String {
        let regex = try NSRegularExpression(pattern: #"<text\b([^>]*)>([^<]*)</text>"#)
        var result = svg
        var count = 0
        for match in regex.matches(in: svg, range: NSRange(svg.startIndex..., in: svg)).reversed() {
            guard let range = Range(match.range, in: result),
                  let originalRange = Range(match.range, in: svg) else { continue }
            let node = TextNode()
            let parser = XMLParser(data: Data(String(svg[originalRange]).utf8))
            parser.delegate = node
            guard parser.parse() else { throw Failure.invalidTextNode }
            guard containsCJK(node.text) else { continue }
            guard let sizeText = node.attributes["font-size"], sizeText.hasSuffix("px"),
                  let size = Double(sizeText.dropLast(2)), size.isFinite, size > 0,
                  node.attributes["x"] == nil, node.attributes["y"] == nil,
                  node.attributes["dx"] == nil, node.attributes["dy"] == nil,
                  node.attributes["text-anchor"] == nil else { throw Failure.unsupportedTextLayout }
            let d = try pathData(text: node.text, fontSize: CGFloat(size))
            // The generated MathJax transform stays on the group. Font attrs are
            // unnecessary once glyphs are paths; all other attrs are retained.
            let attributes = node.attributes.filter { !["font-size", "font-family"].contains($0.key) }
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\"\(escape($0.value))\"" }.joined(separator: " ")
            result.replaceSubrange(range, with: "<g \(attributes)><path d=\"\(d)\"/></g>")
            count += 1
        }
        #if DEBUG
        print("[FormulaCJK] outlinedTextNodes=\(count)")
        #endif
        return result
    }

    static func pathData(text: String, fontSize: CGFloat) throws -> String {
        let base = CTFontCreateWithName(UIFont.systemFont(ofSize: fontSize).fontName as CFString, fontSize, nil)
        let font = CTFontCreateForString(base, text as CFString, CFRange(location: 0, length: (text as NSString).length))
        let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attributed)
        let combined = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let runFont = attributes[kCTFontAttributeName] else { throw Failure.missingFont }
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for index in 0..<count {
                guard glyphs[index] != 0 else { throw Failure.missingGlyph }
                if let path = CTFontCreatePathForGlyph(runFont as! CTFont, glyphs[index], nil) {
                    // CoreText outlines have y-up coordinates; SVG text has y-down.
                    let transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                                      tx: positions[index].x, ty: -positions[index].y)
                    combined.addPath(path, transform: transform)
                }
            }
        }
        guard !combined.isEmpty else { throw Failure.missingGlyph }
        var commands: [String] = []
        func point(_ p: CGPoint) -> String { "\(p.x),\(p.y)" }
        combined.applyWithBlock { pointer in
            let e = pointer.pointee
            switch e.type {
            case .moveToPoint: commands.append("M" + point(e.points[0]))
            case .addLineToPoint: commands.append("L" + point(e.points[0]))
            case .addQuadCurveToPoint: commands.append("Q" + point(e.points[0]) + " " + point(e.points[1]))
            case .addCurveToPoint: commands.append("C" + point(e.points[0]) + " " + point(e.points[1]) + " " + point(e.points[2]))
            case .closeSubpath: commands.append("Z")
            @unknown default: break
            }
        }
        return commands.joined(separator: " ")
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }

    private final class TextNode: NSObject, XMLParserDelegate {
        var attributes: [String: String] = [:]
        var text = ""
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String]) {
            attributes = attributeDict
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    }

    enum Failure: Error {
        case invalidTextNode, unsupportedTextLayout, missingFont, missingGlyph
    }
}
