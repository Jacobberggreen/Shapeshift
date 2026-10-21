import Foundation
import CoreGraphics
import EditCore

/// Aspect-ratio presets for the crop tool.
enum CropAspect: String, CaseIterable, Identifiable {
    case free, square, fourThree, sixteenNine, original
    var id: String { rawValue }
    var title: String {
        switch self {
        case .free: return "Free"
        case .square: return "1:1"
        case .fourThree: return "4:3"
        case .sixteenNine: return "16:9"
        case .original: return "Original"
        }
    }
    /// Width / height in pixels; nil when unconstrained.
    func ratio(imageSize: CGSize) -> CGFloat? {
        switch self {
        case .free: return nil
        case .square: return 1
        case .fourThree: return 4.0 / 3
        case .sixteenNine: return 16.0 / 9
        case .original: return imageSize.width / imageSize.height
        }
    }
}

/// The four corners of the crop rectangle that can be dragged.
enum CropHandle { case topLeft, topRight, bottomLeft, bottomRight }

/// Pure crop-rectangle geometry used by the editor, such as the initial rectangle for an aspect ratio.
enum CropGeometry {
    static func initial(aspect: CropAspect, imageSize: CGSize) -> NormalizedRect {
        guard let ratio = aspect.ratio(imageSize: imageSize) else {
            return NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        }
        var w = 0.8 * imageSize.width
        var h = w / ratio
        if h > 0.8 * imageSize.height { h = 0.8 * imageSize.height; w = h * ratio }
        let nw = Double(w / imageSize.width), nh = Double(h / imageSize.height)
        return NormalizedRect(x: (1 - nw) / 2, y: (1 - nh) / 2, width: nw, height: nh)
    }

    static func moved(_ rect: NormalizedRect, by delta: CGSize) -> NormalizedRect {
        var r = rect
        r.x = min(max(rect.x + Double(delta.width), 0), 1 - rect.width)
        r.y = min(max(rect.y + Double(delta.height), 0), 1 - rect.height)
        return r
    }

    /// Note: with a `ratio`, the side derived from the ratio may end up below `minSide`
    /// (the ratio and image bounds take priority over the minimum).
    static func resized(_ rect: NormalizedRect, handle: CropHandle, to point: CGPoint, ratio: CGFloat?,
                        imageSize: CGSize, minSide: Double = 0.05) -> NormalizedRect {
        let anchor: CGPoint
        switch handle {
        case .topLeft: anchor = CGPoint(x: rect.x + rect.width, y: rect.y + rect.height)
        case .topRight: anchor = CGPoint(x: rect.x, y: rect.y + rect.height)
        case .bottomLeft: anchor = CGPoint(x: rect.x + rect.width, y: rect.y)
        case .bottomRight: anchor = CGPoint(x: rect.x, y: rect.y)
        }
        let px = min(max(Double(point.x), 0), 1), py = min(max(Double(point.y), 0), 1)
        let ax = Double(anchor.x), ay = Double(anchor.y)
        var goesRight = px >= ax, goesDown = py >= ay
        // Flip to the other side of the anchor when the pointer's side has less than minSide of room.
        if (goesRight ? 1 - ax : ax) < minSide { goesRight.toggle() }
        if (goesDown ? 1 - ay : ay) < minSide { goesDown.toggle() }
        let maxW = goesRight ? 1 - ax : ax
        let maxH = goesDown ? 1 - ay : ay

        var w = max(abs(px - ax), minSide)
        var h = max(abs(py - ay), minSide)
        if let ratio {
            let W = Double(imageSize.width), H = Double(imageSize.height), r = Double(ratio)
            h = w * W / (r * H)                       // height implied by the width
            if h > maxH { h = maxH; w = h * r * H / W }
            if w > maxW { w = maxW; h = w * W / (r * H) }
        } else {
            w = min(w, maxW); h = min(h, maxH)
        }
        return NormalizedRect(x: goesRight ? ax : ax - w, y: goesDown ? ay : ay - h, width: w, height: h)
    }
}
