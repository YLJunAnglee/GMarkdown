//
//  GMarkTableLayout.swift
//  GMarkdown
//
//  Created by GIKI on 2025/04/27.
//

import Foundation
import Markdown
import MPITextKit
import UIKit

/// Measures every cell in a Markdown table and produces one shared layout for all renderers.
public final class GMarkTableLayout {
    public let markTable: GMarkTable
    public let style: Style

    public var headerRenders: [MPITextRenderer] = []
    public var bodyRenders: [[MPITextRenderer]] = []
    public private(set) var columnWidths: [CGFloat] = []
    public private(set) var rowHeights: [CGFloat] = []
    public private(set) var tableContentSize: CGSize = .zero
    public var tableHeight: CGFloat = 0

    public init(markTable: GMarkTable, style: Style) {
        self.markTable = markTable
        self.style = style
        setupTableRender()
    }

    /// Rebuilds renderers and sizes after the style or its container width changes.
    public func refreshRender() {
        setupTableRender()
    }

    private func setupTableRender() {
        headerRenders = []
        bodyRenders = []
        columnWidths = []
        rowHeights = []
        tableContentSize = .zero
        tableHeight = 0

        let headers = markTable.headers ?? []
        let bodies = markTable.bodys ?? []
        let columnCount = max(
            markTable.maxColumnCount ?? 0,
            headers.count,
            bodies.map(\.count).max() ?? 0
        )
        guard columnCount > 0 else {
            return
        }

        let normalizedHeaders = normalized(row: headers, columnCount: columnCount)
        let normalizedBodies = bodies.map { normalized(row: $0, columnCount: columnCount) }
        let tableStyle = style.tableStyle
        let horizontalCellPadding = tableStyle.cellPadding.left + tableStyle.cellPadding.right
        let minimumCellWidth = max(tableStyle.cellWidth, horizontalCellPadding + 1)
        let maximumContentWidth = resolvedMaximumContentWidth()

        var naturalWidths = Array(repeating: minimumCellWidth, count: columnCount)
        let attributedRows = (headers.isEmpty ? [] : [normalizedHeaders]) + normalizedBodies
        for (rowIndex, row) in attributedRows.enumerated() {
            for (columnIndex, attributedText) in row.enumerated() {
                let renderer = createTextRenderer(
                    from: attributedText,
                    column: columnIndex,
                    isHeader: !headers.isEmpty && rowIndex == 0,
                    maxWidth: maximumContentWidth
                )
                naturalWidths[columnIndex] = max(
                    naturalWidths[columnIndex],
                    renderer.size().width + horizontalCellPadding
                )
            }
        }

        columnWidths = widthsFillingContainerIfPossible(naturalWidths)
        let contentWidths = columnWidths.map { max(1, $0 - horizontalCellPadding) }

        if !headers.isEmpty {
            headerRenders = normalizedHeaders.enumerated().map { columnIndex, attributedText in
                createTextRenderer(
                    from: attributedText,
                    column: columnIndex,
                    isHeader: true,
                    maxWidth: contentWidths[columnIndex]
                )
            }
        }
        bodyRenders = normalizedBodies.map { row in
            row.enumerated().map { columnIndex, attributedText in
                createTextRenderer(
                    from: attributedText,
                    column: columnIndex,
                    isHeader: false,
                    maxWidth: contentWidths[columnIndex]
                )
            }
        }

        let rendererRows = (headerRenders.isEmpty ? [] : [headerRenders]) + bodyRenders
        let verticalCellPadding = tableStyle.cellPadding.top + tableStyle.cellPadding.bottom
        rowHeights = rendererRows.map { row in
            let contentHeight = row.reduce(CGFloat.zero) { height, renderer in
                max(height, renderer.size().height)
            }
            return max(tableStyle.cellHeight, contentHeight + verticalCellPadding)
        }

        let separatorWidth = max(0, tableStyle.borderWidth)
        let contentWidth = columnWidths.reduce(0, +)
            + CGFloat(max(columnCount - 1, 0)) * separatorWidth
            + separatorWidth * 2
        let contentHeight = rowHeights.reduce(0, +)
            + CGFloat(max(rowHeights.count - 1, 0)) * separatorWidth
            + separatorWidth * 2
        tableContentSize = CGSize(width: contentWidth, height: contentHeight)
        tableHeight = contentHeight + tableStyle.padding.top + tableStyle.padding.bottom
    }

