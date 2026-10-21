import Foundation

/// Moves finished temporary output into place under a free name, retrying on races.
public enum OutputCommitter {
    /// Moves `temp` next to `input` as `<name>[ <label>].<ext>`. If another job takes the name first, the next free
    /// name is tried (at most `maxAttempts` times). Nothing is ever overwritten; `temp` is left for the caller to clean up.
    public static func commit(temp: URL, nextTo input: URL, label: String? = nil, fileExtension: String,
                              fileManager: FileManager = .default, maxAttempts: Int = 5) throws -> URL {
        try move(temp, maxAttempts: maxAttempts, fileManager: fileManager) {
            OutputPlanner.uniqueSibling(of: input, fileExtension: fileExtension, label: label, fileManager: fileManager)
        }
    }

    /// Moves the directory `temp` next to `input` as `<name> <suffix>`, or `<name> <suffix> 2`, `<name> <suffix> 3`, ...
    /// if taken. Same race handling and no-overwrite rule as `commit`.
    public static func commitFolder(temp: URL, nextTo input: URL, suffix: String = "pages",
                                    fileManager: FileManager = .default, maxAttempts: Int = 5) throws -> URL {
        try move(temp, maxAttempts: maxAttempts, fileManager: fileManager) {
            let dir = input.deletingLastPathComponent()
            let base = "\(input.deletingPathExtension().lastPathComponent) \(suffix)"
            var candidate = dir.appendingPathComponent(base)
            var n = 2
            while fileManager.fileExists(atPath: candidate.path) {
                candidate = dir.appendingPathComponent("\(base) \(n)")
                n += 1
            }
            return candidate
        }
    }

    private static func move(_ temp: URL, maxAttempts: Int, fileManager: FileManager,
                             nextCandidate: () -> URL) throws -> URL {
        var attempt = 0
        while true {
            let final = nextCandidate()
            do {
                try fileManager.moveItem(at: temp, to: final)
                return final
            } catch {
                attempt += 1
                guard attempt < maxAttempts, fileManager.fileExists(atPath: final.path) else { throw error }
            }
        }
    }
}
