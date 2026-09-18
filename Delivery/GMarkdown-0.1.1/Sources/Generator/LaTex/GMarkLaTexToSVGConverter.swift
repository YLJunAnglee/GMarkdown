//
//  GMarkLatexRender.swift
//  GMarkdown
//
//  Created by GIKI on 2025/3/15.
//

import UIKit
import MathJaxSwift

class GMarkLaTexToSVGConverter {
    // A reference to our MathJax instance
    private var mathjax: MathJax
    
    // Do not restrict MathJax to a hand-picked subset. Project books contain
    // chemistry and extensible-arrow commands: `\\ce` needs `mhchem`, while
    // `\\xlongequal` needs `extpfeil`. Both are included in MathJaxSwift's
    // complete package set; excluding them made `noundefined` render the raw
    // command in red.
    private let inputOptions = TeXInputProcessorOptions(
        loadPackages: TeXInputProcessorOptions.Packages.all,
        processEscapes: true
    )
    

    
    // The conversion options - use block rendering and increase container dimensions.
    private let convOptions: ConversionOptions = ConversionOptions(
        display: true,            // Enable block rendering for better layout and line breaks
        em: 100,
        ex: 1,
        containerWidth: 300,      // Increased container width for larger SVG
        lineWidth: 300,           // Increased line width to match container
        scale: 3.0
    )
    
    let outputOptionsv2 = SVGOutputProcessorOptions(
        scale: 1.0,                 // Adjust scale if necessary
        minScale: 1.0,
        mtextInheritFont: true,
        merrorInheritFont: true,
        unknownFamily: "serif",
        mathmlSpacing: true,
        skipAttributes: [:],
        exFactor: 1.0,
        displayAlign: "center",
        displayIndent: 0.0
    )
    
    let conversionOptions = ConversionOptions(
        display: true,
        em: 32,
        ex: 16,
        containerWidth: 600, // Set container width to 600 units
        lineWidth: 16,       // Set line width to match container width
        scale: 3.0            // Adjust scale as needed
    )
    
    let documentOptions = DocumentOptions(
        skipHtmlTags: DocumentOptions.defaultSkipHtmlTags,
        includeHtmlTags: DocumentOptions.defaultIncludedHtmlTags,
        enableEnrichment: true,
        enableComplexity: true,
        makeCollapsible: false, // Disable collapsible sections if not needed
        identifyCollapsible: false,
        enableExplorer: true,
        enableAssistiveMml: false,
        enableMenu: true,
        annotationTypes: DocumentOptions.defaultAnnotationTypes,
        a11y: DocumentOptions.defaultA11Y,
        sre: DocumentOptions.defaultSREOptions,
        menuOptions: DocumentOptions.defaultMenuOptions,
        safeOptions: DocumentOptions.defaultSafeOptions,
        enrichError: nil,
        compileError: nil,
        typesetError: nil
    )
    
    init() throws {
        // We only want to convert to SVG
        mathjax = try MathJax(preferredOutputFormat: .svg)
    }
    
    /// Converts the TeX input to SVG.
    ///
    /// - Parameter texInput: The input string.
    /// - Returns: SVG file data as a String.
    func convert(_ texInput: String, display: Bool = true) throws -> String {
        let conversionOptions = ConversionOptions(
            display: display, em: self.conversionOptions.em, ex: self.conversionOptions.ex,
            containerWidth: self.conversionOptions.containerWidth,
            lineWidth: self.conversionOptions.lineWidth, scale: self.conversionOptions.scale
        )
        let svg = try mathjax.tex2svg(texInput,
                                   css: false,
                                   assistiveMml: false,
                                   container: false,
                                   styles: false,
                                   conversionOptions: conversionOptions,
                                   documentOptions: documentOptions,
                                   inputOptions: inputOptions,
                                   outputOptions: outputOptionsv2)
        return try GMarkSVGTextOutliner.outline(GMarkSVGViewport.standalone(svg))
    }
}

/// MathJax numbered equations use a responsive root with nested SVGs for labels.
/// A standalone image has no containing HTML viewport: use MathJax's own minimum
/// width, preserving nested viewBoxes, aspect ratios, paths and label positioning.
enum GMarkSVGViewport {
    static func standalone(_ source: String) -> String {
        guard let rootRange = source.range(of: #"<svg\b[^>]*>"#, options: .regularExpression) else { return source }
        let root = String(source[rootRange])
        guard let widthRange = root.range(of: #"\swidth\s*=\s*["']100%["']"#, options: .regularExpression),
              let styleRange = root.range(of: #"\sstyle\s*=\s*"[^"]*""#, options: .regularExpression),
              let minimumRange = root[styleRange].range(of: #"(?:^|[;"\s])min-width\s*:\s*[0-9]+(?:\.[0-9]+)?ex\s*(?:;|")"#,
                                                       options: .regularExpression) else { return source }
        let minimum = String(root[minimumRange])
        guard let valueRange = minimum.range(of: #"[0-9]+(?:\.[0-9]+)?ex"#, options: .regularExpression) else { return source }
        let value = String(minimum[valueRange])
        guard let width = Double(value.dropLast(2)), width.isFinite, width > 0 else { return source }
        let fixedRoot = root.replacingCharacters(in: widthRange, with: " width=\"\(value)\"")
        #if DEBUG
        print("[FormulaSVG] viewport=standalone width=\(value) previous=100%")
        #endif
        let fixed = source.replacingCharacters(in: rootRange, with: fixedRoot)
        return explicitChildViewports(fixed, root: fixedRoot, width: width)
    }

    /// Numbered MathJax SVGs omit child width/height and rely on browser defaults.
    /// Give the known table/label viewports explicit dimensions for image decoders.
    private static func explicitChildViewports(_ source: String, root: String, width: Double) -> String {
        guard !root.contains("viewBox="),
              let heightAttribute = root.range(of: #"\sheight="[0-9]+(?:\.[0-9]+)?ex""#, options: .regularExpression),
              let number = root[heightAttribute].range(of: #"[0-9]+(?:\.[0-9]+)?"#, options: .regularExpression),
              let height = Double(root[number]), height.isFinite, height > 0,
              let regex = try? NSRegularExpression(pattern: #"<svg\b[^>]*>"#) else { return source }
        var result = source
        var count = 0
        let ranges = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        for match in ranges.dropFirst().reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let tag = String(result[range])
            guard tag.contains("data-table=\"true\"") || tag.contains("data-labels=\"true\"") else { continue }
            guard tag.range(of: #"\s(?:width|height|x|y)\s*="#, options: .regularExpression) == nil else { continue }
            let explicit = String(tag.dropLast()) + " width=\"\(width)\" height=\"\(height)\">"
            result.replaceSubrange(range, with: explicit)
            count += 1
        }
        #if DEBUG
        print("[FormulaSVG] explicitChildViewports=\(count) width=\(width) height=\(height)")
        #endif
        return result
    }
}
