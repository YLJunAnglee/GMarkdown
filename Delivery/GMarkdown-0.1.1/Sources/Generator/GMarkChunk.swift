//
//  GMarkChunk.swift
//  GMarkRender
//
//  Created by GIKI on 2025/04/27.
//

import CryptoKit
import Foundation
import Markdown
import MPITextKit
import UIKit

// MARK: - ChunkType

public enum ChunkType: Int {
    case Text = 0
    case Code = 1
    case Table = 2
    case BlockQuote = 3
    case Thematic = 4
    case Image = 5
    case Latex = 6
    case Html = 7
}

// MARK: - GMarkChunk

/// A class representing a parsed Markdown chunk with various rendering attributes.
/// Conforms to `Hashable` and `Equatable` to support diffing based on content changes.
public final class GMarkChunk: Hashable, Sendable {
    
    // MARK: - Properties
    
    /// A unique identifier for the chunk, provided externally.
    public var identifier: String = UUID().uuidString
    
    public var chunkIndex: Int = 0
    
    /// The children markup elements of this chunk.
    public var children: [Markup] = []
    
    /// The type of the chunk.
    public var chunkType: ChunkType = .Text
    
    /// The attributed text representation of the chunk.
    public var attributedText: NSAttributedString = NSAttributedString(string: "")

    private var dynamicTypeBaseText: NSAttributedString?
    private var dynamicTypeRenderedText: NSAttributedString?

    /// Recover the source of our last scaling pass when a host reuses this chunk.
    /// A newly assigned attributed string is new input, even if its text is equal.
    var unscaledAttributedText: NSAttributedString {
        if attributedText === dynamicTypeRenderedText, let base = dynamicTypeBaseText { return base }
        return attributedText
    }
    
    /// The text renderer for the chunk.
    public var textRender: MPITextRenderer?
    
    /// The text renderer used when the chunk is truncated.
    public var truncationTextRender: MPITextRenderer?
    
    /// The size of the chunk item.
    public var itemSize: CGSize = .zero
    
    /// The size of the truncated chunk item.
    public var truncationItemSize: CGSize = .zero
    
    /// The style applied to the chunk.
    public var style: Style = MarkdownStyle.defaultStyle()
    
    /// The table renderer, if the chunk is a table.
    public var tableRender: GMarkTableLayout?
    
    /// The programming language, if the chunk is a code block.
    public var language: String = ""
    
    public var codeSource: String = ""
    
    /// The source code or content of the chunk.
    public var source: String = ""
    
    /// The template source, if applicable.
    public var sourceTemplate: String = ""
    
    /// Line numbers or related metadata for the source, if applicable.
    public var sourceNumbers: [String] = []
    
    /// The size of the code block.
    public var codeSize: CGSize = .zero
    
    /// The size of the LaTeX block.
    public var latexSize: CGSize = .zero
    
    /// The image rendered from LaTeX, if applicable.
    public var latexImage: UIImage?
    public var latexKey: String?
    public var latexSvg: String?
    
    public var hashKey = UUID().uuidString
    
    // MARK: - Initializers
    
    // 无参构造器
    public init() {
        self.identifier = UUID().uuidString
        setupStyle()
        updateHashKey()
    }
    
    // 基础构造器 - identifier可选
    public init(identifier: String = UUID().uuidString) {
        self.identifier = identifier
        setupStyle()
        updateHashKey()
    }
    
    // 便利构造器 - chunkType
    public convenience init(chunkType: ChunkType) {
        self.init()
        self.chunkType = chunkType
        updateHashKey()
    }
    
    // 便利构造器 - children
    public convenience init(children: [Markup]) {
        self.init()
        self.children = children
        updateHashKey()
    }
    
    // 便利构造器 - chunkType和children
    public convenience init(chunkType: ChunkType, children: [Markup]) {
        self.init()
        self.chunkType = chunkType
        self.children = children
        updateHashKey()
    }
    
    // 便利构造器 - 完整参数
    public convenience init(identifier: String = UUID().uuidString,
                            chunkType: ChunkType = .Text,
                            children: [Markup] = []) {
        self.init(identifier: identifier)
        self.chunkType = chunkType
        self.children = children
        updateHashKey()
    }
    
    private func setupStyle() {
        style.useMPTextKit = true
        style.codeBlockStyle.customRender = true
    }
    
    public func updateHashKey() {
        hashKey = combineHash()
    }
    
    // MARK: - Hashable & Equatable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(hashKey)
    }
    
    public static func == (lhs: GMarkChunk, rhs: GMarkChunk) -> Bool {
        return lhs.identifier == rhs.identifier
        && lhs.hashKey == rhs.hashKey
    }
    
    // MARK: - Public Methods
    
    /// Generates a unique hash key based on the chunk's properties.
    ///
    /// - Returns: A unique string representing the hash key.
    public func combineHash() -> String {
        var customHash = "\(chunkIndex)" + "-" + "\(chunkType.rawValue)" + "-" + identifier
        switch chunkType {
        case .Text, .Latex:
            let text = attributedText.string
            customHash += text.md5()
        case .Code:
            let text = attributedText.string
            customHash += text.md5()
            customHash += language
        case .Table:
            let tableContent = tableRender?.markTable.contents ?? generateRandomString()
            if !tableContent.isEmpty {
                customHash += tableContent.md5()
            } else {
                customHash += generateRandomString()
            }
        case .Image:
            customHash += sourceTemplate
            customHash += source
        case .Thematic:
            customHash += generateRandomString()
        default:
            customHash += generateRandomString()
            break
        }
        
        customHash += String(format: "%.0f", ceil(itemSize.height))
        customHash += String(format: "%.0f", ceil(itemSize.width))
        
        return customHash
    }
    
    // MARK: - Private Methods
    
    /// Performs common initialization tasks.
    private func commonInitialization() {
        style.useMPTextKit = true
        style.codeBlockStyle.customRender = true
    }
    
    /// Generates a random string based on the current timestamp and a random number.
    ///
    /// - Returns: A random string.
    private func generateRandomString() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomNumber = Int.random(in: 0 ... 10000)
        let resultString = "\(timestamp)\(randomNumber)"
        return resultString + UUID().uuidString
    }
}

