import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var fileURL: URL?
    @Published var fileName: String = ""
    @Published var fileSizeText: String = ""
    @Published var items: [PatchItem] = []
    @Published var searchText: String = ""
    @Published var selectedKind: PatchKind? = nil
    @Published var isScanning: Bool = false
    @Published var banner: String? = nil
    @Published var exportedURL: URL? = nil

    private var originalData: Data?

    var stats: DylibStats {
        DylibStats(
            total: items.count,
            urls: items.filter { $0.kind == .url }.count,
            arabic: items.filter { $0.kind == .arabic }.count,
            endpoints: items.filter { $0.kind == .endpoint }.count,
            texts: items.filter { $0.kind == .text }.count,
            changed: items.filter { $0.isChanged }.count
        )
    }

    var filteredItems: [PatchItem] {
        items.filter { item in
            let matchesKind = selectedKind == nil || item.kind == selectedKind
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = query.isEmpty
                || item.original.lowercased().contains(query)
                || item.replacement.lowercased().contains(query)
                || item.detail.lowercased().contains(query)
                || item.offsetHex.lowercased().contains(query)
            return matchesKind && matchesSearch
        }
    }

    func importFile(from url: URL) {
        isScanning = true
        banner = "جاري قراءة الملف وفحص النصوص…"
        exportedURL = nil

        Task {
            do {
                let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessing { url.stopAccessingSecurityScopedResource() }
                }

                let localURL = try DylibFileStore.copyImportedFile(from: url)
                let data = try Data(contentsOf: localURL)
                let scanResult = await Task.detached(priority: .userInitiated) {
                    BinaryScanner.scan(data: data)
                }.value

                originalData = data
                fileURL = localURL
                fileName = localURL.lastPathComponent
                fileSizeText = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
                items = scanResult
                isScanning = false
                banner = "تم استخراج \(scanResult.count) عنصر قابل للفحص. عدّل فقط بنفس الطول أو أقصر."
            } catch {
                isScanning = false
                banner = error.localizedDescription
            }
        }
    }

    func updateReplacement(for id: UUID, replacement: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].replacement = replacement
        exportedURL = nil
    }

    func resetReplacement(for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].replacement = items[index].original
        exportedURL = nil
    }

    func resetAllChanges() {
        items = items.map { item in
            var copy = item
            copy.replacement = copy.original
            return copy
        }
        exportedURL = nil
        banner = "تم إلغاء كل التعديلات."
    }

    func buildPatchedDylib() {
        do {
            guard let originalData else { throw DylibForgeError.noFileLoaded }
            if let invalid = items.first(where: { $0.isChanged && !$0.canPatch }) {
                throw DylibForgeError.invalidReplacement(item: invalid)
            }

            let patched = try BinaryPatcher.patchedData(originalData: originalData, items: items)
            let outputURL = DylibFileStore.patchedOutputURL(for: fileName.isEmpty ? "patched.dylib" : fileName)
            try patched.write(to: outputURL, options: .atomic)
            exportedURL = outputURL
            banner = "تم إنشاء الديلب الجديد: \(outputURL.lastPathComponent)"
        } catch {
            banner = error.localizedDescription
        }
    }
}
