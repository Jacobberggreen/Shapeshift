import Foundation

private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

/// Lock-protected buffer that retains only the last `limit` bytes appended.
private final class TailBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private let limit = 8192
    func append(_ chunk: Data) {
        lock.lock(); defer { lock.unlock() }
        data.append(chunk)
        if data.count > limit { data = data.suffix(limit) }
    }
    var contents: Data { lock.lock(); defer { lock.unlock() }; return data }
}

/// Runs an external tool and waits for it, mapping its failures to ConversionError.
public enum ProcessRunner {
    /// Runs `executable` and waits. Throws ConversionError.failed with the end of stderr on a non-zero exit; terminates the child when the task is cancelled.
    public static func run(executable: URL, arguments: [String]) async throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let flag = CancellationFlag()
        let tail = TailBuffer()
        // Drain stderr while the child runs so a chatty child cannot block on a full pipe.
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                tail.append(chunk)
            }
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { finished in
                    stderr.fileHandleForReading.readabilityHandler = nil
                    tail.append(stderr.fileHandleForReading.readDataToEndOfFile())
                    let data = tail.contents
                    if flag.isSet {
                        continuation.resume(throwing: ConversionError.cancelled)
                    } else if finished.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let text = String(decoding: data, as: UTF8.self)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(throwing: ConversionError.failed(
                            text.isEmpty ? "exit status \(finished.terminationStatus)" : text))
                    }
                }
                do {
                    try process.run()
                } catch {
                    stderr.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: ConversionError.failed(error.localizedDescription))
                    return
                }
                // Cancelled before the process existed: the cancel handler found nothing to stop.
                if Task.isCancelled {
                    flag.set()
                    process.terminate()
                }
            }
        } onCancel: {
            flag.set()
            if process.isRunning { process.terminate() }
        }
    }
}
