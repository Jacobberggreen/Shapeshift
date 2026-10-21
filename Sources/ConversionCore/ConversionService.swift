import Foundation

/// Outcome of converting one input: the source file and either the written output or the error.
public struct ConversionResult: Sendable {
    public let input: URL
    public let result: Result<URL, ConversionError>

    public init(input: URL, result: Result<URL, ConversionError>) {
        self.input = input
        self.result = result
    }
}

/// Runs conversions through the registered converters and reports which targets each file can reach.
public final class ConversionService: Sendable {
    private let converters: [any Converter]
    /// Whether FFmpeg was found, which enables the audio, video and WebP targets.
    public let hasFFmpeg: Bool

    /// Creates a service that uses the first converter supporting each conversion.
    public init(converters: [any Converter], hasFFmpeg: Bool = false) {
        self.converters = converters
        self.hasFFmpeg = hasFFmpeg
    }

    /// A service with the built-in converters, plus FFmpeg when a binary is found.
    public static func makeDefault(ffmpeg: URL? = FFmpegLocator.locate()) -> ConversionService {
        var converters: [any Converter] = [ImageConverter(), PDFConverter(), DocumentConverter()]
        if let ffmpeg { converters.append(FFmpegConverter(executable: ffmpeg)) }
        return ConversionService(converters: converters, hasFFmpeg: ffmpeg != nil)
    }

    /// Formats the file at `url` can be converted to; empty for unsupported or unknown types.
    public func targets(for url: URL) -> [FileFormat] {
        guard let source = FileFormat(url: url) else { return [] }
        return FormatTable.candidateTargets(from: source).filter { target in
            converters.contains { $0.supports(from: source, to: target) }
        }
    }

    /// Formats that every file in `urls` can be converted to.
    public func commonTargets(for urls: [URL]) -> [FileFormat] {
        guard let first = urls.first else { return [] }
        var result = targets(for: first)
        for url in urls.dropFirst() {
            let others = Set(targets(for: url))
            result = result.filter(others.contains)
        }
        return result
    }

    /// Converts one file next to its input and returns the new URL. Never overwrites: the output gets a free name.
    @discardableResult
    public func convert(_ input: URL, to target: FileFormat, options: ConversionOptions = ConversionOptions()) async throws -> URL {
        guard let source = FileFormat(url: input) else { throw ConversionError.unsupportedFile(input) }
        if source == .gdoc {
            throw ConversionError.failed("A .gdoc file is only a link to an online Google Doc. In Google Docs choose File > Download > Microsoft Word (.docx), then convert that file.")
        }
        guard let converter = converters.first(where: { $0.supports(from: source, to: target) }) else {
            throw ConversionError.unsupportedConversion(from: source, to: target)
        }
        let provisional = OutputPlanner.uniqueSibling(of: input, format: target)
        let temp = OutputPlanner.temporarySibling(for: provisional)
        do {
            try await converter.convert(input: input, from: source, to: target, output: temp, options: options)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: temp.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return try OutputCommitter.commitFolder(temp: temp, nextTo: input)
            }
            return try OutputCommitter.commit(temp: temp, nextTo: input, fileExtension: target.fileExtension)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw error
        }
    }

    /// Converts each file in turn and returns one result per input. Stops at cancellation, marking the rest cancelled.
    public func convert(_ inputs: [URL], to target: FileFormat, options: ConversionOptions = ConversionOptions()) async -> [ConversionResult] {
        var results: [ConversionResult] = []
        for (index, input) in inputs.enumerated() {
            if Task.isCancelled {
                results += inputs[index...].map { ConversionResult(input: $0, result: .failure(.cancelled)) }
                break
            }
            do {
                let output = try await convert(input, to: target, options: options)
                results.append(ConversionResult(input: input, result: .success(output)))
            } catch let error as ConversionError {
                results.append(ConversionResult(input: input, result: .failure(error)))
            } catch is CancellationError {
                results.append(ConversionResult(input: input, result: .failure(.cancelled)))
            } catch {
                results.append(ConversionResult(input: input, result: .failure(.failed(error.localizedDescription))))
            }
        }
        return results
    }
}
