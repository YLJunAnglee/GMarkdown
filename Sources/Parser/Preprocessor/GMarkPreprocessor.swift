//
//  GMarkPreprocessor.swift
//  GMarkdown
//
//  Created by GIKI on 2024/7/25.
//

import Foundation
import Markdown

/// Protocol for markdown preprocessors
public protocol GMarkPreprocessorProtocol {
    var priority: Int { get }
    func process(_ markdown: String) -> String
}

/// Main preprocessor manager that handles all preprocessing steps
public class GMarkPreprocessor {
    
    private var processors: [GMarkPreprocessorProtocol] = []
    
    public init() {
        setupDefaultProcessors()
    }
    
    /// Add a custom preprocessor
    public func addProcessor(_ processor: GMarkPreprocessorProtocol) {
        processors.append(processor)
        processors.sort { $0.priority < $1.priority }
    }
    
    /// Remove a processor by type
    public func removeProcessor<T: GMarkPreprocessorProtocol>(ofType type: T.Type) {
        processors.removeAll { processor in
            return processor is T
        }
    }
    
    /// Process markdown through all registered preprocessors
    public func process(_ markdown: String) -> String {
        return processors.reduce(markdown) { result, processor in
            return processor.process(result)
        }
    }
}

// MARK: - Default Preprocessor Implementations

/// Preprocessor for LaTeX mathematical expressions
public class LaTeXPreprocessor: GMarkPreprocessorProtocol {
    
    public let priority: Int = 10
    
    public init() {}
    
    public func process(_ markdown: String) -> String {
        return processLaTeX(markdown)
    }
    
    private func processLaTeX(_ markdown: String) -> String {
        // Some exports emit a display `aligned` environment as `$...$$`.
        // Repair only that unambiguous one-character delimiter mismatch before
        // tokenization; never add delimiters to arbitrary prose or TeX text.
        var result = recoverMalformedAlignedDisplayMath(in: markdown)
        
        // LaTeX pattern: $$...$$, $...$, \[...\], \(...\)
        let pattern = "\\$\\$([\\s\\S]*?)\\$\\$|\\$([\\s\\S]*?)\\$|\\\\\\[([\\s\\S]*?)\\\\\\]|\\\\\\(([\\s\\S]*?)\\\\\\)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }
        
        let nsString = result as NSString
        let range = NSRange(location: 0, length: nsString.length)
        let codeRanges = protectedCodeRanges(in: result)
        let searchSource = NSMutableString(string: result)
        for codeRange in codeRanges.reversed() {
            searchSource.replaceCharacters(in: codeRange, with: String(repeating: " ", count: codeRange.length))
        }
        let matches = regex.matches(in: searchSource as String, options: [], range: range).reversed()
        
        for match in matches {
            let matchRange = match.range
            guard !codeRanges.contains(where: { NSIntersectionRange($0, matchRange).length > 0 }) else { continue }
            let matchedString = nsString.substring(with: matchRange)
            
            // Skip if content is too large (potential security issue)
            guard matchedString.count < 3000 else { continue }
            
            let wrappedString = wrapLaTeX(matchedString)
            result = (result as NSString).replacingCharacters(in: matchRange, with: wrappedString)
        }
        
        return result
    }

    private func recoverMalformedAlignedDisplayMath(in source: String) -> String {
        // A single opening dollar followed by `\\begin{aligned}` and a double
        // closing dollar cannot be a valid paired delimiter. Treat it as the
        // display form the exporter evidently intended, while leaving the
        // original source data untouched.
        // A following word character can instead mean two adjacent `$...$`
        // formulas. Only recover at a Markdown/table boundary.
        let pattern = "(?<!\\$)\\$(\\\\begin\\{aligned\\}[\\s\\S]*?\\\\end\\{aligned\\})\\$\\$(?=\\s|\\||$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }
        let codeRanges = protectedCodeRanges(in: source)
        let range = NSRange(location: 0, length: (source as NSString).length)
        var result = source
        for match in regex.matches(in: source, range: range).reversed() {
            guard !codeRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { continue }
            let body = (source as NSString).substring(with: match.range(at: 1))
            result = (result as NSString).replacingCharacters(in: match.range, with: "$$\(body)$$")
        }
        return result
    }
    
    private func wrapLaTeX(_ content: String) -> String {
        // CommonMark resolves references into literal Text without reinterpreting their
        // decoded punctuation. This also keeps pipes/newlines out of table syntax.
        let literal = content.unicodeScalars.map { "&#\($0.value);" }.joined()
        return "<LaTex>\(literal)</LaTex>"
    }

    private func protectedCodeRanges(in source: String) -> [NSRange] {
        let bytes = Array(source.utf8)
        var starts = [0]
        for index in bytes.indices where bytes[index] == 10 { starts.append(index + 1) }
        func offset(_ location: SourceLocation) -> Int? {
            guard location.line > 0, location.line <= starts.count, location.column > 0 else { return nil }
            let value = starts[location.line - 1] + location.column - 1
            return value <= bytes.count ? value : nil
        }
        var ranges: [NSRange] = []
        func collect(_ node: Markup) {
            if node is CodeBlock || node is InlineCode {
                if let range = node.range, let start = offset(range.lowerBound),
                   let end = offset(range.upperBound), end >= start {
                    let prefix = String(decoding: bytes[..<start], as: UTF8.self)
                    let content = String(decoding: bytes[start..<end], as: UTF8.self)
                    ranges.append(NSRange(location: prefix.utf16.count, length: content.utf16.count))
                }
                return
            }
            for child in node.children { collect(child) }
        }
        collect(Document(parsing: source))
        return ranges
    }

}

/// Preprocessor for code blocks formatting
public class CodeBlockPreprocessor: GMarkPreprocessorProtocol {
    
    public let priority: Int = 20
    
    public init() {}
    
    public func process(_ markdown: String) -> String {
        return processCodeBlocks(markdown)
    }
    
    private func processCodeBlocks(_ markdown: String) -> String {
        // Ensure code blocks are on separate lines
        let result = markdown.replacingOccurrences(of: "```", with: "\n```")
        return result
    }
}

/// Preprocessor for image tags formatting
public class ImagePreprocessor: GMarkPreprocessorProtocol {
    
    public let priority: Int = 30
    
    public init() {}
    
    public func process(_ markdown: String) -> String {
        return processImages(markdown)
    }
    
    private func processImages(_ markdown: String) -> String {
        var result = markdown
        
        // Convert <img></img> tags to markdown format with proper spacing
        result = result.replacingOccurrences(of: "<img>", with: "\n\n ![](")
        result = result.replacingOccurrences(of: "</img>", with: ") \n\n")
        
        return result
    }
}
