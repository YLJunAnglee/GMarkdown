//
//  GMarkPreprocessor.swift
//  GMarkdown
//
//  Created by GIKI on 2024/7/25.
//

import Foundation

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
        var result = markdown
        
        // LaTeX pattern: $$...$$, $...$, \[...\], \(...\)
        let pattern = "\\$\\$([\\s\\S]*?)\\$\\$|\\$([\\s\\S]*?)\\$|\\\\\\[([\\s\\S]*?)\\\\\\]|\\\\\\(([\\s\\S]*?)\\\\\\)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }
        
        let nsString = result as NSString
        let range = NSRange(location: 0, length: nsString.length)
        let matches = regex.matches(in: result, options: [], range: range).reversed()
        
        for match in matches {
            let matchRange = match.range
            let matchedString = nsString.substring(with: matchRange)
            
            // Skip if content is too large (potential security issue)
            guard matchedString.count < 3000 else { continue }
            
            let wrappedString = wrapLaTeX(
                matchedString,
                preserveLineStructure: isInsideMarkdownTable(matchRange, in: nsString)
            )
            result = (result as NSString).replacingCharacters(in: matchRange, with: wrappedString)
        }
        
        return result
    }
    
    private func wrapLaTeX(_ content: String, preserveLineStructure: Bool) -> String {
        // A newline inside a GFM table cell ends the current row. Keep even long
        // expressions inline here so preprocessing cannot change the table shape.
        if preserveLineStructure {
            return "<LaTex>\(content)</LaTex>"
        }

        let lines = content.components(separatedBy: .newlines)
        
        if lines.count > 1 || content.count > 30 {
            // Multi-line or long expressions get newlines for better formatting
            return "\n <LaTex>\(content)</LaTex> \n"
        } else {
            // Inline expressions
            return "<LaTex>\(content)</LaTex>"
        }
    }

    private func isInsideMarkdownTable(_ matchRange: NSRange, in markdown: NSString) -> Bool {
        let matchedString = markdown.substring(with: matchRange)
        guard matchedString.rangeOfCharacter(from: .newlines) == nil else {
            return false
        }

        let lineRange = markdown.lineRange(for: matchRange)
        let line = markdown.substring(with: lineRange)
        guard containsUnescapedPipe(line) else {
            return false
        }

        // A header row is followed immediately by the table delimiter row.
        let nextLineLocation = NSMaxRange(lineRange)
        if nextLineLocation < markdown.length {
            let nextLineRange = markdown.lineRange(
                for: NSRange(location: nextLineLocation, length: 0)
            )
            if isMarkdownTableDelimiter(markdown.substring(with: nextLineRange)) {
                return true
            }
        }

        // A body row belongs to a table when its preceding contiguous pipe rows
        // eventually reach the delimiter row.
        var previousLineLocation = lineRange.location
        while previousLineLocation > 0 {
            let previousLineRange = markdown.lineRange(
                for: NSRange(location: previousLineLocation - 1, length: 0)
            )
            let previousLine = markdown.substring(with: previousLineRange)

            if isMarkdownTableDelimiter(previousLine) {
                return true
            }
            guard containsUnescapedPipe(previousLine) else {
                return false
            }

            previousLineLocation = previousLineRange.location
        }

        return false
    }

    private func isMarkdownTableDelimiter(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard containsUnescapedPipe(trimmedLine) else {
            return false
        }

        var cells = splitOnUnescapedPipes(trimmedLine)
        if cells.first?.isEmpty == true {
            cells.removeFirst()
        }
        if cells.last?.isEmpty == true {
            cells.removeLast()
        }

        guard !cells.isEmpty else {
            return false
        }

        return cells.allSatisfy { cell in
            let delimiter = cell.trimmingCharacters(in: .whitespaces)
            guard !delimiter.isEmpty else { return false }

            let withoutLeadingColon = delimiter.first == ":" ? String(delimiter.dropFirst()) : delimiter
            let hyphens = withoutLeadingColon.last == ":"
                ? String(withoutLeadingColon.dropLast())
                : withoutLeadingColon

            return hyphens.count >= 3 && hyphens.allSatisfy { $0 == "-" }
        }
    }

    private func containsUnescapedPipe(_ text: String) -> Bool {
        splitOnUnescapedPipes(text).count > 1
    }

    private func splitOnUnescapedPipes(_ text: String) -> [String] {
        var result = [String]()
        var current = ""
        var consecutiveBackslashes = 0

        for character in text {
            if character == "|" && consecutiveBackslashes.isMultiple(of: 2) {
                result.append(current)
                current = ""
                consecutiveBackslashes = 0
                continue
            }

            current.append(character)
            if character == "\\" {
                consecutiveBackslashes += 1
            } else {
                consecutiveBackslashes = 0
            }
        }

        result.append(current)
        return result
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
