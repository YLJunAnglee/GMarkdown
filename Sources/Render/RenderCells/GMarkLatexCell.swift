//
//  File.swift
//  GMarkdown
//
//  Created by GIKI on 2025/3/14.
//

import Foundation
import UIKit
import MPITextKit

class GMarkLatexCell: UICollectionViewCell, ChunkCellConfigurable {
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
        scrollView.frame = contentView.bounds
    }
    
    func configure(with chunk: GMarkChunk) {
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
