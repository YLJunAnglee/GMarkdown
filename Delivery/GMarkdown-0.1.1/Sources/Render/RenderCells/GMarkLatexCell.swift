//
//  File.swift
//  GMarkdown
//
//  Created by GIKI on 2025/3/14.
//

import Foundation
import UIKit
import MPITextKit

class GMarkLatexCell: UICollectionViewCell, ChunkCellConfigurable, UIGestureRecognizerDelegate {
    static let reuseIdentifier = "GMarkLatexCell"
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        return sv
    }()

    private let latexImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var sourceImage: UIImage?
    private var imageTopPadding: CGFloat = 0
    private lazy var horizontalPanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleHorizontalPan(_:)))
        gesture.delegate = self
        gesture.cancelsTouchesInView = false
        return gesture
    }()
    
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required public init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = contentView.bounds
        guard let image = latexImageView.image else { return }
        let left = max(0, (scrollView.bounds.width - image.size.width) * 0.5)
        latexImageView.frame = CGRect(
            x: left,
            y: imageTopPadding,
            width: image.size.width,
            height: image.size.height
        )
        scrollView.contentSize = CGSize(
            width: max(image.size.width, scrollView.bounds.width),
            height: imageTopPadding + image.size.height
        )
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        applyAppearance()
    }

    func setupUI() {
        contentView.addSubview(scrollView)
        scrollView.addSubview(latexImageView)
        contentView.addGestureRecognizer(horizontalPanGesture)
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.isDirectionalLockEnabled = true
        scrollView.frame = contentView.bounds
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === horizontalPanGesture,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = panGesture.velocity(in: contentView)
        return abs(velocity.x) > abs(velocity.y) && scrollView.contentSize.width > scrollView.bounds.width
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === horizontalPanGesture else { return false }
        return otherGestureRecognizer.view is UIScrollView
    }

    @objc private func handleHorizontalPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: contentView)
        guard translation.x != 0 else { return }
        let minimumOffset = -scrollView.adjustedContentInset.left
        let maximumOffset = max(
            minimumOffset,
            scrollView.contentSize.width - scrollView.bounds.width + scrollView.adjustedContentInset.right
        )
        let nextX = min(max(scrollView.contentOffset.x - translation.x, minimumOffset), maximumOffset)
        scrollView.setContentOffset(CGPoint(x: nextX, y: scrollView.contentOffset.y), animated: false)
        gestureRecognizer.setTranslation(.zero, in: contentView)
    }
    
    func configure(with chunk: GMarkChunk) {
        scrollView.setContentOffset(.zero, animated: false)
        if let image = chunk.latexImage {
            sourceImage = image
            imageTopPadding = chunk.style.codeBlockStyle.padding.top
            latexImageView.isHidden = false
            applyAppearance()
            setNeedsLayout()
        } else {
            sourceImage = nil
            latexImageView.image = nil
            latexImageView.isHidden = true
            scrollView.contentSize = .zero
        }
    }

    private func applyAppearance() {
        guard let sourceImage else { return }
        let scale = UIFontMetrics.default.scaledValue(for: 1, compatibleWith: traitCollection)
        let targetSize = CGSize(width: sourceImage.size.width * scale, height: sourceImage.size.height * scale)
        let scaledImage = abs(scale - 1) > 0.001 ? sourceImage.resized(to: targetSize) : sourceImage
        if traitCollection.userInterfaceStyle == .dark {
            latexImageView.image = scaledImage.withTintColor(.label, renderingMode: .alwaysOriginal)
        } else {
            latexImageView.image = scaledImage
        }
        setNeedsLayout()
    }
}
