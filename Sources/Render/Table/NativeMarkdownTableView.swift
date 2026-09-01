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
    case invalidCalculatedSize
}

/// A non-fatal issue. Rendering succeeds, but callers may choose a different renderer.
public enum NativeMarkdownTableRenderWarning: Equatable {
    /// One or more LaTeX fragments could not be rendered and were shown as plain text.
    case formulaFallback(count: Int)
}

/// Timing information for one render request.
public struct NativeMarkdownTableRenderPerformance: Equatable {
    public let parseDuration: TimeInterval
    public let formulaRenderDuration: TimeInterval
    public let layoutDuration: TimeInterval
    public let totalDuration: TimeInterval
    public let cacheHit: Bool

    public init(
        parseDuration: TimeInterval = 0,
        formulaRenderDuration: TimeInterval = 0,
        layoutDuration: TimeInterval = 0,
        totalDuration: TimeInterval = 0,
        cacheHit: Bool = false
    ) {
        self.parseDuration = parseDuration
        self.formulaRenderDuration = formulaRenderDuration
        self.layoutDuration = layoutDuration
        self.totalDuration = totalDuration
        self.cacheHit = cacheHit
    }
}

/// Public, implementation-independent information about a rendered table.
public struct NativeMarkdownTableRenderMetrics: Equatable {
    public let columnCount: Int
    public let bodyRowCount: Int
    public let requiredSize: CGSize
    public let warnings: [NativeMarkdownTableRenderWarning]
    public let formulaDiagnostics: [GMarkFormulaDiagnostic]
    public let performance: NativeMarkdownTableRenderPerformance
    /// Difference from the previously displayed successful table height. Nil on first render.
    public let heightDelta: CGFloat?

    public init(
        columnCount: Int,
        bodyRowCount: Int,
        requiredSize: CGSize,
        warnings: [NativeMarkdownTableRenderWarning] = [],
        formulaDiagnostics: [GMarkFormulaDiagnostic] = [],
        performance: NativeMarkdownTableRenderPerformance = .init(),
        heightDelta: CGFloat? = nil
    ) {
        self.columnCount = columnCount
        self.bodyRowCount = bodyRowCount
        self.requiredSize = requiredSize
        self.warnings = warnings
        self.formulaDiagnostics = formulaDiagnostics
        self.performance = performance
        self.heightDelta = heightDelta
    }
}

/// The result of preparing a native Markdown table.
public enum NativeMarkdownTableRenderResult: Equatable {
    case success(NativeMarkdownTableRenderMetrics)
    case failure(NativeMarkdownTableRenderFailure)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var metrics: NativeMarkdownTableRenderMetrics? {
        guard case let .success(metrics) = self else { return nil }
        return metrics
    }

    public var failure: NativeMarkdownTableRenderFailure? {
        guard case let .failure(failure) = self else { return nil }
        return failure
    }
}

/// A cooperative cancellation token returned by `renderAsync`.
///
/// Cancellation prevents an obsolete request from changing the view or invoking completion.
/// Rendering remains on the main thread because the underlying UIKit renderers are not Sendable.
public final class NativeMarkdownTableRenderTask {
    private let lock = NSLock()
    private var cancelled = false

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

/// A standalone native renderer for one Markdown table block.
public final class NativeMarkdownTableView: UIView {
    /// The latest legacy-compatible projection used by the original render API.
    public private(set) var lastRenderResult: NativeMarkdownTableRenderResult = .failure(.emptyMarkdown)
    /// The latest completed result from an API that supplied a formula configuration.
    public private(set) var lastFormulaRenderResult: NativeMarkdownTableFormulaRenderResult?

    private let tableView = GMarkTableView()
    private let tableDataSource = NativeMarkdownTableDataSource()
    private var renderedStyle = MarkdownStyle.defaultStyle()
    private let taskLock = NSLock()
    private var activeRenderTask: NativeMarkdownTableRenderTask?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupTableView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTableView()
    }

