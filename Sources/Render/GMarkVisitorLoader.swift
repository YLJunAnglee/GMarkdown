//
//  GMarkPluginManager.swift
//  GMarkRender
//
//  Created by GIKI on 2024/7/29.
//

import Foundation
import UIKit

// ImageLoader
public protocol ImageLoader {
    func loadImage(from source: String, into imageView: UIImageView)
    /// Called when an image has source-provided fallback text, such as an HTML
    /// `<img alt="…">`. Existing loaders can rely on the default behavior.
    func loadImage(from source: String, into imageView: UIImageView, fallbackText: String?)
    func download(from source: String) async -> UIImage?
}

public extension ImageLoader {
    func loadImage(from source: String, into imageView: UIImageView, fallbackText _: String?) {
        loadImage(from: source, into: imageView)
    }
}

public protocol ReferLoader {
    func referQuote(from source: String, style: Style) -> NSAttributedString
    func referQuoteLink(from source: String) -> String?
    func referQuoteWebSite(from source: String) -> String?
    func referImage(from source: String, style: Style) -> NSAttributedString
}
