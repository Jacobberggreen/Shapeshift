import Foundation
import CoreGraphics

/// Colour scheme of the window chrome.
public enum WindowTheme: String, Codable, Sendable { case light, dark }

/// Look of a framed screenshot. Lengths are multiples of `EditContext.unit`, so they scale with the image.
public struct FrameStyle: Codable, Equatable, Sendable {
    public var cornerRadius: Double = 0
    public var borderColor: RGBAColor = .black
    public var borderWidth: Double = 0
    public var windowChrome: Bool = false
    public var theme: WindowTheme = .light
    public var title: String = ""
    /// Draws the traffic-light dots grey, as for an unfocused window.
    public var inactive: Bool = false
    public var shadowEnabled: Bool = false
    public var shadowOffsetX: Double = 0
    /// Vertical shadow offset; positive moves the shadow down.
    public var shadowOffsetY: Double = 0
    public var shadowBlur: Double = 0
    public var shadowColor: RGBAColor = .black
    public var shadowOpacity: Double = 0.3
    public var backgroundColor: RGBAColor = .clear
    public var margin: Double = 0
    public init() {}

    /// Tolerant decoding: any missing key keeps its default value.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var style = FrameStyle()
        if let v = try c.decodeIfPresent(type(of: style.cornerRadius).self, forKey: .cornerRadius) { style.cornerRadius = v }
        if let v = try c.decodeIfPresent(type(of: style.borderColor).self, forKey: .borderColor) { style.borderColor = v }
        if let v = try c.decodeIfPresent(type(of: style.borderWidth).self, forKey: .borderWidth) { style.borderWidth = v }
        if let v = try c.decodeIfPresent(type(of: style.windowChrome).self, forKey: .windowChrome) { style.windowChrome = v }
        if let v = try c.decodeIfPresent(type(of: style.theme).self, forKey: .theme) { style.theme = v }
        if let v = try c.decodeIfPresent(type(of: style.title).self, forKey: .title) { style.title = v }
        if let v = try c.decodeIfPresent(type(of: style.inactive).self, forKey: .inactive) { style.inactive = v }
        if let v = try c.decodeIfPresent(type(of: style.shadowEnabled).self, forKey: .shadowEnabled) { style.shadowEnabled = v }
        if let v = try c.decodeIfPresent(type(of: style.shadowOffsetX).self, forKey: .shadowOffsetX) { style.shadowOffsetX = v }
        if let v = try c.decodeIfPresent(type(of: style.shadowOffsetY).self, forKey: .shadowOffsetY) { style.shadowOffsetY = v }
        if let v = try c.decodeIfPresent(type(of: style.shadowBlur).self, forKey: .shadowBlur) { style.shadowBlur = v }
        if let v = try c.decodeIfPresent(type(of: style.shadowColor).self, forKey: .shadowColor) { style.shadowColor = v }
        if let v = try c.decodeIfPresent(type(of: style.shadowOpacity).self, forKey: .shadowOpacity) { style.shadowOpacity = v }
        if let v = try c.decodeIfPresent(type(of: style.backgroundColor).self, forKey: .backgroundColor) { style.backgroundColor = v }
        if let v = try c.decodeIfPresent(type(of: style.margin).self, forKey: .margin) { style.margin = v }
        self = style
    }
}

/// Pixel geometry of a framed image in CoreGraphics coordinates (origin bottom-left).
public struct FrameLayout: Equatable, Sendable {
    public let canvas: CGSize
    public let card: CGRect
    public let content: CGRect
    /// Title bar rectangle, or nil without window chrome.
    public let titleBar: CGRect?
    public let cornerRadius: CGFloat

    /// Lays out the canvas for an image of `imageSize`, growing it for the margin and shadow.
    public static func compute(imageSize: CGSize, style: FrameStyle, unit: CGFloat) -> FrameLayout {
        let barHeight: CGFloat = style.windowChrome ? (28 * unit).rounded() : 0
        let cardSize = CGSize(width: imageSize.width, height: imageSize.height + barHeight)

        let margin = CGFloat(style.margin) * unit
        var shadow = (left: CGFloat(0), right: CGFloat(0), top: CGFloat(0), bottom: CGFloat(0))
        if style.shadowEnabled {
            let blur = CGFloat(style.shadowBlur) * unit
            let dx = CGFloat(style.shadowOffsetX) * unit
            let dy = CGFloat(style.shadowOffsetY) * unit      // positive = down
            shadow = (max(0, blur - dx), max(0, blur + dx), max(0, blur - dy), max(0, blur + dy))
        }
        let left = ceil(max(margin, shadow.left)), right = ceil(max(margin, shadow.right))
        let top = ceil(max(margin, shadow.top)), bottom = ceil(max(margin, shadow.bottom))

        let canvas = CGSize(width: cardSize.width + left + right, height: cardSize.height + top + bottom)
        let card = CGRect(x: left, y: bottom, width: cardSize.width, height: cardSize.height)
        let content = CGRect(x: left, y: bottom, width: imageSize.width, height: imageSize.height)
        let bar: CGRect? = style.windowChrome
            ? CGRect(x: left, y: bottom + imageSize.height, width: imageSize.width, height: barHeight) : nil
        let radius = min(CGFloat(style.cornerRadius) * unit, min(cardSize.width, cardSize.height) / 2)
        return FrameLayout(canvas: canvas, card: card, content: content, titleBar: bar, cornerRadius: max(0, radius))
    }
}
