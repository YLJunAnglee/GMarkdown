import Foundation
import UIKit

/// Explicit entry for the supported editor HTML subset. HTML bypasses Markdown
/// preprocessing, so dollar signs, backticks and blank lines retain HTML meaning.
/// Configure before processing; each call owns its parse and style state.
public final class GMarkHTMLProcessor {
    public var style: Style
    public var identifier: String
    /// Soft UTF-16 limit. A paragraph remains intact even when it exceeds this limit.
    public var maxAttributedStringLength: Int

    public init(style: Style = MarkdownStyle.defaultStyle(),
                identifier: String = UUID().uuidString,
                maxAttributedStringLength: Int = 2000) {
        self.style = style
        self.identifier = identifier
        self.maxAttributedStringLength = maxAttributedStringLength
    }

    public func process(html: String) -> [GMarkChunk] {
        let renderStyle = style
        let documentID = identifier
        let limit = max(1, maxAttributedStringLength)
        let text = GMarkHTMLSanitizer.attributedString(from: html, style: renderStyle)
        let string = text.string as NSString
        var chunks: [GMarkChunk] = []
        var start = 0
        var end = 0

        func appendChunk(endingAt boundary: Int) {
            guard boundary > start else { return }
            let chunk = GMarkChunk(identifier: documentID, chunkType: .Text)
            chunk.style = renderStyle
            chunk.chunkIndex = chunks.count
            chunk.attributedText = text.attributedSubstring(from: NSRange(location: start, length: boundary - start))
            chunk.generatorTextRender()
            chunks.append(chunk)
            start = boundary
        }

        while end < text.length {
            let paragraph = string.paragraphRange(for: NSRange(location: end, length: 0))
            let next = NSMaxRange(paragraph)
            if next - start > limit { appendChunk(endingAt: end) }
            end = next
        }
        appendChunk(endingAt: end)
        return chunks
    }
}
