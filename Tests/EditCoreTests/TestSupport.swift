import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

final class TemporaryDirectory {
    let url: URL
    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shapeshift-edit-tests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func file(_ name: String) -> URL { url.appendingPathComponent(name) }
    deinit { try? FileManager.default.removeItem(at: url) }
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func makeImage(width: Int, height: Int, draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx)
    return ctx.makeImage()!
}

func solidImage(width: Int, height: Int, red: CGFloat = 1, green: CGFloat = 0, blue: CGFloat = 0) -> CGImage {
    makeImage(width: width, height: height) { ctx in
        ctx.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

/// Visual quadrants: top-left red, top-right green, bottom-left blue, bottom-right white.
func quadrantImage(width: Int, height: Int) -> CGImage {
    makeImage(width: width, height: height) { ctx in
        let w = CGFloat(width) / 2, h = CGFloat(height) / 2
        let quads: [(CGRect, CGColor)] = [
            (CGRect(x: 0, y: h, width: w, height: h), CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)),   // top-left (CG y is up)
            (CGRect(x: w, y: h, width: w, height: h), CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)),   // top-right
            (CGRect(x: 0, y: 0, width: w, height: h), CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)),   // bottom-left
            (CGRect(x: w, y: 0, width: w, height: h), CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)),   // bottom-right
        ]
        for (rect, color) in quads { ctx.setFillColor(color); ctx.fill(rect) }
    }
}

/// Deterministic pseudo-random noise (incompressible, so JPEG sizes respond to quality).
func noiseImage(width: Int, height: Int, seed: UInt64 = 42) -> CGImage {
    var state = seed
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for i in stride(from: 0, to: bytes.count, by: 4) {
        for c in 0..<3 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            bytes[i + c] = UInt8(truncatingIfNeeded: state >> 33)
        }
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                   space: sRGB, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

struct Pixel: Equatable { let r: UInt8, g: UInt8, b: UInt8, a: UInt8 }

func rgbaBytes(_ image: CGImage) -> [UInt8] {
    let w = image.width, h = image.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    data.withUnsafeMutableBytes { raw in
        let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return data
}

/// `y` counts from the top of the image.
func pixel(_ image: CGImage, x: Int, y: Int) -> Pixel {
    let bytes = rgbaBytes(image)
    let i = (y * image.width + x) * 4
    return Pixel(r: bytes[i], g: bytes[i + 1], b: bytes[i + 2], a: bytes[i + 3])
}

func isClose(_ p: Pixel, _ r: Int, _ g: Int, _ b: Int, _ a: Int = 255, tolerance: Int = 4) -> Bool {
    abs(Int(p.r) - r) <= tolerance && abs(Int(p.g) - g) <= tolerance
        && abs(Int(p.b) - b) <= tolerance && abs(Int(p.a) - a) <= tolerance
}

func resized(_ image: CGImage, width: Int, height: Int) -> CGImage {
    makeImage(width: width, height: height) { ctx in
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
}

/// Mean absolute per-channel difference (0...255); images must have equal size.
func meanAbsoluteDifference(_ a: CGImage, _ b: CGImage) -> Double {
    precondition(a.width == b.width && a.height == b.height)
    let x = rgbaBytes(a), y = rgbaBytes(b)
    var total = 0
    for i in 0..<x.count { total += abs(Int(x[i]) - Int(y[i])) }
    return Double(total) / Double(x.count)
}

func writeImage(_ image: CGImage, to url: URL, type: UTType = .png, properties: [CFString: Any] = [:]) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, properties as CFDictionary)
    precondition(CGImageDestinationFinalize(dest))
}

func properties(ofData data: Data) -> [CFString: Any]? {
    guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
}
