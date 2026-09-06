//
//  GMarkupTableVisitor.swift
//  GMarkRender
//
//  Created by GIKI on 2024/7/26.
//

import Foundation
import Markdown
import UIKit
#if canImport(MPITextKit)
    import MPITextKit
#endif

public struct GMarkTable {
    var columnAlignments: [Table.ColumnAlignment?]?
    var maxColumnCount: Int?
    var headers: [NSAttributedString]? = []
    var bodys: [[NSAttributedString]]? = []
    var contents: String = ""
    var latexFailureCount: Int = 0
    var latexRenderDuration: TimeInterval = 0
    var formulaDiagnostics: [GMarkFormulaDiagnostic] = []
    var formulaRasterByteCost: Int? = 0
}

public struct GMarkupTableVisitor: MarkupVisitor {
    private let style: Style
    private let formulaConfiguration: NativeMarkdownTableFormulaConfiguration?
    private let traitCollection: UITraitCollection
    private let displayScale: CGFloat
    private var markTable: GMarkTable
    private var nextFormulaOrdinal: Int = 0
    public var imageLoader: ImageLoader?
    init(style: Style) {
        self.style = style
        formulaConfiguration = nil
        traitCollection = .current
        displayScale = UIScreen.main.scale
        markTable = GMarkTable()
    }

    init(
        style: Style,
        formulaConfiguration: NativeMarkdownTableFormulaConfiguration,
        traitCollection: UITraitCollection,
        displayScale: CGFloat
    ) {
        self.style = style
        self.formulaConfiguration = formulaConfiguration
        self.traitCollection = traitCollection
        self.displayScale = displayScale
        markTable = GMarkTable()
    }

    public typealias Result = GMarkTable

    public mutating func defaultVisit(_ markup: Markup) -> GMarkTable {
        for child in markup.children {
            _ = visit(child)
        }
        return markTable
    }

    /**
     Visit a `Table` element and return the result.

     - parameter table: A `Table` element.
     - returns: The result of the visit.
     */
    public mutating func visitTable(_ table: Table) -> GMarkTable {
        markTable.columnAlignments = table.columnAlignments
        markTable.maxColumnCount = table.maxColumnCount
        _ = visit(table.head)
        _ = visit(table.body)
        return markTable
    }

    /**
     Visit a `Table.Head` element and return the result.

     - parameter tableHead: A `Table.Head` element.
     - returns: The result of the visit.
     */
    public mutating func visitTableHead(_ tableHead: Table.Head) -> GMarkTable {
        var headers: [NSAttributedString] = []
        for (column, child) in tableHead.cells.enumerated() {
            var visitor = makeCellVisitor(row: 0, column: column, isHeader: true)
            visitor.imageLoader = imageLoader
            let attribute = visitor.visit(child)
            collectFormulaResults(from: visitor)
            markTable.contents += attribute.string
            headers.append(attribute)
        }
        markTable.headers = headers
        return markTable
    }

    /**
     Visit a `Table.Body` element and return the result.

     - parameter tableBody: A `Table.Body` element.
     - returns: The result of the visit.
     */
    public mutating func visitTableBody(_ tableBody: Table.Body) -> GMarkTable {
        for (index, child) in tableBody.rows.enumerated() {
            _ = visitTableRow(child, bodyRowIndex: index)
        }
        return markTable
    }

    /**
     Visit a `Table.Row` element and return the result.

     - parameter tableRow: A `Table.Row` element.
     - returns: The result of the visit.
     */
    public mutating func visitTableRow(_ tableRow: Table.Row) -> GMarkTable {
        visitTableRow(tableRow, bodyRowIndex: max(0, markTable.bodys?.count ?? 0))
    }

    private mutating func visitTableRow(
        _ tableRow: Table.Row,
        bodyRowIndex: Int
    ) -> GMarkTable {
        var rows: [NSAttributedString] = []
        for (column, child) in tableRow.cells.enumerated() {
            var visitor = makeCellVisitor(
                row: bodyRowIndex + 1,
                column: column,
                isHeader: false
            )
            visitor.imageLoader = imageLoader
            let attribute = visitor.visit(child)
            collectFormulaResults(from: visitor)
            markTable.contents += attribute.string
            rows.append(attribute)
        }
        if rows.count > 0 {
            markTable.bodys?.append(rows)
        }
        return markTable
    }

    private func makeCellVisitor(
        row: Int,
        column: Int,
        isHeader: Bool
    ) -> GMarkupVisitor {
        guard let formulaConfiguration else { return GMarkupVisitor(style: style) }
        return GMarkupVisitor(
            style: style,
            formulaRenderer: formulaConfiguration.renderer,
            formulaCellLocation: GMarkFormulaCellLocation(
                row: row,
                column: column,
                isHeader: isHeader
            ),
            startingFormulaOrdinal: nextFormulaOrdinal,
            traitCollection: traitCollection,
            displayScale: displayScale
        )
    }

    private mutating func collectFormulaResults(from visitor: GMarkupVisitor) {
        markTable.latexFailureCount += visitor.latexFailureCount
        markTable.latexRenderDuration += visitor.latexRenderDuration
        markTable.formulaDiagnostics += visitor.formulaDiagnostics
        if let currentCost = markTable.formulaRasterByteCost,
           let visitorCost = visitor.formulaRasterByteCost {
            let (total, overflow) = currentCost.addingReportingOverflow(visitorCost)
            markTable.formulaRasterByteCost = overflow ? nil : total
        } else {
            markTable.formulaRasterByteCost = nil
        }
        nextFormulaOrdinal += visitor.formulaDiagnostics.count
    }
}
