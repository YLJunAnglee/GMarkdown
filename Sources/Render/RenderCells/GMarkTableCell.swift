//
//  File 2.swift
//  GMarkdown
//
//  Created by GIKI on 2025/3/14.
//

import Foundation
import UIKit
import MPITextKit

class GMarkTableCell: UICollectionViewCell, GMarkTableViewDataSource, ChunkCellConfigurable {
    static let reuseIdentifier = "GMarkTableCell"

    public var handlerChain: GMarkHandlerChain?

    let table = GMarkTableView()
    var markChunk: GMarkChunk?
    public private(set) lazy var style: GMarkTableStyle = {
        let style = GMarkTableStyle.appearance
        style.cornerRadius = 6
        style.colGap = 1
        style.gapColor = UIColor(hex: "#F2F2FF")
        return style
    }()

    var tableStyle: TableStyle {
        guard let tableStyle = markChunk?.style.tableStyle else {
            return DefaultTableStyle()
        }
        return tableStyle
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        table.backgroundColor = .clear
        table.register(GMarkTableRichLabelCell.self, forCellReuseIdentifier: "GMarkTableRichLabelCell")
        table.dataSource = self
        table.style = style
        table.layer.cornerRadius = 6
        table.layer.masksToBounds = true
        contentView.addSubview(table)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        table.frame = contentView.bounds.inset(by: tableStyle.padding)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with chunk: GMarkChunk) {
        markChunk = chunk
        table.style = GMarkTableStyle.markdownStyle(from: tableStyle)
        table.reloadData()
    }

    func headerEmpty() -> Bool {
        return (markChunk?.tableRender?.headerRenders.isEmpty) != nil
    }

    func headerRenders() -> [MPITextRenderer] {
        if let renders = markChunk?.tableRender?.headerRenders {
            return renders
        }
        return []
    }

    func bodyRenders() -> [[MPITextRenderer]] {
        if let renders = markChunk?.tableRender?.bodyRenders {
            return renders
        }
        return [[]]
    }

    func tableRenders() -> [[MPITextRenderer]] {
        let header = headerRenders()
        let headerArray = header.isEmpty ? [] : [header]
        let body = bodyRenders()
        let result = headerArray + body
        return result
    }

    // MARK: GMarkTableViewDataSource

    func numberOfRows(in _: GMarkTableView) -> Int {
        return tableRenders().count
    }

    func numberOfCols(in _: GMarkTableView) -> Int {
        return markChunk?.tableRender?.columnWidths.count ?? 0
    }

    func numberOfLockingRows(in _: GMarkTableView) -> Int {
        return 0
    }

    func numberOfLockingCols(in _: GMarkTableView) -> Int {
        return 0
    }

    func table(_: GMarkTableView, lengthForRow row: Int) -> CGFloat {
        return markChunk?.tableRender?.rowHeights[safe: row] ?? tableStyle.cellHeight
    }

    func table(_: GMarkTableView, lengthForCol col: Int) -> CGFloat {
        return markChunk?.tableRender?.columnWidths[safe: col] ?? tableStyle.cellWidth
    }

    func table(_ table: GMarkTableView, cellForIndexPath indexPath: TabIndexPath) -> GMarkTableViewCell? {
        guard let cell = table.dequeueReusableCell(withIdentifier: "GMarkTableRichLabelCell", for: indexPath) as? GMarkTableRichLabelCell else {
            return nil
        }

        let renders = tableRenders()

        if indexPath.row < renders.count && indexPath.col < renders[indexPath.row].count {
            let textRender = renders[indexPath.row][indexPath.col]
            cell.configure(textRender)
        }

        cell.contentInset = tableStyle.cellPadding

        if indexPath.row == 0 {
            cell.backgroundColor = tableStyle.headerBackgroundColor
        } else if indexPath.row.isMultiple(of: 2) {
            cell.backgroundColor = tableStyle.rowAlternateBackgroundColor ?? .white
        } else {
            cell.backgroundColor = .white
        }

        return cell
    }
}
