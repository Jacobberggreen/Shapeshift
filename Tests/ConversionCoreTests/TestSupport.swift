import Foundation

final class TemporaryDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shapeshift-tests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func file(_ name: String) -> URL { url.appendingPathComponent(name) }

    deinit { try? FileManager.default.removeItem(at: url) }
}

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func makeTestPNG(at url: URL, width: Int = 64, height: Int = 32) {
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 0.5, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(dest))
}

@testable import ConversionCore

/// 0.5 s, 44.1 kHz, mono, 16-bit sine wave.
func makeTestWAV(at url: URL, seconds: Double = 0.5, sampleRate: Int = 44100) {
    let frames = Int(Double(sampleRate) * seconds)
    var data = Data()
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    data.append(contentsOf: "RIFF".utf8); u32(UInt32(36 + frames * 2)); data.append(contentsOf: "WAVE".utf8)
    data.append(contentsOf: "fmt ".utf8); u32(16); u16(1); u16(1)
    u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
    data.append(contentsOf: "data".utf8); u32(UInt32(frames * 2))
    for i in 0..<frames {
        let s = Int16(sin(2 * Double.pi * 440 * Double(i) / Double(sampleRate)) * 12000)
        u16(UInt16(bitPattern: s))
    }
    try! data.write(to: url)
}

/// 1 s, 128x72 test pattern with a sine audio track.
func makeTestMP4(at url: URL, ffmpeg: URL) throws {
    try runSync(ffmpeg, ["-y", "-loglevel", "error",
        "-f", "lavfi", "-i", "testsrc=duration=1:size=128x72:rate=10",
        "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", url.path])
}

/// First stream's codec name via the ffprobe that sits next to ffmpeg.
func probeCodec(_ url: URL, ffmpeg: URL) -> String? {
    let ffprobe = ffmpeg.deletingLastPathComponent().appendingPathComponent("ffprobe")
    guard FileManager.default.isExecutableFile(atPath: ffprobe.path) else { return nil }
    let p = Process()
    p.executableURL = ffprobe
    p.arguments = ["-v", "error", "-select_streams", "0", "-show_entries", "stream=codec_name",
                   "-of", "csv=p=0", url.path]
    let out = Pipe()
    p.standardOutput = out
    try? p.run()
    p.waitUntilExit()
    let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    return text.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces)
}

private func runSync(_ exe: URL, _ args: [String]) throws {
    let p = Process()
    p.executableURL = exe
    p.arguments = args
    try p.run()
    p.waitUntilExit()
    if p.terminationStatus != 0 { throw ConversionError.failed("fixture command failed: \(args)") }
}