    deinit {
        cancelActiveRenderTask()
    }

    override public var intrinsicContentSize: CGSize {
        lastRenderResult.metrics?.requiredSize ?? .zero
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        tableView.frame = bounds.inset(by: renderedStyle.tableStyle.padding)
    }

    /// Parses and renders exactly one top-level Markdown table synchronously.
    /// Call this UIKit API on the main thread.
    @discardableResult
    public func render(
        markdown: String,
        style: MarkdownStyle = .defaultStyle(),
        containerWidth: CGFloat
    ) -> NativeMarkdownTableRenderResult {
        cancelActiveRenderTask()
        let result = prepareAndApply(
            markdown: markdown,
            style: style,
            containerWidth: containerWidth,
            formulaConfiguration: nil,
            formulaFailureHandler: nil,
            shouldApply: { true }
        ) ?? .failure(.emptyMarkdown)
        lastFormulaRenderResult = nil
        return result
    }

    /// Renders one table with a caller-supplied formula backend and explicit failure policy.
    @discardableResult
    public func render(
        markdown: String,
        style: MarkdownStyle = .defaultStyle(),
        containerWidth: CGFloat,
        formulaConfiguration: NativeMarkdownTableFormulaConfiguration
    ) -> NativeMarkdownTableFormulaRenderResult {
        cancelActiveRenderTask()
        var formulaFailureDiagnostics: [GMarkFormulaDiagnostic]?
        let result = prepareAndApply(
            markdown: markdown,
            style: style,
            containerWidth: containerWidth,
            formulaConfiguration: formulaConfiguration,
            formulaFailureHandler: { formulaFailureDiagnostics = $0 },
            shouldApply: { true }
        ) ?? .failure(.emptyMarkdown)
        let formulaResult = formulaResult(
            from: result,
            formulaFailureDiagnostics: formulaFailureDiagnostics
        )
        lastFormulaRenderResult = formulaResult
        return formulaResult
    }

    /// Schedules a cancellable render on the main queue.
    ///
    /// Starting another render or calling `clear()` invalidates the previous task. An obsolete
    /// request never writes its result back into a reused view and does not invoke completion.
    @discardableResult
    public func renderAsync(
        markdown: String,
        style: MarkdownStyle = .defaultStyle(),
        containerWidth: CGFloat,
        completion: @escaping (NativeMarkdownTableRenderResult) -> Void
    ) -> NativeMarkdownTableRenderTask {
        let task = NativeMarkdownTableRenderTask()
        activate(task)

        DispatchQueue.main.async { [weak self, weak task] in
            guard let self, let task, self.isActive(task) else { return }
            let result = self.prepareAndApply(
                markdown: markdown,
                style: style,
                containerWidth: containerWidth,
                formulaConfiguration: nil,
                formulaFailureHandler: nil,
                shouldApply: { [weak self, weak task] in
                    guard let self, let task else { return false }
                    return self.isActive(task)
                }
            )
            guard let result, self.complete(task) else { return }
            self.lastFormulaRenderResult = nil
            completion(result)
        }
        return task
    }

    /// Schedules a cancellable render using a caller-supplied formula backend.
    @discardableResult
    public func renderAsync(
        markdown: String,
        style: MarkdownStyle = .defaultStyle(),
        containerWidth: CGFloat,
        formulaConfiguration: NativeMarkdownTableFormulaConfiguration,
        completion: @escaping (NativeMarkdownTableFormulaRenderResult) -> Void
    ) -> NativeMarkdownTableRenderTask {
        let task = NativeMarkdownTableRenderTask()
        activate(task)

        DispatchQueue.main.async { [weak self, weak task] in
            guard let self, let task, self.isActive(task) else { return }
            var formulaFailureDiagnostics: [GMarkFormulaDiagnostic]?
            let result = self.prepareAndApply(
                markdown: markdown,
                style: style,
                containerWidth: containerWidth,
                formulaConfiguration: formulaConfiguration,
                formulaFailureHandler: { formulaFailureDiagnostics = $0 },
                shouldApply: { [weak self, weak task] in
                    guard let self, let task else { return false }
                    return self.isActive(task)
                }
            )
            guard let result, self.complete(task) else { return }
            let formulaResult = self.formulaResult(
                from: result,
                formulaFailureDiagnostics: formulaFailureDiagnostics
            )
            self.lastFormulaRenderResult = formulaResult
            completion(formulaResult)
        }
        return task
    }

