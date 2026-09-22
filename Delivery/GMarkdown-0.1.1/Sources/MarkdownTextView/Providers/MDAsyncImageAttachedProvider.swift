//
//  MDAsyncImageAttachedProvider.swift
//  GMarkdown
//
//  Created by 巩柯 on 2025/7/3.
//

import UIKit
import Markdown

class MDAsyncImageAttachedProvider: MarkdownAttachedViewProvider {

    private final class LayoutAwareImageView: UIImageView {
        var onImageChanged: (() -> Void)?

        override var image: UIImage? {
            didSet { onImageChanged?() }
        }
    }

    let url: String
    
    private lazy var imageView: LayoutAwareImageView = {
        let imageView = LayoutAwareImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.onImageChanged = { [weak self] in
            self?.invalidateAttachmentLayout()
        }
        return imageView
    }()
    
    var markup: Image?
    var style:Style?
    var imageloader: ImageLoader?
    let fallbackText: String?
    private weak var attachment: MarkdownAttachment?
    private weak var behavior: MarkdownAttachingBehavior?
    
    init(markup: Image, style:Style, imageloader: ImageLoader? = nil) {
        self.url = markup.source ?? ""
        self.markup = markup
        self.style = style
        self.imageloader = imageloader
        self.fallbackText = markup.plainText
    }
    
    func instantiateView(for attachment: MarkdownAttachment, in behavior: MarkdownAttachingBehavior) -> UIView {
        self.attachment = attachment
        self.behavior = behavior
        if let imageloader {
            imageloader.loadImage(from: url, into: self.imageView, fallbackText: fallbackText)
        } else {
            loadImageFromUrl()
        }
        return self.imageView
    }

    func bounds(for attachment: MarkdownAttachment, textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint) -> CGRect {
        guard let style = self.style else {
            return CGRect(origin: .zero, size: CGSize(width: 100, height: 100))
        }
        let horizontalPadding = (textContainer?.lineFragmentPadding ?? 0) * 2
        let widths = [
            style.maxContainerWidth,
            (textContainer?.size.width ?? 0) - horizontalPadding,
            lineFrag.width - horizontalPadding,
        ].filter { $0.isFinite && $0 > 0 }
        let width = widths.min() ?? style.maxContainerWidth

        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else {
            return CGRect(origin: .zero, size: CGSize(width: width, height: width))
        }
        return CGRect(origin: .zero, size: CGSize(width: width, height: width * image.size.height / image.size.width))
    }

    private func invalidateAttachmentLayout() {
        guard let attachment, let behavior, let textView = behavior.textView else { return }

        DispatchQueue.main.async {
            let fullRange = NSRange(location: 0, length: textView.textStorage.length)
            var attachmentRange: NSRange?
            textView.textStorage.enumerateAttribute(.attachment, in: fullRange) { value, range, stop in
                if let candidate = value as? MarkdownAttachment, candidate === attachment {
                    attachmentRange = range
                    stop.pointee = true
                }
            }
            guard let attachmentRange else { return }
            textView.layoutManager.invalidateLayout(forCharacterRange: attachmentRange, actualCharacterRange: nil)
            textView.layoutManager.ensureLayout(for: textView.textContainer)
            textView.setNeedsLayout()
            behavior.layoutAttachedSubviews()
        }
    }
    
    func loadImageFromUrl() {
        guard !url.isEmpty, let imageURL = URL(string: url) else {
            print("Invalid URL: \(url)")
            return
        }
        
        // 设置加载状态
        DispatchQueue.main.async {
            self.imageView.backgroundColor = UIColor.systemGray6
            self.imageView.contentMode = .scaleAspectFit
        }
        
        // 检查缓存
        let cache = URLCache.shared
        let request = URLRequest(url: imageURL)
        
        if let cachedResponse = cache.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            // 使用缓存的图片
            DispatchQueue.main.async {
                self.imageView.image = image
                self.imageView.backgroundColor = UIColor.clear
            }
            return
        }
        
        // 从网络加载
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.showErrorState()
                }
                return
            }
            
            guard let data = data,
                  let response = response,
                  let image = UIImage(data: data) else {
                print("Invalid image data")
                DispatchQueue.main.async {
                    self?.showErrorState()
                }
                return
            }
            
            // 缓存响应
            let cachedResponse = CachedURLResponse(response: response, data: data)
            cache.storeCachedResponse(cachedResponse, for: request)
            
            // 更新UI
            DispatchQueue.main.async {
                self?.imageView.image = image
                self?.imageView.backgroundColor = UIColor.clear
            }
        }
        
        task.resume()
    }

    private func showErrorState() {
        imageView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
    }

}
