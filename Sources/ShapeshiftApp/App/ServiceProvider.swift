import AppKit

/// Extracts the existing file URLs from a pasteboard.
enum ServiceFiles {
    /// File URLs on the pasteboard, in order, without duplicates; only existing regular files.
    static func urls(from pasteboard: NSPasteboard) -> [URL] {
        let all = (pasteboard.readObjects(forClasses: [NSURL.self],
                                          options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        var seen = Set<String>()
        var result: [URL] = []
        for url in all {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  seen.insert(url.standardizedFileURL.path).inserted else { continue }
            result.append(url)
        }
        return result
    }
}

/// Receives the "Shapeshift…" Service from Finder (see NSServices in Info.plist).
@MainActor
final class ServiceProvider: NSObject {
    var onFiles: (([URL]) -> Void)?

    @objc func openWithShapeshift(_ pboard: NSPasteboard, userData: String,
                                  error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let urls = ServiceFiles.urls(from: pboard)
        guard !urls.isEmpty else {
            error.pointee = "Shapeshift found no files to open." as NSString
            return
        }
        onFiles?(urls)
    }
}
