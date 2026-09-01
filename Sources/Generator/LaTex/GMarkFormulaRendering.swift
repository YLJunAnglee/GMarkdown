//
//  GMarkFormulaRendering.swift
//  GMarkdown
//
//  Created on 2026/9/1.
//

import UIKit

/// A caller-supplied formula backend used by GMarkdown without depending on business-layer types.
public protocol GMarkFormulaRendering: AnyObject {
    /// Must change whenever analyzer, dialect, capability, or backend behavior changes.
    var cacheIdentity: String { get }

    func renderFormula(_ request: GMarkFormulaRenderRequest) -> GMarkFormulaRenderResult
}

public enum GMarkFormulaContainer: String, Equatable {
    case inline
    case block
    case tableCell
}

public struct GMarkFormulaRenderRequest {
    public let latex: String
    public let container: GMarkFormulaContainer
    public let font: UIFont
    public let textColor: UIColor
    public let maximumWidth: CGFloat
    public let displayScale: CGFloat
    public let traitCollection: UITraitCollection

    public init(
        latex: String,
        container: GMarkFormulaContainer,
        font: UIFont,
        textColor: UIColor,
        maximumWidth: CGFloat,
        displayScale: CGFloat,
        traitCollection: UITraitCollection
    ) {
        self.latex = latex
        self.container = container
        self.font = font
        self.textColor = textColor
        self.maximumWidth = maximumWidth
        self.displayScale = displayScale
        self.traitCollection = traitCollection
    }
}

/// A library-owned stable reason code. Callers can select a code but cannot create payload-bearing values.
public struct GMarkFormulaFallbackReasonCode: Equatable, Hashable {
    public let rawValue: String

    private init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let emptySource = Self("source.empty")
    public static let unsupportedFeature = Self("source.unsupported_feature")
    public static let rejectedActiveContent = Self("source.rejected_active_content")
    public static let sourceBudgetExceeded = Self("source.budget_exceeded")
    public static let nestingBudgetExceeded = Self("source.nesting_budget_exceeded")
    public static let backendUnavailable = Self("backend.unavailable")
    public static let backendFailure = Self("backend.failure")
    public static let invalidBackendOutput = Self("result.invalid_backend_output")
    public static let outputBudgetExceeded = Self("result.budget_exceeded")
    public static let invalidImageSize = Self("result.invalid_image_size")
    public static let invalidIntrinsicSize = Self("result.invalid_intrinsic_size")
    public static let unknown = Self("unknown")
}

/// A caller-owned stable numeric revision. The numeric representation cannot contain formula payloads.
public struct GMarkFormulaBackendRevision: RawRepresentable, Equatable, Hashable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

public enum GMarkFormulaRenderResult {
    case success(
        image: UIImage,
        intrinsicSize: CGSize,
        backendRevision: GMarkFormulaBackendRevision
    )
    case fallback(
        reasonCode: GMarkFormulaFallbackReasonCode,
        backendRevision: GMarkFormulaBackendRevision
    )
}

public enum NativeMarkdownTableFormulaFailurePolicy: String, Equatable {
    /// Preserve the exact wrapped formula source as visible text.
    case rawFormula
    /// Reject the complete table before applying any partially prepared content.
    case rejectWholeTable
}

public struct NativeMarkdownTableFormulaConfiguration {
    public let renderer: any GMarkFormulaRendering
    public let failurePolicy: NativeMarkdownTableFormulaFailurePolicy

    public init(
        renderer: any GMarkFormulaRendering,
        failurePolicy: NativeMarkdownTableFormulaFailurePolicy
    ) {
        self.renderer = renderer
        self.failurePolicy = failurePolicy
    }
}

public enum NativeMarkdownTableFormulaRenderFailure: Equatable {
    case table(NativeMarkdownTableRenderFailure)
    case formulaRenderingFailed(diagnostics: [GMarkFormulaDiagnostic])
}

public enum NativeMarkdownTableFormulaRenderResult: Equatable {
    case success(NativeMarkdownTableRenderMetrics)
    case failure(NativeMarkdownTableFormulaRenderFailure)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var metrics: NativeMarkdownTableRenderMetrics? {
        guard case let .success(metrics) = self else { return nil }
        return metrics
    }

    public var failure: NativeMarkdownTableFormulaRenderFailure? {
        guard case let .failure(failure) = self else { return nil }
        return failure
    }
}

/// Sanitized formula metadata. It intentionally contains no formula source, SVG, URL, or image.
public struct GMarkFormulaDiagnostic: Equatable {
    /// Zero-based traversal order across table header and body cells.
    public let ordinal: Int
    /// Zero-based table row. The header is row zero and body rows start at one.
    public let row: Int
    public let column: Int
    public let isHeader: Bool
    public let container: GMarkFormulaContainer
    public let reasonCode: GMarkFormulaFallbackReasonCode?
    public let backendRevision: GMarkFormulaBackendRevision
    public let duration: TimeInterval

    init(
        ordinal: Int,
        row: Int,
        column: Int,
        isHeader: Bool,
        container: GMarkFormulaContainer,
        reasonCode: GMarkFormulaFallbackReasonCode?,
        backendRevision: GMarkFormulaBackendRevision,
        duration: TimeInterval
    ) {
        self.ordinal = ordinal
        self.row = row
        self.column = column
        self.isHeader = isHeader
        self.container = container
        self.reasonCode = reasonCode
        self.backendRevision = backendRevision
        self.duration = duration
    }
}

struct GMarkFormulaCellLocation {
    let row: Int
    let column: Int
    let isHeader: Bool
}

extension GMarkFormulaDiagnostic {
    func replacingDuration(with duration: TimeInterval) -> GMarkFormulaDiagnostic {
        GMarkFormulaDiagnostic(
            ordinal: ordinal,
            row: row,
            column: column,
            isHeader: isHeader,
            container: container,
            reasonCode: reasonCode,
            backendRevision: backendRevision,
            duration: duration
        )
    }
}
