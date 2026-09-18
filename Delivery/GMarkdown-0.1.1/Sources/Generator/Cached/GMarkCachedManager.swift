//
//  GMarkCachedManager.swift
//  GMarkdown
//
//  Created by GIKI on 2025/6/28.
//

import Foundation
import UIKit

public final class GMarkCachedManager {
    
    public static let shared = GMarkCachedManager()
    
    private init() {}
    
    private let latexCached = GMarkLRUCache<String, UIImage>(totalCostLimit: 24 * 1024 * 1024, countLimit: 30)
    
    private let attributedCached = GMarkLRUCache<String, NSAttributedString>(totalCostLimit: 8 * 1024 * 1024, countLimit: 50)
    
    // MARK: - Latex Cache
    
    public func setLatexCache(_ image: UIImage, for key: String) {
        let pixelCost = Int(max(1, image.size.width * image.size.height * image.scale * image.scale * 4))
        latexCached.setValue(image, forKey: key.cacheKey, cost: pixelCost)
    }
    
    public func getLatexCache(for key: String) -> UIImage? {
        return latexCached.value(forKey: key.cacheKey)
    }
    
    public func clearLatexCache() {
        latexCached.removeAllValues()
    }
    
    // MARK: - AttributedText Cache
    
    public func setAttributedTextCache(_ text: NSAttributedString, for key: String) {
        // UTF-16 storage is a conservative, deterministic lower bound for the
        // backing string. The cache also has a count limit and hard byte cap.
        let textCost = max(1, text.length * MemoryLayout<UInt16>.size)
        attributedCached.setValue(text, forKey: key.cacheKey, cost: textCost)
    }
    
    public func getAttributedTextCache(for key: String) -> NSAttributedString? {
        return attributedCached.value(forKey: key.cacheKey)
    }
    
    public func clearAttributedTextCache() {
        attributedCached.removeAllValues()
    }
    
    // MARK: - Clean All
    
    public func clearAllCache() {
        clearLatexCache()
        clearAttributedTextCache()
    }
}
    
