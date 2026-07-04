import Foundation

struct DylibFileStore {
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static func copyImportedFile(from sourceURL: URL) throws -> URL {
        let fileName = sourceURL.lastPathComponent.isEmpty ? "imported.dylib" : sourceURL.lastPathComponent
        let safeName = fileName.hasSuffix(".dylib") ? fileName : fileName + ".dylib"
        let destination = documentsURL.appendingPathComponent(safeName)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    static func patchedOutputURL(for originalName: String) -> URL {
        let base = originalName.replacingOccurrences(of: ".dylib", with: "", options: .caseInsensitive)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        return documentsURL.appendingPathComponent("\(base)-patched-\(stamp).dylib")
    }
}
