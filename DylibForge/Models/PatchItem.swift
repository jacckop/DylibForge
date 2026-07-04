import Foundation

enum PatchKind: String, CaseIterable, Identifiable {
    case url = "روابط"
    case arabic = "عربي"
    case endpoint = "Endpoint"
    case text = "نصوص"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .url: return "link"
        case .arabic: return "character.book.closed"
        case .endpoint: return "point.3.connected.trianglepath.dotted"
        case .text: return "text.alignleft"
        }
    }
}

struct PatchItem: Identifiable, Hashable {
    let id: UUID
    let offset: Int
    let original: String
    var replacement: String
    let byteLength: Int
    let kind: PatchKind
    let detail: String

    init(offset: Int, original: String, byteLength: Int, kind: PatchKind, detail: String) {
        self.id = UUID()
        self.offset = offset
        self.original = original
        self.replacement = original
        self.byteLength = byteLength
        self.kind = kind
        self.detail = detail
    }

    var offsetHex: String {
        "0x" + String(offset, radix: 16, uppercase: true)
    }

    var replacementByteLength: Int {
        replacement.data(using: .utf8)?.count ?? 0
    }

    var canPatch: Bool {
        replacementByteLength <= byteLength
    }

    var isChanged: Bool {
        replacement != original
    }

    var remainingBytes: Int {
        max(0, byteLength - replacementByteLength)
    }

    var preview: String {
        let cleaned = original.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count > 90 {
            return String(cleaned.prefix(90)) + "…"
        }
        return cleaned
    }
}

struct DylibStats {
    let total: Int
    let urls: Int
    let arabic: Int
    let endpoints: Int
    let texts: Int
    let changed: Int

    static let empty = DylibStats(total: 0, urls: 0, arabic: 0, endpoints: 0, texts: 0, changed: 0)
}

enum DylibForgeError: LocalizedError {
    case noFileLoaded
    case invalidReplacement(item: PatchItem)
    case invalidRange(item: PatchItem)
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noFileLoaded:
            return "ماكو ملف محمّل حالياً."
        case .invalidReplacement(let item):
            return "التعديل أطول من النص الأصلي عند \(item.offsetHex). لازم يكون نفس الطول أو أقصر."
        case .invalidRange(let item):
            return "الـ offset غير صالح أو خارج حجم الملف عند \(item.offsetHex)."
        case .writeFailed:
            return "فشل حفظ ملف dylib الجديد."
        }
    }
}
