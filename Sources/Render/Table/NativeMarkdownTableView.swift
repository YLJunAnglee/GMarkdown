import Markdown
import MPITextKit
import UIKit

/// A public failure model that lets callers fall back without inspecting GMarkdown internals.
public enum NativeMarkdownTableRenderFailure: Error, Equatable {
    case emptyMarkdown
    case invalidContainerWidth
    case tableNotFound
    case multipleTables(count: Int)
    case containsUnsupportedContent
}

/// Public, implementation-independent information about a rendered table.
public struct NativeMarkdownTableRenderMetrics: Equatable {
    public let columnCount: Int
    public let bodyRowCount: Int
    public let requiredSize: CGSize

    public init(columnCount: Int, bodyRowCount: Int, requiredSize: CGSize) {
        self.columnCount = columnCount
        self.bodyRowCount = bodyRowCount
        self.requiredSize = requiredSize
    }
}

/// The synchronous result of preparing a native Markdown table.
public enum NativeMarkdownTableRenderResult: Equatable {
    case success(NativeMarkdownTableRenderMetrics)
    case failure(NativeMarkdownTableRenderFailure)

    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    public var metrics: NativeMarkdownTableRenderMetrics? {
        guard case let .success(metrics) = self else {
            return nil
        }
        return metrics
    }

    public var failure: NativeMarkdownTableRenderFailure? {
        guard case let .failure(failure) = self else {
            return nil
        }
        return failure
    }
}

/// A standalone native renderer for one Markdown table block.
///
/// This view intentionally hides parser, chunk, visitor, and cell implementation details.
/// Inputs containing no table, multiple tables, or other top-level Markdown content return
/// an explicit failure so a host application can fall back to another renderer.
public final class NativeMarkdownTableView: UIView {
    public private(set) var lastRenderResult: NativeMarkdownTableRenderResult = .failure(.emptyMarkdown)

    private let tableView = GMarkTableView()
    private let tableDataSource = NativeMarkdownTableDataSource()
    private var renderedStyle = MarkdownStyle.defaultStyle()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupTableView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTableView()
    }

    override public var intrinsicContentSize: CGSize {
        guard let metrics = lastRenderResult.metrics else {
            return .zero
        }
        return metrics.requiredSize
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let padding = renderedStyle.tableStyle.padding
        tableView.frame = bounds.inset(by: padding)
    }

    /// Parses and renders exactly one top-level Markdown table.
    ///
    /// - Parameters:
    ///   - markdown: The original Markdown table source. It is never modified by this view.
    ///   - style: The Markdown and table style used for parsing, measuring, and rendering.
    ///   - containerWidth: The available outer width, including table padding.
    /// - Returns: Public metrics on success, or a failure suitable for renderer fallback.
    @discardableResult
    public func render(
        markdown: String,
        style: MarkdownStyle = .defaultStyle(),
        containerWidth: CGFloat
    ) -> NativeMarkdownTableRenderResult {
        guard containerWidth.isFinite, containerWidth > 0 else {
            return finish(with: .failure(.invalidContainerWidth))
        }
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return finish(with: .failure(.emptyMarkdown))
        }

        let markups = GMarkParser().parseMarkdownToMarkups(markdown: markdown)
        let tables = markups.compactMap { $0 as? Table }

        guard !tables.isEmpty else {
            return finish(with: .failure(.tableNotFound))
        }
        guard tables.count == 1 else {
            return finish(with: .failure(.multipleTables(count: tables.count)))
        }
        guard markups.count == 1, markups.first is Table else {
            return finish(with: .failure(.containsUnsupportedContent))
        }

        var resolvedStyle = style
        resolvedStyle.maxContainerWidth = containerWidth
        resolvedStyle.useMPTextKit = true

        var visitor = GMarkupTableVisitor(style: resolvedStyle)
        let table = tables[0]
        let markTable = visitor.visit(table)
        let layout = GMarkTableLayout(markTable: markTable, style: resolvedStyle)
        let metrics = NativeMarkdownTableRenderMetrics(
            columnCount: table.maxColumnCount,
            bodyRowCount: Array(table.body.rows).count,
            requiredSize: CGSize(width: containerWidth, height: layout.tableHeight)
        )

        renderedStyle = resolvedStyle
        tableDataSource.update(tableLayout: layout, style: resolvedStyle)
        tableView.isHidden = false
        tableView.reloadData()
        setNeedsLayout()
        invalidateIntrinsicContentSize()

        lastRenderResult = .success(metrics)
        return lastRenderResult
    }

    /// Removes the current table and returns the view to its initial empty state.
    public func clear() {
        _ = finish(with: .failure(.emptyMarkdown))
    }

    private func setupTableView() {
        clipsToBounds = true
        tableView.backgroundColor = .white
        tableView.register(
            GMarkTableRichLabelCell.self,
            forCellReuseIdentifier: GMarkTableRichLabelCell.reuseIdentifier
        )
        tableView.dataSource = tableDataSource
        tableView.style = makeGridStyle()
        tableView.layer.cornerRadius = 6
        tableView.layer.masksToBounds = true
        tableView.isHidden = true
        addSubview(tableView)
    }

    private func makeGridStyle() -> GMarkTableStyle {
        let style = GMarkTableStyle()
        style.cornerRadius = 6
        style.colGap = 1
        style.gapColor = UIColor(red: 242 / 255, green: 242 / 255, blue: 1, alpha: 1)
        return style
    }

    @discardableResult
    private func finish(with result: NativeMarkdownTableRenderResult) -> NativeMarkdownTableRenderResult {
        tableDataSource.clear()
        tableView.isHidden = true
        tableView.reloadData()
        lastRenderResult = result
        invalidateIntrinsicContentSize()
        return result
    }
}

