import Foundation

struct TVGameStateFiles {
    let romURL: URL

    // Keep the ROM extension so same-named games on different systems do not
    // share automatic states. Preserve the existing manual-state path.
    var automaticURL: URL { romURL.appendingPathExtension("autosave") }
    var manualURL: URL { romURL.deletingPathExtension().appendingPathExtension("savestate") }

    var resumeURL: URL? {
        [automaticURL, manualURL].first { url in
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else { return false }
            return values.isRegularFile == true && (values.fileSize ?? 0) > 0
        }
    }

    func saveAutomatic(using writer: (URL) throws -> Void) throws {
        let temporary = automaticURL.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).autosave")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try writer(temporary)
        let data = try Data(contentsOf: temporary, options: .mappedIfSafe)
        guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        // A failed core write must not destroy the previous resume point.
        try data.write(to: automaticURL, options: .atomic)
    }
}
