import Foundation
import UIKit

final class PreparedNativeMarkdownTableRender {
    let layout: GMarkTableLayout
    let columnCount: Int
    let bodyRowCount: Int
    let requiredSize: CGSize
    let warnings: [NativeMarkdownTableRenderWarning]
    let formulaDiagnostics: [GMarkFormulaDiagnostic]
    let formulaRenderDuration: TimeInterval

    init(
        layout: GMarkTableLayout,
        columnCount: Int,
        bodyRowCount: Int,
        requiredSize: CGSize,
        warnings: [NativeMarkdownTableRenderWarning],
        formulaDiagnostics: [GMarkFormulaDiagnostic],
        formulaRenderDuration: TimeInterval
    ) {
        self.layout = layout
        self.columnCount = columnCount
        self.bodyRowCount = bodyRowCount
        self.requiredSize = requiredSize
        self.warnings = warnings
        self.formulaDiagnostics = formulaDiagnostics
        self.formulaRenderDuration = formulaRenderDuration
    }

    func cacheCost(for key: NativeMarkdownTableRenderCacheKey) -> Int? {
        guard let formulaRasterByteCost = layout.markTable.formulaRasterByteCost else {
            return nil
        }
        return Self.addingCosts([
            key.retainedUTF8Cost,
            layout.markTable.contents.utf8.count,
            formulaRasterByteCost
        ])
    }

    private static func addingCosts(_ costs: [Int?]) -> Int? {
        var total = 0
        for cost in costs {
            guard let cost else { return nil }
            let (next, overflow) = total.addingReportingOverflow(cost)
            guard overflow == false else { return nil }
            total = next
        }
        return max(1, total)
    }
}

struct NativeMarkdownTableRenderCacheKey: Hashable {
    private static let currentRendererVersion = "native-table-v4-literal-formula"

    let markdown: String
    let containerWidthBits: UInt64
    let styleFingerprint: String
    let interfaceStyle: Int
    let accessibilityContrast: Int
    let interfaceLevel: Int
    let displayScaleBits: UInt64
    let formulaRendererIdentity: String
    let formulaFailurePolicy: String
    let rendererVersion: String

    init(
        markdown: String,
        containerWidth: CGFloat,
        style: MarkdownStyle,
        traits: UITraitCollection,
        displayScale: CGFloat,
        formulaRendererIdentity: String = "legacy-formula-renderer-v1",
        formulaFailurePolicy: String = "legacy-raw-formula"
    ) {
        self.markdown = markdown
        containerWidthBits = Double(containerWidth).bitPattern
        styleFingerprint = NativeMarkdownTableStyleFingerprint.make(style: style, traits: traits)
        interfaceStyle = traits.userInterfaceStyle.rawValue
        accessibilityContrast = traits.accessibilityContrast.rawValue
        interfaceLevel = traits.userInterfaceLevel.rawValue
        displayScaleBits = Double(displayScale).bitPattern
        self.formulaRendererIdentity = formulaRendererIdentity
        self.formulaFailurePolicy = formulaFailurePolicy
        rendererVersion = Self.currentRendererVersion
    }

    var retainedUTF8Cost: Int? {
        var total = 0
        for value in [markdown, styleFingerprint, formulaRendererIdentity,
                      formulaFailurePolicy, rendererVersion] {
            let (next, overflow) = total.addingReportingOverflow(value.utf8.count)
            guard overflow == false else { return nil }
            total = next
        }
        return total
    }
}

final class NativeMarkdownTableRenderCache {
    static let maximumTotalCost = 16 * 1_024 * 1_024
    static let maximumEntryCount = 32
    static let shared = NativeMarkdownTableRenderCache(
        totalCostLimit: maximumTotalCost,
        countLimit: maximumEntryCount
    )

    private let storage: GMarkLRUCache<NativeMarkdownTableRenderCacheKey,
        PreparedNativeMarkdownTableRender>

    init(totalCostLimit: Int,
         countLimit: Int,
         notificationCenter: NotificationCenter = .default) {
        storage = GMarkLRUCache(totalCostLimit: totalCostLimit,
                                countLimit: countLimit,
                                notificationCenter: notificationCenter)
    }

    func value(for key: NativeMarkdownTableRenderCacheKey) -> PreparedNativeMarkdownTableRender? {
        storage.value(forKey: key)
    }

    func insert(_ value: PreparedNativeMarkdownTableRender, for key: NativeMarkdownTableRenderCacheKey) {
        guard let cost = value.cacheCost(for: key),
              cost <= storage.totalCostLimit else { return }
        storage.setValue(value, forKey: key, cost: cost)
    }

    func removeAll() {
        storage.removeAllValues()
    }

    var snapshot: (entryCount: Int, totalCost: Int) {
        (storage.count, storage.totalCost)
    }
}

