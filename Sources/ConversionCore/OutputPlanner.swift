import Foundation

/// Picks output file names next to the input that do not collide with existing files.
public enum OutputPlanner {
    /// `photo.png` + `.jpeg` -> `photo.jpg`, or `photo 2.jpg` if taken.
    public static func uniqueSibling(of input: URL, format: FileFormat, fileManager: FileManager = .default) -> URL {
        uniqueSibling(of: input, fileExtension: format.fileExtension, label: nil, fileManager: fileManager)
    }

    /// `photo.png` + "jpg" + "cropped" -> `photo cropped.jpg`, or `photo cropped 2.jpg` if taken.
    public static func uniqueSibling(of input: URL, fileExtension: String, label: String?,
                                     fileManager: FileManager = .default) -> URL {
        let dir = input.deletingLastPathComponent()
        var base = input.deletingPathExtension().lastPathComponent
        if let label, !label.isEmpty { base += " \(label)" }
        var candidate = dir.appendingPathComponent(base).appendingPathExtension(fileExtension)
        var n = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base) \(n)").appendingPathExtension(fileExtension)
            n += 1
        }
        return candidate
    }

    /// Hidden file in the same directory (so the final move is atomic) that
    /// keeps the real extension (so ffmpeg can infer the container).
    public static func temporarySibling(for final: URL) -> URL {
        final.deletingLastPathComponent()
            .appendingPathComponent(".shapeshift-\(UUID().uuidString)")
            .appendingPathExtension(final.pathExtension)
    }
}
