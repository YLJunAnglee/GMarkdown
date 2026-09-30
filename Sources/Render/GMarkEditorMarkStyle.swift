import UIKit

/// Shared presentation policy for the supported editor mark. Keep parser fallback
/// and custom drawing consistent; business interactions do not belong here.
enum GMarkEditorMarkStyle {
    static let color = UIColor(hex: "#4F5CE7")
    static let fallbackUnderline = NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue
    static let gap: CGFloat = 2
    static let thickness: CGFloat = 1.2
    static let dotPitch: CGFloat = 3.5
    static let minimumLineSpacing = ceil(gap + thickness + 1)
}
