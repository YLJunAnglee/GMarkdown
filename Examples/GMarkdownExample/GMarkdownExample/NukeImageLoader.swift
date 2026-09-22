//
//  NukeImageLoader.swift
//  GMarkdownExample
//
//  Created by GIKI on 2024/8/1.
//

import Foundation
import UIKit
import Nuke
import NukeExtensions
import GMarkdown

class NukeImageLoader: ImageLoader {
    private static let longImageFixtureSource = "gmarkdown-demo://acceptance-long-image"

    private static let longImageFixture: UIImage = {
        let size = CGSize(width: 600, height: 2_400)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.systemIndigo.withAlphaComponent(0.12).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            for section in 0 ..< 12 {
                let y = CGFloat(section) * 200
                UIColor.systemBlue.withAlphaComponent(section.isMultiple(of: 2) ? 0.22 : 0.08).setFill()
                context.cgContext.fill(CGRect(x: 0, y: y, width: size.width, height: 200))
                let text = "Long image acceptance · section \(section + 1)"
                text.draw(at: CGPoint(x: 36, y: y + 82), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                    .foregroundColor: UIColor.label,
                ])
            }
        }
    }()

    @MainActor func loadImage(from source: String, into imageView: UIImageView) {
        loadImage(from: source, into: imageView, fallbackText: nil)
    }

    @MainActor func loadImage(from source: String, into imageView: UIImageView, fallbackText: String?) {
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.viewWithTag(947_001)?.removeFromSuperview()
        if source == Self.longImageFixtureSource {
            imageView.image = Self.longImageFixture
            return
        }
        guard let url = URL(string: source) else {
            showFallback(text: fallbackText, in: imageView)
            return
        }

        let options = ImageLoadingOptions(
            placeholder: nil,
            transition: .fadeIn(duration: 0.33)
        )
        NukeExtensions.loadImage(with: url, options: options, into: imageView) { [weak imageView] result in
            guard case .failure = result else { return }
            Task { @MainActor [weak imageView] in
                guard let imageView else { return }
                self.showFallback(text: fallbackText, in: imageView)
            }
        }
    }

    @MainActor private func showFallback(text: String?, in imageView: UIImageView) {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        imageView.image = nil
        imageView.backgroundColor = .clear
        imageView.viewWithTag(947_001)?.removeFromSuperview()

        let label = UILabel()
        label.tag = 947_001
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -4)
        ])
    }
    
    func download(from source: String) async -> UIImage? {
        if source == Self.longImageFixtureSource {
            return Self.longImageFixture
        }
        do {
            let request = ImageRequest(
                url: URL(string: source),
                priority: .high
            )
            let image = try await ImagePipeline.shared.image(for: request)
            return image
        } catch {
            print("Error downloading image: \(error)")
            return nil
        }
    }
    
}

extension UIImage {
    
    /// 创建一个纯色的图片
    /// - Parameters:
    ///   - color: 图片的颜色
    ///   - size: 图片的尺寸
    /// - Returns: 生成的纯色图片
    static func image(withColor color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}
