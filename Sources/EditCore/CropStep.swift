import CoreGraphics

/// Crops the image to a rectangle in normalised 0...1 coordinates.
public struct CropStep: EditStep, Equatable, Sendable {
    /// The crop area, with a top-left origin.
    public var rect: NormalizedRect
    public init(rect: NormalizedRect) { self.rect = rect }

    /// Returns the cropped pixels; throws EditError.renderFailed if the rectangle cannot be cropped.
    public func apply(to image: CGImage, context: EditContext) throws -> CGImage {
        let pixels = rect.pixelRect(in: CGSize(width: image.width, height: image.height))
        guard let cropped = image.cropping(to: pixels) else { throw EditError.renderFailed("crop") }
        return cropped
    }
}