private final class NativeMarkdownTableDataSource: NSObject, GMarkTableViewDataSource {
    private var tableLayout: GMarkTableLayout?
    private var renderedStyle = MarkdownStyle.defaultStyle()

    func update(tableLayout: GMarkTableLayout, style: MarkdownStyle) {
        self.tableLayout = tableLayout
        renderedStyle = style
    }

    func clear() {
        tableLayout = nil
    }

    func numberOfRows(in _: GMarkTableView) -> Int {
        tableRenders.count
    }

    func numberOfCols(in _: GMarkTableView) -> Int {
        tableLayout?.headerRenders.count ?? 0
    }

    func numberOfLockingRows(in _: GMarkTableView) -> Int {
        0
    }

    func numberOfLockingCols(in _: GMarkTableView) -> Int {
        0
    }

    func table(_: GMarkTableView, lengthForRow row: Int) -> CGFloat {
        let tableStyle = renderedStyle.tableStyle
        guard let renders = tableRenders[safe: row] else {
            return tableStyle.cellHeight
        }

        let contentHeight = renders.reduce(CGFloat.zero) { height, renderer in
            max(height, renderer.size().height)
        }
        return max(
            tableStyle.cellHeight,
            contentHeight + tableStyle.cellPadding.top + tableStyle.cellPadding.bottom
        )
    }

    func table(_: GMarkTableView, lengthForCol col: Int) -> CGFloat {
        let tableStyle = renderedStyle.tableStyle
        let contentWidth = tableRenders.reduce(CGFloat.zero) { width, row in
            guard let renderer = row[safe: col] else {
                return width
            }
            return max(width, renderer.size().width)
        }
        return max(
            tableStyle.cellWidth,
            contentWidth + tableStyle.cellPadding.left + tableStyle.cellPadding.right
        )
    }

    func table(
        _ table: GMarkTableView,
        cellForIndexPath indexPath: TabIndexPath
    ) -> GMarkTableViewCell? {
        guard let cell = table.dequeueReusableCell(
            withIdentifier: GMarkTableRichLabelCell.reuseIdentifier,
            for: indexPath
        ) as? GMarkTableRichLabelCell else {
            return nil
        }
        guard let renderer = tableRenders[safe: indexPath.row]?[safe: indexPath.col] else {
            return GMarkTableViewCell.placeholder
        }

        cell.configure(renderer)
        cell.contentInset = renderedStyle.tableStyle.cellPadding
        if indexPath.row == 0 {
            cell.backgroundColor = renderedStyle.tableStyle.headerBackgroundColor
        } else if indexPath.row.isMultiple(of: 2) {
            cell.backgroundColor = renderedStyle.tableStyle.rowAlternateBackgroundColor ?? .clear
        } else {
            cell.backgroundColor = .clear
        }
        return cell
    }

    private var tableRenders: [[MPITextRenderer]] {
        guard let tableLayout else {
            return []
        }
        let headers = tableLayout.headerRenders
        let headerRows = headers.isEmpty ? [] : [headers]
        return headerRows + tableLayout.bodyRenders
    }
}

private extension GMarkTableRichLabelCell {
    static let reuseIdentifier = "NativeMarkdownTableRichLabelCell"
}