// MARK: - Container-driven layout

extension GMarkChunk {
    /// Rebuilds measured renderers with fonts scaled for the current Dynamic
    /// Type category. The caller supplies immutable source values so repeated
    /// trait changes never accumulate scaling.
    func applyDynamicType(style: Style,
                          baseAttributedText: NSAttributedString?,
                          baseTable: GMarkTable?,
                          baseAttachmentSizes: [(NSRange, CGSize)],
                          baseTableAttachmentSizes: (headers: [[(NSRange, CGSize)]], body: [[[(NSRange, CGSize)]]])?,
                          compatibleWith traitCollection: UITraitCollection) {
        self.style = style

        switch chunkType {
        case .Text, .Code:
            if let baseAttributedText {
                let rendered = baseAttributedText.scaledFonts(
                    compatibleWith: traitCollection,
                    baseAttachmentSizes: baseAttachmentSizes
                )
                dynamicTypeBaseText = baseAttributedText
                // Publish an immutable snapshot so identity can safely distinguish
                // our derived display text from freshly assigned host content.
                let snapshot = NSAttributedString(attributedString: rendered)
                dynamicTypeRenderedText = snapshot
                attributedText = snapshot
            }
            if chunkType == .Text {
                generatorTextRender()
            } else {
                calculateCode()
            }
        case .Table:
            guard var baseTable else { return }
            baseTable.headers = baseTable.headers?.enumerated().map { index, text in
                let sizes = baseTableAttachmentSizes?.headers[safe: index] ?? []
                return text.scaledFonts(compatibleWith: traitCollection, baseAttachmentSizes: sizes)
            }
            baseTable.bodys = baseTable.bodys?.enumerated().map { rowIndex, row in
                row.enumerated().map { cellIndex, text in
                    let sizes = baseTableAttachmentSizes?.body[safe: rowIndex]?[safe: cellIndex] ?? []
                    return text.scaledFonts(compatibleWith: traitCollection, baseAttachmentSizes: sizes)
                }
            }
            tableRender = GMarkTableLayout(markTable: baseTable, style: style)
            itemSize = CGSize(width: style.maxContainerWidth, height: tableRender?.tableHeight ?? 0)
        case .Latex:
            if let latexImage {
                let scale = UIFontMetrics.default.scaledValue(for: 1, compatibleWith: traitCollection)
                let padding = style.codeBlockStyle.padding
                itemSize = CGSize(
                    width: style.maxContainerWidth,
                    height: latexImage.size.height * scale + padding.top + padding.bottom
                )
            } else {
                calculateLatexText()
            }
        default:
            break
        }
    }

    /// Re-measures a prepared chunk for a changed host container width.
    /// The original style is restored first so repeated rotations/split changes
    /// do not accumulate rounding or shrink the configured maximum permanently.
    @discardableResult
    func relayout(for containerWidth: CGFloat, preserving originalStyle: Style) -> Bool {
        let width = max(1, min(originalStyle.maxContainerWidth, containerWidth))
        guard abs(style.maxContainerWidth - width) > 0.5 else { return false }

        style = originalStyle
        style.maxContainerWidth = width

        switch chunkType {
        case .Text:
            generatorTextRender()
        case .Code:
            calculateCode()
        case .Latex:
            if latexImage == nil {
                calculateLatexText()
            } else {
                itemSize.width = width
            }
        case .Table:
            if let table = tableRender {
                var tableStyle = style.tableStyle
                tableStyle.cellMaximumWidth = max(20, min(tableStyle.cellMaximumWidth, width - tableStyle.cellPadding.left - tableStyle.cellPadding.right))
                style.tableStyle = tableStyle
                tableRender = GMarkTableLayout(markTable: table.markTable, style: style)
                itemSize = CGSize(width: width, height: tableRender?.tableHeight ?? 0)
            }
        default:
            itemSize.width = width
        }
        return true
    }
}

extension NSAttributedString {
    func attachmentSizes() -> [(NSRange, CGSize)] {
        var result: [(NSRange, CGSize)] = []
        enumerateAttribute(.attachment, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            if let attachment = value as? MPITextAttachment {
                result.append((range, attachment.contentSize))
            }
        }
        return result
    }

    func scaledFonts(compatibleWith traitCollection: UITraitCollection,
                     baseAttachmentSizes: [(NSRange, CGSize)] = []) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: self)
        let metrics = UIFontMetrics.default
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            result.addAttribute(
                .font,
                value: metrics.scaledFont(for: font, compatibleWith: traitCollection),
                range: range
            )
        }
        let scale = metrics.scaledValue(for: 1, compatibleWith: traitCollection)
        for (range, baseSize) in baseAttachmentSizes {
            guard range.location < result.length,
                  let attachment = result.attribute(.attachment, at: range.location, effectiveRange: nil) as? MPITextAttachment else {
                continue
            }
            let scaledAttachment = MPITextAttachment()
            scaledAttachment.content = attachment.content
            scaledAttachment.contentSize = CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
            result.addAttribute(.attachment, value: scaledAttachment, range: range)
        }
        return result
    }
}
