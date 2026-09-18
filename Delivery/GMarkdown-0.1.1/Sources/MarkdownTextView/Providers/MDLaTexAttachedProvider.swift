//
//  MDLaTexAttachedProvider.swift
//  GMarkdown
//
//  Created by GIKI on 2025/7/7.
//


import UIKit
import Markdown

class MDLaTexAttachedProvider: MarkdownAttachedViewProvider {
    
    private let style: Style
    private let laTexImage: UIImage
    private let mode: GMarkFormulaMode
    init(laTexImage: UIImage, style:Style, mode: GMarkFormulaMode = .block) {
        self.laTexImage = laTexImage
        self.style = style
        self.mode = mode
    }
    
    func instantiateView(for attachment: MarkdownAttachment, in behavior: MarkdownAttachingBehavior) -> UIView {
        // Each text view needs its own scrolling state, even for a shared attachment.
        if mode == .block { return MDLaTexScrollView(image: laTexImage) }
        let imageView = UIImageView(image: laTexImage)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }

    func bounds(for attachment: MarkdownAttachment, textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint) -> CGRect {
        let padding = (textContainer?.lineFragmentPadding ?? 0) * 2
        let widths = [style.maxContainerWidth,
                      (textContainer?.size.width ?? 0) - padding,
                      lineFrag.width - padding].filter { $0.isFinite && $0 > 0 }
        let available = widths.min() ?? laTexImage.size.width
        if mode == .inline {
            // Keep inline attachments in text flow. Only formulas wider than a full
            // line scale down; a normal formula near line end moves to the next line.
            let width = min(laTexImage.size.width, available)
            let scale = laTexImage.size.width > 0 ? width / laTexImage.size.width : 1
            return CGRect(x: 0, y: 0,
                          width: width, height: laTexImage.size.height * scale)
        }
        let width = available
        let height = laTexImage.size.height + (width < laTexImage.size.width ? MDLaTexScrollView.indicatorSpace : 0)
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
}

private final class MDLaTexScrollView: UIScrollView {
    static let indicatorSpace: CGFloat = 6
    private let formulaImageView: UIImageView
    private var previousViewportSize: CGSize = .zero

    init(image: UIImage) {
        formulaImageView = UIImageView(image: image)
        super.init(frame: .zero)
        addSubview(formulaImageView)
        contentInsetAdjustmentBehavior = .never
        showsHorizontalScrollIndicator = true
        showsVerticalScrollIndicator = false
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        bounces = true
        isDirectionalLockEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = formulaImageView.image else { return }
        formulaImageView.frame = CGRect(x: max(0, (bounds.width - image.size.width) / 2), y: 0,
                                       width: image.size.width, height: image.size.height)
        let newContentSize = CGSize(width: image.size.width, height: bounds.height)
        if contentSize != newContentSize { contentSize = newContentSize }
        let needsScrolling = image.size.width > bounds.width
        if isScrollEnabled != needsScrolling { isScrollEnabled = needsScrolling }
        // Scrolling also triggers layout. Clamping on every layout would cancel
        // UIKit's elastic overscroll and interrupt its deceleration animation.
        let viewportChanged = previousViewportSize != bounds.size
        previousViewportSize = bounds.size
        if viewportChanged && !isTracking && !isDragging && !isDecelerating {
            let offset = CGPoint(x: min(max(0, contentOffset.x), max(0, image.size.width - bounds.width)), y: 0)
            if contentOffset != offset { contentOffset = offset }
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let velocity = panGestureRecognizer.velocity(in: self)
            // Vertical drags over an equation should continue scrolling the chapter.
            if abs(velocity.x) <= abs(velocity.y) { return false }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}