    /// Removes all native table layout entries shared by renderer instances.
    public static func clearRenderCache() {
        NativeMarkdownTableRenderCache.shared.removeAll()
    }

    /// Removes the current table, cancels pending work, and returns to the initial empty state.
    public func clear() {
        cancelActiveRenderTask()
        lastFormulaRenderResult = nil
        _ = finish(with: .failure(.emptyMarkdown))
    }

    private func prepareAndApply(
        markdown: String,
        style: MarkdownStyle,
        containerWidth: CGFloat,
        formulaConfiguration: NativeMarkdownTableFormulaConfiguration?,
        formulaFailureHandler: (([GMarkFormulaDiagnostic]) -> Void)?,
        shouldApply: () -> Bool
    ) -> NativeMarkdownTableRenderResult? {
        let totalStart = ProcessInfo.processInfo.systemUptime
        guard containerWidth.isFinite, containerWidth > 0 else {
            return shouldApply() ? finish(with: .failure(.invalidContainerWidth)) : nil
        }
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return shouldApply() ? finish(with: .failure(.emptyMarkdown)) : nil
        }

        var resolvedStyle = style
        resolvedStyle.maxContainerWidth = containerWidth
        resolvedStyle.useMPTextKit = true
        let cacheKey = NativeMarkdownTableRenderCacheKey(
            markdown: markdown,
            containerWidth: containerWidth,
            style: resolvedStyle,
            traits: traitCollection,
            displayScale: resolvedDisplayScale,
            formulaRendererIdentity: formulaConfiguration?.renderer.cacheIdentity
                ?? "legacy-formula-renderer-v1",
            formulaFailurePolicy: formulaConfiguration?.failurePolicy.rawValue
                ?? "legacy-raw-formula"
        )

        if let prepared = NativeMarkdownTableRenderCache.shared.value(for: cacheKey) {
            guard shouldApply() else { return nil }
            return apply(
                prepared,
                style: resolvedStyle,
                parseDuration: 0,
                layoutDuration: 0,
                totalStart: totalStart,
                cacheHit: true
            )
        }

        let parseStart = ProcessInfo.processInfo.systemUptime
        let markups = GMarkParser().parseMarkdownToMarkups(markdown: markdown)
        let parseDuration = ProcessInfo.processInfo.systemUptime - parseStart
        let tables = markups.compactMap { $0 as? Table }

        guard !tables.isEmpty else {
            return shouldApply() ? finish(with: .failure(.tableNotFound)) : nil
        }
        guard tables.count == 1 else {
            return shouldApply() ? finish(with: .failure(.multipleTables(count: tables.count))) : nil
        }
        guard markups.count == 1, markups.first is Table else {
            return shouldApply() ? finish(with: .failure(.containsUnsupportedContent)) : nil
        }

