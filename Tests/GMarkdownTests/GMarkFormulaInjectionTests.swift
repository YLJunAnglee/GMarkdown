//
//  GMarkFormulaInjectionTests.swift
//  GMarkdownTests
//
//  Created on 2026/9/1.
//

import Markdown
import CoreImage
import UIKit
import XCTest

@testable import GMarkdown

final class GMarkFormulaInjectionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NativeMarkdownTableView.clearRenderCache()
    }

    func testInjectedRendererReceivesHeaderAndBodyFormulasInTraversalOrder() throws {
        let renderer = FormulaRendererSpy(cacheIdentity: "fake-v1")
        let view = NativeMarkdownTableView()

        let result = view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(
                renderer: renderer,
                failurePolicy: .rawFormula
            )
        )

        let metrics = try XCTUnwrap(result.metrics)
        XCTAssertEqual(renderer.requests.map(\.latex), ["h", "b_1", "b_2", "b_3"])
        XCTAssertTrue(renderer.requests.allSatisfy { $0.container == .tableCell })
        XCTAssertEqual(metrics.formulaDiagnostics.map(\.ordinal), [0, 1, 2, 3])
        XCTAssertEqual(metrics.formulaDiagnostics.map(\.row), [0, 1, 1, 1])
        XCTAssertEqual(metrics.formulaDiagnostics.map(\.column), [0, 0, 0, 1])
        XCTAssertEqual(metrics.formulaDiagnostics.map(\.isHeader), [true, false, false, false])
        XCTAssertTrue(metrics.formulaDiagnostics.allSatisfy { $0.reasonCode == nil })
        XCTAssertTrue(metrics.formulaDiagnostics.allSatisfy { $0.backendRevision.rawValue == 1 })
    }

    func testRawFormulaPolicyPreservesSourceAndNeverFallsThroughToLegacyRenderer() throws {
        let renderer = FormulaRendererSpy(
            cacheIdentity: "fallback-v1",
            fallbackLatex: "b_2",
            fallbackReasonCode: .unsupportedFeature
        )
        let table = try parseSingleTable(formulaTable)
        var style = MarkdownStyle.defaultStyle()
        style.maxContainerWidth = 370
        var visitor = GMarkupTableVisitor(
            style: style,
            formulaConfiguration: .init(renderer: renderer, failurePolicy: .rawFormula),
            traitCollection: UITraitCollection(userInterfaceStyle: .light),
            displayScale: 2
        )

        let rendered = visitor.visit(table)

        XCTAssertEqual(renderer.requests.map(\.latex), ["h", "b_1", "b_2", "b_3"])
        XCTAssertEqual(rendered.bodys?[0][0].string, "\u{fffc} and $b_2$")
        XCTAssertEqual(rendered.formulaDiagnostics.compactMap(\.reasonCode), [.unsupportedFeature])
        XCTAssertEqual(rendered.latexFailureCount, 1)
    }

    func testRejectWholeTableReturnsSanitizedStructuredFailureAndClearsOldContent() throws {
        let view = NativeMarkdownTableView()
        XCTAssertTrue(view.render(markdown: plainTable, containerWidth: 370).isSuccess)
        let secretFormula = "private_formula_payload"
        let renderer = FormulaRendererSpy(
            cacheIdentity: "fallback-v1",
            fallbackLatex: secretFormula,
            fallbackReasonCode: .backendFailure,
            backendRevision: .init(rawValue: 2)
        )

        let result = view.render(
            markdown: "| Value |\n| --- |\n| $\(secretFormula)$ |",
            containerWidth: 370,
            formulaConfiguration: .init(
                renderer: renderer,
                failurePolicy: .rejectWholeTable
            )
        )

        guard case let .failure(.formulaRenderingFailed(diagnostics)) = result else {
            return XCTFail("Expected a structured formula rendering failure")
        }
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].reasonCode, .backendFailure)
        XCTAssertEqual(diagnostics[0].backendRevision.rawValue, 2)
        XCTAssertFalse(String(describing: diagnostics).contains(secretFormula))
        XCTAssertEqual(view.lastFormulaRenderResult, result)
        XCTAssertEqual(view.lastRenderResult, .failure(.containsUnsupportedContent))
        XCTAssertEqual(view.intrinsicContentSize, .zero)
    }

    func testConfiguredFallbackIsNotStoredInPreparedTableCache() throws {
        let firstRenderer = FormulaRendererSpy(
            cacheIdentity: "recovering-renderer-v1",
            fallbackLatex: "b_2"
        )
        let recoveredRenderer = FormulaRendererSpy(cacheIdentity: "recovering-renderer-v1")
        let view = NativeMarkdownTableView()

        let fallbackMetrics = try XCTUnwrap(view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(renderer: firstRenderer, failurePolicy: .rawFormula)
        ).metrics)
        let recoveredMetrics = try XCTUnwrap(view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(renderer: recoveredRenderer, failurePolicy: .rawFormula)
        ).metrics)

        XCTAssertEqual(fallbackMetrics.warnings, [.formulaFallback(count: 1)])
        XCTAssertFalse(recoveredMetrics.performance.cacheHit)
        XCTAssertTrue(recoveredMetrics.warnings.isEmpty)
        XCTAssertEqual(recoveredRenderer.requests.count, 4)
    }

    func testPreparedTableCacheEvictsByMeasuredRasterAndSourceBytes() throws {
        let center = NotificationCenter()
        let firstKey = renderCacheKey(markdown: "| first |")
        let secondKey = renderCacheKey(markdown: "| second |")
        let first = preparedRender(contents: "first", formulaRasterByteCost: 600)
        let second = preparedRender(contents: "second", formulaRasterByteCost: 600)
        let firstCost = try XCTUnwrap(first.cacheCost(for: firstKey))
        let secondCost = try XCTUnwrap(second.cacheCost(for: secondKey))
        let cache = NativeMarkdownTableRenderCache(totalCostLimit: max(firstCost, secondCost),
                                                   countLimit: 8,
                                                   notificationCenter: center)

        cache.insert(first, for: firstKey)
        XCTAssertNotNil(cache.value(for: firstKey))
        cache.insert(second, for: secondKey)

        XCTAssertNil(cache.value(for: firstKey))
        XCTAssertNotNil(cache.value(for: secondKey))
        XCTAssertEqual(cache.snapshot.entryCount, 1)
        XCTAssertLessThanOrEqual(cache.snapshot.totalCost, max(firstCost, secondCost))
    }

    func testPreparedTableCachePurgesOnInjectedMemoryWarning() {
        let center = NotificationCenter()
        let warning = Notification.Name("GMarkFormulaInjectionTests.memoryWarning")
        let cache = NativeMarkdownTableRenderCache(totalCostLimit: 1_000_000,
                                                   countLimit: 8,
                                                   notificationCenter: center)
        let key = renderCacheKey(markdown: "| warning |")
        cache.insert(preparedRender(contents: "warning", formulaRasterByteCost: 128),
                     for: key)
        XCTAssertEqual(cache.snapshot.entryCount, 1)

        center.post(name: warning, object: nil)
        XCTAssertEqual(cache.snapshot.entryCount, 1)
        center.post(name: LRUCacheMemoryWarningNotification, object: nil)

        XCTAssertEqual(cache.snapshot.entryCount, 0)
        XCTAssertEqual(cache.snapshot.totalCost, 0)
    }

    func testUnmeasurableFormulaRasterRendersButIsNeverCached() throws {
        let ciImage = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = UIImage(ciImage: ciImage, scale: 1, orientation: .up)
        XCTAssertNil(image.cgImage)
        let renderer = FormulaRendererSpy(cacheIdentity: "ci-image-v1", image: image)
        let view = NativeMarkdownTableView()

        let first = try XCTUnwrap(view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(renderer: renderer, failurePolicy: .rawFormula)
        ).metrics)
        let second = try XCTUnwrap(view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(renderer: renderer, failurePolicy: .rawFormula)
        ).metrics)

        XCTAssertFalse(first.performance.cacheHit)
        XCTAssertFalse(second.performance.cacheHit)
        XCTAssertEqual(renderer.requests.count, 8)
    }

    func testCacheSeparatesRendererIdentityAndFailurePolicy() throws {
        let first = FormulaRendererSpy(cacheIdentity: "renderer-a")
        let sameIdentity = FormulaRendererSpy(cacheIdentity: "renderer-a")
        let changedIdentity = FormulaRendererSpy(cacheIdentity: "renderer-b")
        let view = NativeMarkdownTableView()

        let firstMetrics = try XCTUnwrap(view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(renderer: first, failurePolicy: .rawFormula)
        ).metrics)
        let sameMetrics = try XCTUnwrap(view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(renderer: sameIdentity, failurePolicy: .rawFormula)
        ).metrics)
        let changedIdentityMetrics = try XCTUnwrap(view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(renderer: changedIdentity, failurePolicy: .rawFormula)
        ).metrics)
        let changedPolicyMetrics = try XCTUnwrap(view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(renderer: changedIdentity, failurePolicy: .rejectWholeTable)
        ).metrics)

        XCTAssertFalse(firstMetrics.performance.cacheHit)
        XCTAssertTrue(sameMetrics.performance.cacheHit)
        XCTAssertTrue(sameMetrics.formulaDiagnostics.allSatisfy { $0.duration == 0 })
        XCTAssertTrue(sameIdentity.requests.isEmpty)
        XCTAssertFalse(changedIdentityMetrics.performance.cacheHit)
        XCTAssertFalse(changedPolicyMetrics.performance.cacheHit)
        XCTAssertEqual(changedIdentity.requests.count, 8)
    }

    func testLegacyRenderAPIStillSucceedsWithoutFormulaConfiguration() {
        let view = NativeMarkdownTableView()
        _ = view.render(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(
                renderer: FormulaRendererSpy(cacheIdentity: "before-legacy-v1"),
                failurePolicy: .rawFormula
            )
        )
        XCTAssertNotNil(view.lastFormulaRenderResult)

        let result = view.render(
            markdown: formulaTable,
            containerWidth: 370
        )

        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.metrics?.formulaDiagnostics.isEmpty == true)
        XCTAssertNil(view.lastFormulaRenderResult)
    }

    func testConfiguredAsyncRejectPublishesTheStructuredLastResult() {
        let formula = "async_private_payload"
        let renderer = FormulaRendererSpy(
            cacheIdentity: "async-reject-v1",
            fallbackLatex: formula,
            fallbackReasonCode: .backendFailure,
            backendRevision: .init(rawValue: 2)
        )
        let view = NativeMarkdownTableView()
        let completed = expectation(description: "configured async reject completes")

        _ = view.renderAsync(
            markdown: "| Value |\n| --- |\n| $\(formula)$ |",
            containerWidth: 370,
            formulaConfiguration: .init(renderer: renderer, failurePolicy: .rejectWholeTable)
        ) { result in
            guard case let .failure(.formulaRenderingFailed(diagnostics)) = result else {
                return XCTFail("Expected configured async formula failure")
            }
            XCTAssertEqual(diagnostics.first?.reasonCode, .backendFailure)
            XCTAssertEqual(diagnostics.first?.backendRevision.rawValue, 2)
            XCTAssertEqual(view.lastFormulaRenderResult, result)
            completed.fulfill()
        }

        wait(for: [completed], timeout: 1)
    }

    func testNewestConfiguredAsyncRenderWinsDuringViewReuse() {
        let staleRenderer = FormulaRendererSpy(cacheIdentity: "async-stale-v1")
        let newestRenderer = FormulaRendererSpy(cacheIdentity: "async-newest-v1")
        let view = NativeMarkdownTableView()
        let staleCompletion = expectation(description: "obsolete configured render must not complete")
        staleCompletion.isInverted = true
        let newestCompletion = expectation(description: "newest configured render completes")

        let staleTask = view.renderAsync(
            markdown: formulaTable,
            containerWidth: 370,
            formulaConfiguration: .init(renderer: staleRenderer, failurePolicy: .rawFormula)
        ) { _ in
            staleCompletion.fulfill()
        }
        _ = view.renderAsync(
            markdown: formulaTable,
            containerWidth: 280,
            formulaConfiguration: .init(renderer: newestRenderer, failurePolicy: .rawFormula)
        ) { result in
            XCTAssertEqual(result.metrics?.requiredSize.width, 280)
            XCTAssertEqual(view.lastFormulaRenderResult, result)
            newestCompletion.fulfill()
        }

        XCTAssertTrue(staleTask.isCancelled)
        wait(for: [newestCompletion, staleCompletion], timeout: 1)
        XCTAssertTrue(staleRenderer.requests.isEmpty)
        XCTAssertEqual(newestRenderer.requests.count, 4)
    }

    private var plainTable: String {
        "| A | B |\n| --- | --- |\n| 1 | 2 |"
    }

    private var formulaTable: String {
        "| $h$ | Value |\n| --- | --- |\n| $b_1$ and $b_2$ | $b_3$ |"
    }

    private func parseSingleTable(_ markdown: String) throws -> Table {
        try XCTUnwrap(GMarkParser().parseMarkdownToMarkups(markdown: markdown).first as? Table)
    }

    private func renderCacheKey(markdown: String) -> NativeMarkdownTableRenderCacheKey {
        NativeMarkdownTableRenderCacheKey(markdown: markdown,
                                          containerWidth: 320,
                                          style: MarkdownStyle.defaultStyle(),
                                          traits: .init(userInterfaceStyle: .light),
                                          displayScale: 2)
    }

    private func preparedRender(contents: String,
                                formulaRasterByteCost: Int?)
        -> PreparedNativeMarkdownTableRender {
        var table = GMarkTable()
        table.contents = contents
        table.formulaRasterByteCost = formulaRasterByteCost
        let layout = GMarkTableLayout(markTable: table,
                                      style: MarkdownStyle.defaultStyle())
        return .init(layout: layout,
                     columnCount: 1,
                     bodyRowCount: 1,
                     requiredSize: CGSize(width: 1, height: 1),
                     warnings: [],
                     formulaDiagnostics: [],
                     formulaRenderDuration: 0)
    }
}