private enum NativeMarkdownTableStyleFingerprint {
    static func make(style: MarkdownStyle, traits: UITraitCollection) -> String {
        var fields: [String] = [
            style.useMPTextKit ? "1" : "0",
            style.hasStrikethrough ? "1" : "0",
            style.softbreakSeparator,
            String(style.linkUnderlineStyle.rawValue),
            style.needTruncation ? "1" : "0",
            String(style.maximumNumberOfLines)
        ]
        appendFonts(style.fonts, to: &fields)
        appendColors(style.colors, traits: traits, to: &fields)
        appendParagraph(style.paragraphStyle, to: &fields)
        appendCodeBlock(style.codeBlockStyle, traits: traits, to: &fields)
        appendTable(style.tableStyle, traits: traits, to: &fields)
        appendBlockquote(style.blockquoteStyle, traits: traits, to: &fields)
        appendImage(style.imageStyle, traits: traits, to: &fields)
        return fields.joined(separator: "|")
    }

    private static func appendFonts(_ fonts: FontStyle, to fields: inout [String]) {
        [fonts.current, fonts.h1, fonts.h2, fonts.h3, fonts.h4, fonts.h5, fonts.h6,
         fonts.paragraph, fonts.inlineCodeFont, fonts.quoteFont].forEach {
            fields.append(font($0))
        }
    }

    private static func appendColors(
        _ colors: ColorStyle,
        traits: UITraitCollection,
        to fields: inout [String]
    ) {
        [colors.current, colors.h1, colors.h2, colors.h3, colors.h4, colors.h5, colors.h6,
         colors.inlineCodeForeground, colors.inlineCodeBackground, colors.link,
         colors.linkUnderline, colors.paragraph, colors.quoteBackground,
         colors.quoteForeground].forEach {
            fields.append(color($0, traits: traits))
        }
    }

    private static func appendParagraph(_ style: ParagraphStyle, to fields: inout [String]) {
        fields += [
            number(style.lineSpacing),
            number(style.paragraphSpacing),
            String(style.alignment.rawValue),
            number(style.minimumLineHeight)
        ]
    }

    private static func appendCodeBlock(
        _ style: CodeBlockStyle,
        traits: UITraitCollection,
        to fields: inout [String]
    ) {
        fields += [
            style.customRender ? "1" : "0",
            font(style.font),
            color(style.foregroundColor, traits: traits),
            color(style.backgroundColor, traits: traits),
            number(style.cornerRadius),
            insets(style.padding),
            style.useHighlight ? "1" : "0"
        ]
    }

    private static func appendTable(
        _ style: TableStyle,
        traits: UITraitCollection,
        to fields: inout [String]
    ) {
        fields += [
            color(style.borderColor, traits: traits),
            number(style.borderWidth),
            insets(style.padding),
            color(style.headerBackgroundColor, traits: traits),
            color(style.headerTextColor, traits: traits),
            style.rowAlternateBackgroundColor.map { color($0, traits: traits) } ?? "nil",
            number(style.cellWidth),
            number(style.cellHeight),
            insets(style.cellPadding),
            number(style.cellMaximumWidth),
            String(style.maximumNumberOfLines)
        ]
    }

    private static func appendBlockquote(
        _ style: BlockquoteStyle,
        traits: UITraitCollection,
        to fields: inout [String]
    ) {
        fields += [
            color(style.backgroundColor, traits: traits),
            color(style.borderColor, traits: traits),
            number(style.borderWidth),
            font(style.font),
            color(style.textColor, traits: traits),
            insets(style.padding)
        ]
    }

    private static func appendImage(
        _ style: ImageStyle,
        traits: UITraitCollection,
        to fields: inout [String]
    ) {
        fields += [
            color(style.backgroundColor, traits: traits),
            color(style.borderColor, traits: traits),
            number(style.borderWidth),
            number(style.cornerRadius),
            insets(style.padding),
            number(style.size.width),
            number(style.size.height),
            String(style.contentMode.rawValue)
        ]
    }

    private static func font(_ font: UIFont) -> String {
        [font.fontName, number(font.pointSize), String(font.fontDescriptor.symbolicTraits.rawValue)]
            .joined(separator: ":")
    }

    private static func color(_ color: UIColor, traits: UITraitCollection) -> String {
        let resolved = color.resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return [red, green, blue, alpha].map(number).joined(separator: ",")
        }
        return resolved.cgColor.components?.map(number).joined(separator: ",")
            ?? String(describing: resolved)
    }

    private static func insets(_ value: UIEdgeInsets) -> String {
        [value.top, value.left, value.bottom, value.right].map(number).joined(separator: ",")
    }

    private static func number(_ value: CGFloat) -> String {
        String(Double(value).bitPattern)
    }
}
