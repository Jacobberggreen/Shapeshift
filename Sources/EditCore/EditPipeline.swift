import CoreGraphics

/// Edits to apply to an image in order: an optional crop, then an optional frame.
public struct EditPipeline: Equatable, Sendable {
    public var crop: CropStep?
    public var frame: FrameStep?
    public init(crop: CropStep? = nil, frame: FrameStep? = nil) { self.crop = crop; self.frame = frame }

    /// True when no crop or frame is set.
    public var isEmpty: Bool { crop == nil && frame == nil }

    /// `image` is the full-size image (`scale == 1`) or a downscaled copy at `scale` of `fullSize`.
    public func render(_ image: CGImage, fullSize: CGSize, scale: CGFloat) throws -> CGImage {
        var current = image
        var longSide = max(fullSize.width, fullSize.height)
        if let crop {
            current = try crop.apply(to: current, context: EditContext(scale: scale, referenceLongSide: Int(longSide)))
            longSide = max(fullSize.width * crop.rect.width, fullSize.height * crop.rect.height)
        }
        if let frame {
            current = try frame.apply(to: current, context: EditContext(scale: scale, referenceLongSide: Int(longSide.rounded())))
        }
        return current
    }
}
