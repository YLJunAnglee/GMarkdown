import Foundation
import Markdown

public enum GMarkFormulaMode: String {
    case inline
    case block

    /// Bare TeX keeps the historical display default for direct backend callers.
    public static func detect(_ source: String) -> GMarkFormulaMode {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("$$") && text.hasSuffix("$$") { return .block }
        if text.hasPrefix(#"\["#) && text.hasSuffix(#"\]"#) { return .block }
        if text.hasPrefix("$") && text.hasSuffix("$") { return .inline }
        if text.hasPrefix(#"\("#) && text.hasSuffix(#"\)"#) { return .inline }
        return .block
    }

    static func isBlockParagraph(_ node: Markup) -> Bool {
        guard node is Paragraph, node.childCount == 3,
              (node.child(at: 0) as? InlineHTML)?.rawHTML == "<LaTex>",
              let payload = node.child(at: 1) as? Text,
              (node.child(at: 2) as? InlineHTML)?.rawHTML == "</LaTex>" else { return false }
        return detect(payload.string) == .block
    }
}

/// Split only paragraph children, preserving list/quote containers and table cells.
enum GMarkFormulaBlocks {
    static func normalize(_ node: Markup) -> Markup {
        if node is Table.Cell {
            // A table cell accepts inline children only. Keep display math inside
            // that cell, with local line boundaries rather than new table rows.
            let original = Array(node.children)
            var local: [Markup] = []
            var index = 0
            while index < original.count {
                if index + 2 < original.count,
                   (original[index] as? InlineHTML)?.rawHTML == "<LaTex>",
                   let payload = original[index + 1] as? Text,
                   GMarkFormulaMode.detect(payload.string) == .block,
                   (original[index + 2] as? InlineHTML)?.rawHTML == "</LaTex>" {
                    if let last = local.last, !(last is LineBreak || last is SoftBreak) { local.append(LineBreak()) }
                    local.append(contentsOf: original[index...index + 2])
                    index += 3
                    if index < original.count, !(original[index] is LineBreak || original[index] is SoftBreak) { local.append(LineBreak()) }
                } else {
                    local.append(original[index])
                    index += 1
                }
            }
            return node.withUncheckedChildren(local)
        }
        var children: [Markup] = []
        for child in node.children {
            if let paragraph = child as? Paragraph {
                children.append(contentsOf: split(paragraph))
            } else {
                children.append(normalize(child))
            }
        }
        return node.withUncheckedChildren(children)
    }

    private static func split(_ paragraph: Paragraph) -> [Markup] {
        let children = Array(paragraph.children)
        var result: [Markup] = []
        var pending: [Markup] = []
        func flush() {
            // Breaks bordering a new block are structural, not formula payload.
            while let first = pending.first, isBoundaryWhitespace(first) { pending.removeFirst() }
            while let last = pending.last, isBoundaryWhitespace(last) { pending.removeLast() }
            if !pending.isEmpty { result.append(paragraph.withUncheckedChildren(pending)) }
            pending.removeAll()
        }
        var index = 0
        var foundBlock = false
        while index < children.count {
            if index + 2 < children.count,
               (children[index] as? InlineHTML)?.rawHTML == "<LaTex>",
               let payload = children[index + 1] as? Text,
               GMarkFormulaMode.detect(payload.string) == .block,
               (children[index + 2] as? InlineHTML)?.rawHTML == "</LaTex>" {
                foundBlock = true
                flush()
                result.append(paragraph.withUncheckedChildren(Array(children[index...index + 2])))
                index += 3
            } else {
                pending.append(children[index])
                index += 1
            }
        }
        guard foundBlock else { return [paragraph] }
        flush()
        return result
    }

    private static func isBoundaryWhitespace(_ node: Markup) -> Bool {
        if node is SoftBreak || node is LineBreak { return true }
        if let text = node as? Text { return text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return false
    }
}
