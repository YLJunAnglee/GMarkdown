//
//  GMarkdownCodeView.swift
//  GMarkRender
//
//  Created by GIKI on 2024/7/25.
//

import MPITextKit
import UIKit

open class GMarkdownCodeView: UIView {
    public var container: UIView!
    public var topView: UIView!
    public var languageLabel: UILabel!
    public var scrollView: UIScrollView!
    public var codeCopyButton: UIButton!
    public var codeLabel: MPILabel!
    public var playButton: UIButton!

    @objc public var onCopy: ((String) -> Void)?

    public var markChunk: GMarkChunk? {
        didSet {
            guard let markChunk = markChunk else { return }
            languageLabel.text = markChunk.language
            if let textRender = markChunk.textRender {
                codeLabel.textRenderer = textRender
            }
            codeLabel.frame = CGRect(x: 0, y: 0, width: markChunk.codeSize.width, height: markChunk.codeSize.height)
            scrollView.contentSize = markChunk.codeSize

            container.layer.cornerRadius = markChunk.style.codeBlockStyle.cornerRadius
            container.backgroundColor = markChunk.style.codeBlockStyle.backgroundColor

            setNeedsLayout()

            playButton.isHidden = !(["mermaid", "html"].contains(markChunk.language.lowercased()))
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        let padding = markChunk?.style.codeBlockStyle.padding ?? UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        container.frame = CGRect(
            x: padding.left,
            y: padding.top,
            width: max(0, bounds.width - padding.left - padding.right),
            height: max(0, bounds.height - padding.top - padding.bottom)
        )
        topView.frame = CGRect(x: 0, y: 0, width: container.bounds.width, height: 36)

        let copyButtonWidth: CGFloat = 60
        codeCopyButton.frame = CGRect(
            x: max(0, topView.bounds.width - copyButtonWidth - 8),
            y: 2,
            width: copyButtonWidth,
            height: 32
        )

        let languageSize = languageLabel.intrinsicContentSize
        languageLabel.frame = CGRect(
            x: 8,
            y: (topView.bounds.height - languageSize.height) / 2,
            width: languageSize.width,
            height: languageSize.height
        )
        playButton.frame = CGRect(x: languageLabel.frame.maxX + 2, y: 6, width: 24, height: 24)

        scrollView.frame = CGRect(
            x: 8,
            y: 40,
            width: max(0, container.bounds.width - 16),
            height: max(0, container.bounds.height - 48)
        )
    }

    private func setupViews() {
        backgroundColor = .white

        container = UIView()
        container.backgroundColor = UIColor(hex: "#E7E7E7")
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true
        container.layer.borderColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1).cgColor
        container.layer.borderWidth = 1
        addSubview(container)

        topView = UIView()
        topView.backgroundColor = UIColor(hex: "#FFFFFF")
        container.addSubview(topView)

        _ = NSMutableParagraphStyle()
        languageLabel = UILabel()
        languageLabel.font = UIFont(name: "PingFangSC-Medium", size: 14)
        languageLabel.textColor = UIColor(hex: "#000000")
        topView.addSubview(languageLabel)

        codeCopyButton = UIButton(type: .custom)
        codeCopyButton.addTarget(self, action: #selector(codeCopyAction), for: .touchUpInside)
        codeCopyButton.setTitle("Copy", for: .normal)
        codeCopyButton.setTitleColor(UIColor(hex: "#666666"), for: .normal)
        codeCopyButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        codeCopyButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        codeCopyButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 2, bottom: 0, right: -2)
        codeCopyButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: 2)
        codeCopyButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        topView.addSubview(codeCopyButton)

        scrollView = UIScrollView()
        container.addSubview(scrollView)

        codeLabel = MPILabel()
        codeLabel.numberOfLines = 0
        scrollView.addSubview(codeLabel)

        playButton = UIButton(type: .custom)
        playButton.addTarget(self, action: #selector(playButtonAction), for: .touchUpInside)
        playButton.isHidden = true
        topView.addSubview(playButton)

        setDefaultCopyImage()
        setDefaultPlayImage()
    }

    private func imageFromBase64(base64String: String) -> UIImage? {
        if let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) {
            let image = UIImage(data: imageData)
            return image
        }
        return nil
    }

    private func setDefaultCopyImage() {
        let base64String = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAK5JREFUSEvtlUEOhCAMRVsuNq4b7uTMnQhrvBg1kmAYQW2EmUgia+ijj/SD8OOFS32t9eC9H2pZSilnjHFpnQAgojcAjLUAAPhYa5da6/o/ABEdM0/SbhDxxcxRr6iDbNMRbKO3c0BJb+mRaxRlNvsCJIrWmWrdQdBLRBxdPYBtjt1AUYssOntkac6V9okUtQfs/WhpFEvUxR8tU7R35bMoPjj3PWhCwCV1YZK7Bszzbc5HrUgLQwAAAABJRU5ErkJggg=="
        if let image = imageFromBase64(base64String: base64String) {
            let resizedImage = image.resized(to: CGSize(width: 12, height: 12))
            codeCopyButton.setImage(resizedImage, for: .normal)
        }
    }

    private func setDefaultPlayImage() {
        let base64String = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAW5JREFUSEu1VttxxCAMDBSD3UVylSWu7JwubIpBiTTIs2DxyNyED/tuAO3qtbJ766x1XT94m4g+81v+O+d2Ivrm3zHGr54NZ22yYTZKRGJwYm0toBsAG08pPdGoMvbe7yklBBXPYN2ACoAQAruLl5rM1OjozgWAB5mxc247jmOfCI8cWZblqSH13j/0LgKQJvA8z8esYTxngQgAskf0V0A4CkxUAYT9bwWaMQ8h8P4wH2wAi4TJOmQfYzTLNgMIAa6kUW40VDVAkyEAaNS63iiAFAsk5i8AXSANkwCg+61uNDyo81+QwzxcAL3q6QFYPVMA/HuIMCGtBqs90Bpv9QlU5ubQnVGZzkoIRqUAaDUTX5jVprqvpLFQQ1pezMpGnVMBKLKeNWTWIJ6zVOGShmrQTOlOyziG+uWBY4zXgtxN3IwJJSLHDxY6ZV1/COT9a9DoOVM96xkxykevfJsA1czlT5V3HYlsME8/8awn3z9KOVH6hlcOVgAAAABJRU5ErkJggg=="
        if let image = imageFromBase64(base64String: base64String) {
            let resizedImage = image.resized(to: CGSize(width: 12, height: 12))
            playButton.setImage(resizedImage, for: .normal)
        }
    }

    @objc private func playButtonAction() {
        guard let markChunk = markChunk else { return }
        let language = markChunk.language.lowercased()
        if language == "mermaid" {
            GMarkMermaidBrowser.modal(with: markChunk.codeSource)
        } else if language == "html" {
            GMarkHtmlBrowser.modal(with: markChunk.codeSource)
        }
    }

    @objc private func codeCopyAction() {
        guard let markChunk = markChunk else { return }
        UIPasteboard.general.string = markChunk.codeSource
        if  markChunk.codeSource.isEmpty {
            onCopy?(markChunk.codeSource)
        }
    }
}

// Add this extension to UIImage
extension UIImage {
    func resized(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