        var visitor: GMarkupTableVisitor
        if let formulaConfiguration {
            visitor = GMarkupTableVisitor(
                style: resolvedStyle,
                formulaConfiguration: formulaConfiguration,
                traitCollection: traitCollection,
                displayScale: resolvedDisplayScale
            )
        } else {
            visitor = GMarkupTableVisitor(style: resolvedStyle)
        }
        let table = tables[0]
        let markTable = visitor.visit(table)
        if formulaConfiguration?.failurePolicy == .rejectWholeTable,
           markTable.formulaDiagnostics.contains(where: { $0.reasonCode != nil }) {
            guard shouldApply() else { return nil }
            formulaFailureHandler?(markTable.formulaDiagnostics)
            return finish(with: .failure(.containsUnsupportedContent))
        }
        let layoutStart = ProcessInfo.processInfo.systemUptime
        let layout = GMarkTableLayout(markTable: markTable, style: resolvedStyle)
        let layoutDuration = ProcessInfo.processInfo.systemUptime - layoutStart
        let requiredSize = CGSize(width: containerWidth, height: layout.tableHeight)
        guard requiredSize.width.isFinite,
              requiredSize.height.isFinite,
              requiredSize.width > 0,
              requiredSize.height > 0,
              layout.tableContentSize.width.isFinite,
              layout.tableContentSize.height.isFinite else {
            return shouldApply() ? finish(with: .failure(.invalidCalculatedSize)) : nil
        }

