//
//  GMarkFormulaInjectionTests.swift
//  GMarkdownTests
//
//  Created on 2026/9/1.
//

import Markdown
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
}

private final class FormulaRendererSpy: GMarkFormulaRendering {
    let cacheIdentity: String
    private let fallbackLatex: String?
    private let fallbackReasonCode: GMarkFormulaFallbackReasonCode
    private let backendRevision: GMarkFormulaBackendRevision
    private(set) var requests: [GMarkFormulaRenderRequest] = []

    init(
        cacheIdentity: String,
        fallbackLatex: String? = nil,
        fallbackReasonCode: GMarkFormulaFallbackReasonCode = .unknown,
        backendRevision: GMarkFormulaBackendRevision = .init(rawValue: 1)
    ) {
        self.cacheIdentity = cacheIdentity
        self.fallbackLatex = fallbackLatex
        self.fallbackReasonCode = fallbackReasonCode
        self.backendRevision = backendRevision
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
            image: UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in },
            intrinsicSize: CGSize(width: 8, height: 8),
            backendRevision: backendRevision
        )
    }
}