private final class FormulaRendererSpy: GMarkFormulaRendering {
    let cacheIdentity: String
    private let fallbackLatex: String?
    private let fallbackReasonCode: GMarkFormulaFallbackReasonCode
    private let backendRevision: GMarkFormulaBackendRevision
    private let image: UIImage?
    private(set) var requests: [GMarkFormulaRenderRequest] = []

    init(
        cacheIdentity: String,
        fallbackLatex: String? = nil,
        fallbackReasonCode: GMarkFormulaFallbackReasonCode = .unknown,
        backendRevision: GMarkFormulaBackendRevision = .init(rawValue: 1),
        image: UIImage? = nil
    ) {
        self.cacheIdentity = cacheIdentity
        self.fallbackLatex = fallbackLatex
        self.fallbackReasonCode = fallbackReasonCode
        self.backendRevision = backendRevision
        self.image = image
    }

    func renderFormula(_ request: GMarkFormulaRenderRequest) -> GMarkFormulaRenderResult {
        requests.append(request)
        if request.latex == fallbackLatex {
            return .fallback(
                reasonCode: fallbackReasonCode,
                backendRevision: backendRevision
            )
        }
        return .success(
            image: image
                ?? UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in },
            intrinsicSize: CGSize(width: 8, height: 8),
            backendRevision: backendRevision
        )
    }
}
