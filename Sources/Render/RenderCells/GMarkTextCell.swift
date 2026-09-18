//
//  File.swift
//  GMarkdown
//
//  Created by GIKI on 2025/3/14.
//

import Foundation
import UIKit
import MPITextKit

class GMarkTextCell: UICollectionViewCell, MPILabelDelegate, ChunkCellConfigurable {
    public var handlerChain: GMarkHandlerChain?

    static let reuseIdentifier = "GMarkTextCell"

    private let label: MPILabel = {
        let label = MPILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        // MPITextKit owns the selection view, long-press/double-tap gestures,
        // handles and the system Copy action. Selection is therefore confined
        // to this label (and consequently to this single text chunk).
        label.isSelectable = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        label.delegate = self
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -0),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -0),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with chunk: GMarkChunk) {
        // A reused cell must never expose the previous chunk's selection/menu.
        label.hideMenu()
        label.selectedRange = NSRange(location: NSNotFound, length: 0)
        // MPILabel's copy: implementation reads attributedText, even when the
        // visual layout is supplied through textRenderer.
        label.attributedText = chunk.attributedText
        if let textRender = chunk.textRender {
            label.textRenderer = textRender
            return
        }
        label.textRenderer = nil
    }

    // MARK: - MPILabelDelegate

    func label(_: MPILabel, didInteractWith link: MPITextLink, forAttributedText attributedText: NSAttributedString, in characterRange: NSRange, interaction _: MPITextItemInteraction) {
        let attributed = attributedText.attributedSubstring(from: characterRange)

        if attributed.attribute(.attachment, at: 0, effectiveRange: nil) is NSTextAttachment {
            if let imageURL = link.value as? URL {
                handlerChain?.handle(.imageClicked(imageURL))
            }
        } else if let linkURL = link.value as? URL {
            // MPITextKit links are stored as `.MPILink` when the block
            // renderer is active; `.link` is only the fallback representation.
            handlerChain?.handle(.linkClicked(linkURL))
        } else if let linkURL = attributed.attribute(.link, at: 0, effectiveRange: nil) as? URL {
            handlerChain?.handle(.linkClicked(linkURL))
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.hideMenu()
        label.selectedRange = NSRange(location: NSNotFound, length: 0)
        label.textRenderer = nil
        label.attributedText = nil
    }
}