        let warnings: [NativeMarkdownTableRenderWarning] = markTable.latexFailureCount > 0
            ? [.formulaFallback(count: markTable.latexFailureCount)]
            : []
        let prepared = PreparedNativeMarkdownTableRender(
            layout: layout,
            columnCount: table.maxColumnCount,
            bodyRowCount: Array(table.body.rows).count,
            requiredSize: requiredSize,
            warnings: warnings,
            formulaDiagnostics: markTable.formulaDiagnostics,
            formulaRenderDuration: markTable.latexRenderDuration
        )
        guard shouldApply() else { return nil }
        let containsConfiguredFormulaFallback = formulaConfiguration != nil
            && markTable.latexFailureCount > 0
        if !containsConfiguredFormulaFallback {
            NativeMarkdownTableRenderCache.shared.insert(prepared, for: cacheKey)
        }
        return apply(
            prepared,
            style: resolvedStyle,
            parseDuration: parseDuration,
            layoutDuration: layoutDuration,
            totalStart: totalStart,
            cacheHit: false
        )
    }

    private func apply(
        _ prepared: PreparedNativeMarkdownTableRender,
        style: MarkdownStyle,
        parseDuration: TimeInterval,
        layoutDuration: TimeInterval,
        totalStart: TimeInterval,
        cacheHit: Bool
    ) -> NativeMarkdownTableRenderResult {
        let previousHeight = lastRenderResult.metrics?.requiredSize.height
        renderedStyle = style
        tableDataSource.update(tableLayout: prepared.layout, style: style)
        tableView.style = GMarkTableStyle.markdownStyle(from: style.tableStyle)
        tableView.isHidden = false
        tableView.reloadData()
        setNeedsLayout()

        let performance = NativeMarkdownTableRenderPerformance(
            parseDuration: parseDuration,
            formulaRenderDuration: cacheHit ? 0 : prepared.formulaRenderDuration,
            layoutDuration: layoutDuration,
            totalDuration: ProcessInfo.processInfo.systemUptime - totalStart,
            cacheHit: cacheHit
        )
        let metrics = NativeMarkdownTableRenderMetrics(
            columnCount: prepared.columnCount,
            bodyRowCount: prepared.bodyRowCount,
            requiredSize: prepared.requiredSize,
            warnings: prepared.warnings,
            formulaDiagnostics: cacheHit
                ? prepared.formulaDiagnostics.map { $0.replacingDuration(with: 0) }
                : prepared.formulaDiagnostics,
            performance: performance,
            heightDelta: previousHeight.map { prepared.requiredSize.height - $0 }
        )
        lastRenderResult = .success(metrics)
        invalidateIntrinsicContentSize()
        return lastRenderResult
    }

    private func formulaResult(
        from result: NativeMarkdownTableRenderResult,
        formulaFailureDiagnostics: [GMarkFormulaDiagnostic]?
    ) -> NativeMarkdownTableFormulaRenderResult {
        if let formulaFailureDiagnostics {
            return .failure(.formulaRenderingFailed(diagnostics: formulaFailureDiagnostics))
        }
        switch result {
        case let .success(metrics):
            return .success(metrics)
        case let .failure(failure):
            return .failure(.table(failure))
        }
    }

    private var resolvedDisplayScale: CGFloat {
        let scale = traitCollection.displayScale
        return scale > 0 ? scale : UIScreen.main.scale
    }

    private func setupTableView() {
        clipsToBounds = true
        tableView.backgroundColor = .clear
        tableView.register(
            GMarkTableRichLabelCell.self,
            forCellReuseIdentifier: GMarkTableRichLabelCell.reuseIdentifier
        )
        tableView.dataSource = tableDataSource
        tableView.style = GMarkTableStyle.markdownStyle(from: renderedStyle.tableStyle)
        tableView.layer.cornerRadius = 6
        tableView.layer.masksToBounds = true
        tableView.isHidden = true
        addSubview(tableView)
    }

    private func activate(_ task: NativeMarkdownTableRenderTask) {
        taskLock.lock()
        activeRenderTask?.cancel()
        activeRenderTask = task
        taskLock.unlock()
    }

    private func isActive(_ task: NativeMarkdownTableRenderTask) -> Bool {
        guard !task.isCancelled else { return false }
        taskLock.lock()
        defer { taskLock.unlock() }
        return activeRenderTask === task
    }

    @discardableResult
    private func complete(_ task: NativeMarkdownTableRenderTask) -> Bool {
        taskLock.lock()
        defer { taskLock.unlock() }
        guard activeRenderTask === task, !task.isCancelled else { return false }
        activeRenderTask = nil
        return true
    }

    private func cancelActiveRenderTask() {
        taskLock.lock()
        activeRenderTask?.cancel()
        activeRenderTask = nil
        taskLock.unlock()
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

    func clear() { tableLayout = nil }
    func numberOfRows(in _: GMarkTableView) -> Int { tableRenders.count }
    func numberOfCols(in _: GMarkTableView) -> Int { tableLayout?.columnWidths.count ?? 0 }
    func numberOfLockingRows(in _: GMarkTableView) -> Int { 0 }
    func numberOfLockingCols(in _: GMarkTableView) -> Int { 0 }

    func table(_: GMarkTableView, lengthForRow row: Int) -> CGFloat {
        tableLayout?.rowHeights[safe: row] ?? renderedStyle.tableStyle.cellHeight
    }

    func table(_: GMarkTableView, lengthForCol col: Int) -> CGFloat {
        tableLayout?.columnWidths[safe: col] ?? renderedStyle.tableStyle.cellWidth
    }

    func table(
        _ table: GMarkTableView,
        cellForIndexPath indexPath: TabIndexPath
    ) -> GMarkTableViewCell? {
        guard let cell = table.dequeueReusableCell(
            withIdentifier: GMarkTableRichLabelCell.reuseIdentifier,
            for: indexPath
        ) as? GMarkTableRichLabelCell else { return nil }
        guard let renderer = tableRenders[safe: indexPath.row]?[safe: indexPath.col] else {
            return GMarkTableViewCell.placeholder
        }

        cell.configure(renderer)
        cell.contentInset = renderedStyle.tableStyle.cellPadding
        if indexPath.row == 0 {
            cell.backgroundColor = renderedStyle.tableStyle.headerBackgroundColor
        } else if indexPath.row.isMultiple(of: 2) {
            cell.backgroundColor = renderedStyle.tableStyle.rowAlternateBackgroundColor ?? .white
        } else {
            cell.backgroundColor = .white
        }
        return cell
    }

    private var tableRenders: [[MPITextRenderer]] {
        guard let tableLayout else { return [] }
        let headers = tableLayout.headerRenders
        return (headers.isEmpty ? [] : [headers]) + tableLayout.bodyRenders
    }
}

private extension GMarkTableRichLabelCell {
    static let reuseIdentifier = "NativeMarkdownTableRichLabelCell"
}
