import UIKit

/// A rendering failure that the component can identify. The source block index
/// refers to the top-level Markdown block passed to `ChunkGenerator`, not a
/// collection-view cell index. Process each business block with a distinct
/// `GMarkChunkGenerator.identifier` for each content revision when the host
/// needs business-level identity and stale-result filtering.
public struct GMarkRenderIssue {
    public enum Cause {
        case formulaRenderFailed
        case imageSourceMissing
        case imageRenderingDisabled
        case imageLoaderMissing
        case imageLoadFailed
        case standaloneImageUnsupported
        case htmlImageReducedToAlternateText
    }

    public enum DisplayedFallback {
        case sourceText
        case imageAlternateText
        case imagePlaceholder
        case empty
    }

    public let documentIdentifier: String
    public let sourceBlockIndex: Int
    public let cause: Cause
    public let displayedFallback: DisplayedFallback

    public init(documentIdentifier: String,
                sourceBlockIndex: Int,
                cause: Cause,
                displayedFallback: DisplayedFallback) {
        self.documentIdentifier = documentIdentifier
        self.sourceBlockIndex = sourceBlockIndex
        self.cause = cause
        self.displayedFallback = displayedFallback
    }
}

/// The image loader reports the final visible outcome once per request. An
/// existing `ImageLoader` remains valid, but its asynchronous failures cannot
/// be observed by GMarkdown until it adopts this protocol.
public enum GMarkImageLoadOutcome {
    case success
    case failedShowingAlternateText
    case failedShowingPlaceholder
    case failedShowingEmptyImage
}

public protocol GMarkReportingImageLoader: ImageLoader {
    func loadImage(from source: String,
                   into imageView: UIImageView,
                   fallbackText: String?,
                   completion: @escaping (GMarkImageLoadOutcome) -> Void)
}

/// Keeps reporting scoped to the top-level source block, including images in
/// table cells. It never sends image URLs or source text to the issue callback.
final class GMarkObservedImageLoader: ImageLoader {
    private let base: ImageLoader
    private let report: (GMarkImageLoadOutcome) -> Void

    init(base: ImageLoader, report: @escaping (GMarkImageLoadOutcome) -> Void) {
        self.base = base
        self.report = report
    }

    func loadImage(from source: String, into imageView: UIImageView) {
        loadImage(from: source, into: imageView, fallbackText: nil)
    }

    func loadImage(from source: String, into imageView: UIImageView, fallbackText: String?) {
        if let reporting = base as? GMarkReportingImageLoader {
            let report = self.report
            reporting.loadImage(from: source, into: imageView, fallbackText: fallbackText) { outcome in
                report(outcome)
            }
        } else {
            base.loadImage(from: source, into: imageView, fallbackText: fallbackText)
        }
    }

    func download(from source: String) async -> UIImage? {
        await base.download(from: source)
    }
}
