import XCTest
@testable import ConversionCore

final class FFmpegTests: XCTestCase {
    private var ffmpeg: URL!

    override func setUpWithError() throws {
        guard let url = FFmpegLocator.locate() else { throw XCTSkip("ffmpeg not installed") }
        ffmpeg = url
    }

    // MARK: locator (no ffmpeg needed, but setUp skips cleanly if absent)

    func testLocatorPrefersEnvironmentOverride() {
        let found = FFmpegLocator.locate(environment: ["SHAPESHIFT_FFMPEG": "/bin/echo"], bundleResources: nil)
        XCTAssertEqual(found?.path, "/bin/echo")
    }

    func testNonexistentOverrideIsFinalAndDoesNotFallThrough() {
        let found = FFmpegLocator.locate(environment: ["SHAPESHIFT_FFMPEG": "/nonexistent/ffmpeg"], bundleResources: nil)
        XCTAssertNil(found)
    }

    func testEmptyOverrideDisablesFFmpeg() {
        XCTAssertNil(FFmpegLocator.locate(environment: ["SHAPESHIFT_FFMPEG": ""], bundleResources: nil))
    }

    func testUnsetOverrideKeepsNormalLookup() {
        // May or may not find Homebrew's ffmpeg; just must not crash.
        _ = FFmpegLocator.locate(environment: [:], bundleResources: nil)
    }

    // MARK: pure argument building

    func testMp3Arguments() {
        let args = FFmpegArguments.make(input: URL(fileURLWithPath: "/a.wav"), output: URL(fileURLWithPath: "/b.mp3"),
                                        from: .wav, to: .mp3, quality: 1)
        XCTAssertEqual(Array(args.prefix(6)), ["-y", "-hide_banner", "-loglevel", "error", "-i", "/a.wav"])
        XCTAssertTrue(args.contains("libmp3lame"))
        XCTAssertEqual(args[args.firstIndex(of: "-q:a")! + 1], "0")
        XCTAssertEqual(args.last, "/b.mp3")
    }

    func testMp4Arguments() {
        let args = FFmpegArguments.make(input: URL(fileURLWithPath: "/a.mov"), output: URL(fileURLWithPath: "/b.mp4"),
                                        from: .mov, to: .mp4, quality: 0.85)
        XCTAssertTrue(args.contains("libx264"))
        XCTAssertTrue(args.contains("yuv420p"))
        XCTAssertTrue(args.contains("+faststart"))
    }

    func testGifArgumentsUsePalette() {
        let args = FFmpegArguments.make(input: URL(fileURLWithPath: "/a.mp4"), output: URL(fileURLWithPath: "/b.gif"),
                                        from: .mp4, to: .gif, quality: 0.85)
        XCTAssertTrue(args.joined(separator: " ").contains("palettegen"))
        XCTAssertTrue(args.contains("-an"))
    }

    func testSupports() {
        let c = FFmpegConverter(executable: ffmpeg)
        XCTAssertTrue(c.supports(from: .wav, to: .flac))
        XCTAssertTrue(c.supports(from: .mp4, to: .mp3))
        XCTAssertTrue(c.supports(from: .mp4, to: .gif))
        XCTAssertTrue(c.supports(from: .png, to: .webp))
        XCTAssertFalse(c.supports(from: .heic, to: .webp))
        XCTAssertFalse(c.supports(from: .mp3, to: .mp4))
        XCTAssertFalse(c.supports(from: .wav, to: .wav))
        XCTAssertFalse(c.supports(from: .png, to: .jpeg))
    }

    // MARK: real conversions

    func testAudioConversions() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.wav")
        makeTestWAV(at: input)
        let c = FFmpegConverter(executable: ffmpeg)
        let expected: [(FileFormat, String)] = [
            (.mp3, "mp3"), (.flac, "flac"), (.opus, "opus"), (.ogg, "vorbis"), (.m4a, "aac"), (.aiff, "pcm_s16be"),
        ]
        for (format, codec) in expected {
            let out = dir.file("out.\(format.fileExtension)")
            try await c.convert(input: input, from: .wav, to: format, output: out, options: ConversionOptions())
            XCTAssertGreaterThan(try FileManager.default.attributesOfItem(atPath: out.path)[.size] as! Int, 0)
            if let probed = probeCodec(out, ffmpeg: ffmpeg) { XCTAssertEqual(probed, codec, "\(format)") }
        }
    }

    func testVideoConversions() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.mp4")
        try makeTestMP4(at: input, ffmpeg: ffmpeg)
        let c = FFmpegConverter(executable: ffmpeg)
        let codecs: [FileFormat: String] = [.mkv: "h264", .mov: "h264", .webm: "vp9", .avi: "mpeg4", .mp3: "mp3"]
        for format in [FileFormat.mkv, .mov, .webm, .avi, .gif, .mp3] {
            let out = dir.file("out.\(format.fileExtension)")
            try await c.convert(input: input, from: .mp4, to: format, output: out, options: ConversionOptions())
            XCTAssertGreaterThan(try FileManager.default.attributesOfItem(atPath: out.path)[.size] as! Int, 0, "\(format)")
            if let expected = codecs[format], let probed = probeCodec(out, ffmpeg: ffmpeg) {
                XCTAssertEqual(probed, expected, "\(format)")
            }
        }
        XCTAssertEqual(probeCodec(dir.file("out.gif"), ffmpeg: ffmpeg), "gif")
    }

    func testPNGToWebP() async throws {
        let dir = TemporaryDirectory()
        let input = dir.file("in.png")
        makeTestPNG(at: input)
        let out = dir.file("out.webp")
        try await FFmpegConverter(executable: ffmpeg).convert(input: input, from: .png, to: .webp, output: out, options: ConversionOptions())
        XCTAssertEqual(probeCodec(out, ffmpeg: ffmpeg), "webp")
    }

    func testBadInputSurfacesFfmpegError() async {
        let dir = TemporaryDirectory()
        let bogus = dir.file("bogus.wav")
        try? Data("junk".utf8).write(to: bogus)
        do {
            try await FFmpegConverter(executable: ffmpeg).convert(input: bogus, from: .wav, to: .mp3, output: dir.file("o.mp3"), options: ConversionOptions())
            XCTFail("expected throw")
        } catch {
            guard case ConversionError.failed = error else { return XCTFail("got \(error)") }
        }
    }
}