    private func normalized(row: [NSAttributedString], columnCount: Int) -> [NSAttributedString] {
        if row.count >= columnCount {
            return Array(row.prefix(columnCount))
        }
        return row + Array(repeating: NSAttributedString(string: ""), count: columnCount - row.count)
    }

    private func resolvedMaximumContentWidth() -> CGFloat {
        let configuredWidth = style.tableStyle.cellMaximumWidth
        if configuredWidth.isFinite, configuredWidth > 0 {
            return configuredWidth
        }
        let padding = style.tableStyle.padding.left + style.tableStyle.padding.right
            + style.tableStyle.cellPadding.left + style.tableStyle.cellPadding.right
        return max(1, style.maxContainerWidth - padding)
    }

    private func widthsFillingContainerIfPossible(_ naturalWidths: [CGFloat]) -> [CGFloat] {
        guard !naturalWidths.isEmpty else {
            return []
        }
        let tableStyle = style.tableStyle
        let separatorWidth = max(0, tableStyle.borderWidth)
        let outerPadding = tableStyle.padding.left + tableStyle.padding.right
        let availableTableWidth = max(0, style.maxContainerWidth - outerPadding)
        let availableCellWidth = max(
            0,
            availableTableWidth
                - separatorWidth * 2
                - CGFloat(max(naturalWidths.count - 1, 0)) * separatorWidth
        )
        let naturalCellWidth = naturalWidths.reduce(0, +)
        guard availableCellWidth > naturalCellWidth else {
            return naturalWidths
        }

        let extraPerColumn = (availableCellWidth - naturalCellWidth) / CGFloat(naturalWidths.count)
        var widths = naturalWidths.map { $0 + extraPerColumn }
        // Keep the final sum stable despite floating-point division.
        if let last = widths.indices.last {
            widths[last] += availableCellWidth - widths.reduce(0, +)
        }
        return widths
    }

    private func createTextRenderer(
        from attributedText: NSAttributedString,
        column: Int,
        isHeader: Bool,
        maxWidth: CGFloat
    ) -> MPITextRenderer {
        let builder = MPITextRenderAttributesBuilder()
        builder.attributedText = styledText(
            attributedText,
            column: column,
            isHeader: isHeader
        )
        builder.maximumNumberOfLines = UInt(max(0, style.tableStyle.maximumNumberOfLines))
        let renderAttributes = MPITextRenderAttributes(builder: builder)
        let constrainedSize = CGSize(width: max(1, maxWidth), height: CGFloat.greatestFiniteMagnitude)
        return MPITextRenderer(renderAttributes: renderAttributes, constrainedSize: constrainedSize)
    }

    private func styledText(
        _ attributedText: NSAttributedString,
        column: Int,
        isHeader: Bool
    ) -> NSAttributedString {
        guard attributedText.length > 0 else {
            return attributedText
        }
        let result = NSMutableAttributedString(attributedString: attributedText)
        let range = NSRange(location: 0, length: result.length)
        let paragraphStyle = NSMutableParagraphStyle()
        if let existing = attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
            as? NSParagraphStyle {
            paragraphStyle.setParagraphStyle(existing)
        }
        paragraphStyle.alignment = textAlignment(for: column)
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        if isHeader {
            result.addAttribute(
                .foregroundColor,
                value: style.tableStyle.headerTextColor,
                range: range
            )
        }
        return result
    }

    private func textAlignment(for column: Int) -> NSTextAlignment {
        guard let alignment = markTable.columnAlignments?[safe: column] ?? nil else {
            return .left
        }
        switch alignment {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        }
    }
}
