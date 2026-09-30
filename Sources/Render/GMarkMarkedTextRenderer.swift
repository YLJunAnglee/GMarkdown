import UIKit
import MPITextKit

private extension MPITextRenderer {
    // MPITextRenderer.h publishes this selector, but MPITextKit's umbrella omits
    // MPITextInput.h, so Swift cannot import its forward-declared return class.
    // The returned MPITextSelectionRect objects subclass UITextSelectionRect.
    // Declare the existing Objective-C method; no replacement implementation.
    @objc(selectionRectsForCharacterRange:)
    @NSManaged func gmarkSelectionRects(for range: NSRange) -> [UITextSelectionRect]
}

/// Draws editor marks below the text using the renderer's own selection geometry.
/// Text layout, selection and source UTF-16 ranges remain owned by MPITextKit.
final class GMarkMarkedTextRenderer: MPITextRenderer {
    private(set) var markLines: [CGRect] = []
    private var markBottom: CGFloat = 0
    /// Only unlimited-height text chunks use this path; truncated/table renderers
    /// keep their existing implementation and cannot accidentally draw hidden marks.
    static func make(text: NSAttributedString, width: CGFloat) -> MPITextRenderer {
        let size = CGSize(width: width, height: CGFLOAT_MAX)
        let builder = MPITextRenderAttributesBuilder()
        builder.attributedText = text
        builder.maximumNumberOfLines = 0
        var ranges: [NSRange] = []
        text.enumerateAttribute(.gmarkCustomClickableSpan, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if value is String { ranges.append(range) }
        }
        guard !ranges.isEmpty else {
            return MPITextRenderer(renderAttributes: builder.build(), constrainedSize: size)
        }
        // Only the rendering copy loses its native underline. The source keeps
        // its marks and fallback underline for callers and other render paths.
        let display = NSMutableAttributedString(attributedString: text)
        let string = text.string as NSString
        var coveredParagraphEnd = 0
        for range in ranges {
            display.removeAttribute(.underlineStyle, range: range)
            display.removeAttribute(.underlineColor, range: range)
            // Ranges arrive in source order. Process each touched paragraph once,
            // even when a long paragraph contains hundreds of adjacent marks.
            let start = max(range.location, coveredParagraphEnd)
            guard start < NSMaxRange(range) else { continue }
            let paragraphRange = string.paragraphRange(for: NSRange(location: start, length: NSMaxRange(range) - start))
            coveredParagraphEnd = NSMaxRange(paragraphRange)
            display.enumerateAttribute(.paragraphStyle, in: paragraphRange) { value, run, _ in
                let paragraph = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                paragraph.lineSpacing = max(paragraph.lineSpacing, GMarkEditorMarkStyle.minimumLineSpacing)
                display.addAttribute(.paragraphStyle, value: paragraph, range: run)
            }
        }
        builder.attributedText = display
        let renderer = GMarkMarkedTextRenderer(renderAttributes: builder.build(), constrainedSize: size)
        for range in ranges {
            for selection in renderer.gmarkSelectionRects(for: range) {
                let rect = selection.rect
                guard !rect.isEmpty, !selection.isVertical else { continue }
                let index = renderer.characterIndex(for: CGPoint(x: rect.midX, y: rect.midY))
                guard index < UInt(text.length) else { continue }
                // MPITextKit's used rect excludes interline spacing. Use the
                // whole line for a consistent baseline across partial selections.
                let lineRect = renderer.lineFragmentUsedRectForCharacter(at: index, effectiveRange: nil)
                let y = lineRect.maxY + GMarkEditorMarkStyle.gap
                let x = max(rect.minX, lineRect.minX)
                let right = min(rect.maxX, lineRect.maxX)
                guard right > x else { continue }
                renderer.markLines.append(CGRect(x: x, y: y, width: right - x, height: GMarkEditorMarkStyle.thickness))
                renderer.markBottom = max(renderer.markBottom, y + GMarkEditorMarkStyle.thickness)
            }
        }
        return renderer
    }

    override func size() -> CGSize {
        let original = super.size()
        // Include the bottom stroke in the cell height, including a marked last line.
        return CGSize(width: original.width, height: ceil(max(original.height, markBottom)))
    }

    override func draw(at point: CGPoint, debugOption: MPITextDebugOption?) {
        super.draw(at: point, debugOption: debugOption)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(GMarkEditorMarkStyle.color.cgColor)
        context.setLineWidth(GMarkEditorMarkStyle.thickness)
        context.setLineCap(.round)
        context.setLineDash(phase: 0, lengths: [0, GMarkEditorMarkStyle.dotPitch])
        for line in markLines {
            let inset = min(GMarkEditorMarkStyle.thickness / 2, line.width / 2)
            context.move(to: CGPoint(x: point.x + line.minX + inset, y: point.y + line.midY))
            context.addLine(to: CGPoint(x: point.x + line.maxX - inset, y: point.y + line.midY))
            context.strokePath()
        }
    }
}
