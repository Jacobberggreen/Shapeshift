import Foundation

/// Finds an ffmpeg executable on this Mac.
public enum FFmpegLocator {
    /// The ffmpeg binary to use: the SHAPESHIFT_FFMPEG override (an empty value disables the search), else the bundled or Homebrew copy.
    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleResources: URL? = Bundle.main.resourceURL,
        fileManager: FileManager = .default
    ) -> URL? {
        // An override (even an empty one) is final: no fall-through to other locations.
        if let override = environment["SHAPESHIFT_FFMPEG"] {
            return fileManager.isExecutableFile(atPath: override) ? URL(fileURLWithPath: override) : nil
        }
        var candidates: [String] = []
        if let resources = bundleResources { candidates.append(resources.appendingPathComponent("ffmpeg").path) }
        candidates += ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        return candidates
            .first { fileManager.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }
}

/// Builds ffmpeg command lines for each supported output format.
public enum FFmpegArguments {
    /// Arguments that convert `input` to `output`; `quality` is clamped to 0...1.
    public static func make(input: URL, output: URL, from: FileFormat, to: FileFormat, quality: Double) -> [String] {
        ["-y", "-hide_banner", "-loglevel", "error", "-i", input.path]
            + codecArguments(to: to, quality: min(max(quality, 0), 1))
            + [output.path]
    }

    private static func h264(_ q: Double) -> [String] {
        let crf = 18 + Int((1 - q) * 22)
        return ["-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
                "-c:v", "libx264", "-crf", "\(crf)", "-pix_fmt", "yuv420p", "-c:a", "aac"]
    }

    private static func codecArguments(to: FileFormat, quality q: Double) -> [String] {
        switch to {
        case .mp3:  return ["-vn", "-codec:a", "libmp3lame", "-q:a", "\(Int(((1 - q) * 9).rounded()))"]
        case .m4a:  return ["-vn", "-codec:a", "aac", "-b:a", "\(64 + Int(q * 192))k"]
        case .wav:  return ["-vn", "-codec:a", "pcm_s16le"]
        case .flac: return ["-vn", "-codec:a", "flac"]
        case .ogg:  return ["-vn", "-codec:a", "libvorbis", "-q:a", "\(Int((q * 10).rounded()))"]
        case .opus: return ["-vn", "-codec:a", "libopus", "-b:a", "\(32 + Int(q * 128))k"]
        case .aiff: return ["-vn", "-codec:a", "pcm_s16be"]
        case .mp4:  return h264(q) + ["-movflags", "+faststart"]
        case .mov, .mkv: return h264(q)
        case .webm: return ["-c:v", "libvpx-vp9", "-crf", "\(25 + Int((1 - q) * 20))", "-b:v", "0", "-c:a", "libopus"]
        case .avi:  return ["-c:v", "mpeg4", "-q:v", "\(2 + Int((1 - q) * 8))", "-c:a", "libmp3lame"]
        case .gif:  return ["-an", "-vf",
                            "fps=12,scale=480:-2:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
                            "-loop", "0"]
        case .webp: return ["-frames:v", "1", "-c:v", "libwebp", "-quality", "\(Int(q * 100))"]
        default:    return []
        }
    }
}

/// Converts audio, video and WebP images by running ffmpeg.
public struct FFmpegConverter: Converter {
    public let executable: URL

    public init(executable: URL) { self.executable = executable }

    /// Audio to audio, video to video, audio or GIF, and JPEG, PNG, TIFF, BMP or GIF to WebP.
    public func supports(from: FileFormat, to: FileFormat) -> Bool {
        guard from != to else { return false }
        switch from.kind {
        case .audio: return to.kind == .audio
        case .video: return to.kind == .video || to.kind == .audio || to == .gif
        case .image: return to == .webp && [.jpeg, .png, .tiff, .bmp, .gif].contains(from)
        case .document: return false
        }
    }

    /// Runs ffmpeg with the arguments from `FFmpegArguments`; throws if the pair is unsupported or ffmpeg fails.
    public func convert(input: URL, from: FileFormat, to: FileFormat, output: URL, options: ConversionOptions) async throws {
        guard supports(from: from, to: to) else {
            throw ConversionError.unsupportedConversion(from: from, to: to)
        }
        try await ProcessRunner.run(
            executable: executable,
            arguments: FFmpegArguments.make(input: input, output: output, from: from, to: to, quality: options.quality))
    }
}
