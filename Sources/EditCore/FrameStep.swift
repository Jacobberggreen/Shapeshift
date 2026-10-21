import Foundation
import CoreGraphics
import CoreText

/// Edit step that draws the image onto a framed canvas with border, shadow and optional window chrome.
public struct FrameStep: EditStep, Equatable, Sendable {
    public var style: FrameStyle
    public init(style: FrameStyle) { self.style = style }

    /// Returns the framed image. The canvas keeps the source's RGB colour space when it has one, otherwise sRGB.
    public func apply(to image: CGImage, context: EditContext) throws -> CGImage {
        let unit = context.unit
        let layout = FrameLayout.compute(imageSize: CGSize(width: image.width, height: image.height),
                                         style: style, unit: unit)
        let width = Int(layout.canvas.width), height = Int(layout.canvas.height)
        // Keep the source's RGB colour space (e.g. Display P3 screenshots); anything else renders in sRGB.
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        var space = srgb
        if let source = image.colorSpace, source.model == .rgb { space = source }
        let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: bitmap)
                ?? CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                             space: srgb, bitmapInfo: bitmap) else {
            throw EditError.renderFailed("frame canvas \(width)x\(height)")
        }
        ctx.interpolationQuality = .high

        if style.backgroundColor.a > 0 {
            ctx.setFillColor(style.backgroundColor.cgColor)
            ctx.fill(CGRect(origin: .zero, size: layout.canvas))
        }

        let radius = layout.cornerRadius
        let cardPath = CGPath(roundedRect: layout.card, cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.saveGState()
        if style.shadowEnabled {
            let color = CGColor(srgbRed: style.shadowColor.r, green: style.shadowColor.g, blue: style.shadowColor.b,
                                alpha: min(max(style.shadowColor.a * style.shadowOpacity, 0), 1))
            ctx.setShadow(offset: CGSize(width: CGFloat(style.shadowOffsetX) * unit,
                                         height: -CGFloat(style.shadowOffsetY) * unit),   // CG y is up
                          blur: CGFloat(style.shadowBlur) * unit, color: color)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        }

        ctx.saveGState()
        ctx.addPath(cardPath)
        ctx.clip()
        ctx.draw(image, in: layout.content)
        drawTitleBar(in: ctx, layout: layout, unit: unit)
        ctx.restoreGState()

        let border = effectiveBorder(unit: unit)
        if border.width > 0 {
            let bw = border.width
            let inset = layout.card.insetBy(dx: bw / 2, dy: bw / 2)
            let r = max(0, radius - bw / 2)
            ctx.setStrokeColor(border.color)
            ctx.setLineWidth(bw)
            ctx.addPath(CGPath(roundedRect: inset, cornerWidth: min(r, min(inset.width, inset.height) / 2),
                               cornerHeight: min(r, min(inset.width, inset.height) / 2), transform: nil))
            ctx.strokePath()
        }

        if style.shadowEnabled { ctx.endTransparencyLayer() }
        ctx.restoreGState()

        guard let result = ctx.makeImage() else { throw EditError.renderFailed("frame") }
        return result
    }

    /// Window frames get the fixed hairline macOS draws around windows; plain frames use the user's border.
    private func effectiveBorder(unit: CGFloat) -> (width: CGFloat, color: CGColor) {
        if style.windowChrome {
            let color = style.theme == .dark
                ? CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22)
                : CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.18)
            return (unit, color)
        }
        return (CGFloat(style.borderWidth) * unit, style.borderColor.cgColor)
    }

    private func drawTitleBar(in ctx: CGContext, layout: FrameLayout, unit: CGFloat) {
        guard let bar = layout.titleBar else { return }
        let dark = style.theme == .dark
        ctx.setFillColor(dark ? CGColor(srgbRed: 0.20, green: 0.20, blue: 0.21, alpha: 1)
                              : CGColor(srgbRed: 0.93, green: 0.93, blue: 0.93, alpha: 1))
        ctx.fill(bar)

        let gray: CGFloat = dark ? 0.35 : 0.80
        let colors: [CGColor] = style.inactive
            ? Array(repeating: CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1), count: 3)
            : [CGColor(srgbRed: 1.0, green: 0.37, blue: 0.34, alpha: 1),
               CGColor(srgbRed: 1.0, green: 0.74, blue: 0.18, alpha: 1),
               CGColor(srgbRed: 0.16, green: 0.79, blue: 0.25, alpha: 1)]
        let diameter = 12 * unit
        for (i, color) in colors.enumerated() {
            let centreX = bar.minX + (18 + 20 * CGFloat(i)) * unit
            ctx.setFillColor(color)
            ctx.fillEllipse(in: CGRect(x: centreX - diameter / 2, y: bar.midY - diameter / 2,
                                       width: diameter, height: diameter))
        }

        guard !style.title.isEmpty else { return }
        let font = CTFontCreateUIFontForLanguage(.system, 13 * unit, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, 13 * unit, nil)
        let textGray: CGFloat = dark ? 0.80 : 0.30
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(srgbRed: textGray, green: textGray, blue: textGray, alpha: 1),
        ]
        let attributed = CFAttributedStringCreate(nil, style.title as CFString, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributed)
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        ctx.textPosition = CGPoint(x: bar.midX - textWidth / 2, y: bar.midY - 4.5 * unit)
        CTLineDraw(line, ctx)
    }
}
