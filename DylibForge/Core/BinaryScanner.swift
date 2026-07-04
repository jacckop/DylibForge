import Foundation

struct BinaryScanner {
    private struct Segment {
        let offset: Int
        let text: String
        let byteLength: Int
    }

    static func scan(data: Data) -> [PatchItem] {
        let segments = scanSegments(data: data)
        var items: [PatchItem] = []
        var seen = Set<String>()

        for segment in segments {
            for item in urlItems(from: segment) {
                appendUnique(item, to: &items, seen: &seen)
            }

            if containsArabic(segment.text) {
                appendUnique(
                    PatchItem(
                        offset: segment.offset,
                        original: safeDisplay(segment.text),
                        byteLength: segment.byteLength,
                        kind: .arabic,
                        detail: functionGuess(for: segment.text)
                    ),
                    to: &items,
                    seen: &seen
                )
            } else if looksLikeEndpoint(segment.text) {
                appendUnique(
                    PatchItem(
                        offset: segment.offset,
                        original: safeDisplay(segment.text),
                        byteLength: segment.byteLength,
                        kind: .endpoint,
                        detail: functionGuess(for: segment.text)
                    ),
                    to: &items,
                    seen: &seen
                )
            } else if looksLikeUsefulText(segment.text) {
                appendUnique(
                    PatchItem(
                        offset: segment.offset,
                        original: safeDisplay(segment.text),
                        byteLength: segment.byteLength,
                        kind: .text,
                        detail: functionGuess(for: segment.text)
                    ),
                    to: &items,
                    seen: &seen
                )
            }

            if items.count >= 5000 { break }
        }

        return items.sorted { left, right in
            if left.kind == right.kind { return left.offset < right.offset }
            return priority(left.kind) < priority(right.kind)
        }
    }

    private static func scanSegments(data: Data) -> [Segment] {
        let bytes = [UInt8](data)
        var segments: [Segment] = []
        var index = 0

        while index < bytes.count {
            let start = index
            var text = ""
            var byteLength = 0

            while index < bytes.count {
                guard let consumed = consumeCharacter(bytes: bytes, index: index) else { break }
                text.append(consumed.text)
                byteLength += consumed.length
                index += consumed.length

                if byteLength > 4096 { break }
            }

            if byteLength >= 4 {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if isMeaningful(trimmed) {
                    segments.append(Segment(offset: start, text: trimmed, byteLength: byteLength))
                }
            }

            if index == start { index += 1 }
        }

        return segments
    }

    private static func consumeCharacter(bytes: [UInt8], index: Int) -> (text: String, length: Int)? {
        let byte = bytes[index]

        if byte >= 0x20 && byte <= 0x7E {
            return (String(UnicodeScalar(byte)), 1)
        }

        if byte == 0x09 || byte == 0x0A || byte == 0x0D {
            return (" ", 1)
        }

        for length in 2...4 {
            guard index + length <= bytes.count else { continue }
            let slice = Array(bytes[index..<(index + length)])
            guard let string = String(bytes: slice, encoding: .utf8), string.count == 1 else { continue }
            guard let scalar = string.unicodeScalars.first else { continue }
            if isAllowedUnicodeScalar(scalar) {
                return (string, length)
            }
        }

        return nil
    }

    private static func isAllowedUnicodeScalar(_ scalar: UnicodeScalar) -> Bool {
        let value = scalar.value
        if value < 0x00A0 { return false }
        if value >= 0xD800 && value <= 0xDFFF { return false }
        if value >= 0xE000 && value <= 0xF8FF { return false }
        if value >= 0xF0000 && value <= 0xFFFFD { return false }
        if value >= 0x100000 && value <= 0x10FFFD { return false }
        return true
    }

    private static func isMeaningful(_ text: String) -> Bool {
        guard text.count >= 3 else { return false }
        if text.contains("http://") || text.contains("https://") || text.contains("itms-services://") { return true }
        if containsArabic(text) { return true }
        if looksLikeEndpoint(text) { return true }
        return looksLikeUsefulText(text)
    }

    private static func urlItems(from segment: Segment) -> [PatchItem] {
        let pattern = #"(?i)(https?|ftp|itms-services)://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(segment.text.startIndex..<segment.text.endIndex, in: segment.text)
        let matches = regex.matches(in: segment.text, range: nsRange)

        return matches.compactMap { match in
            guard let range = Range(match.range, in: segment.text) else { return nil }
            let found = String(segment.text[range])
            let prefix = String(segment.text[..<range.lowerBound])
            let offset = segment.offset + (prefix.data(using: .utf8)?.count ?? 0)
            let byteLength = found.data(using: .utf8)?.count ?? 0
            guard byteLength > 0 else { return nil }
            return PatchItem(offset: offset, original: found, byteLength: byteLength, kind: .url, detail: functionGuess(for: found))
        }
    }

    private static func appendUnique(_ item: PatchItem, to items: inout [PatchItem], seen: inout Set<String>) {
        let key = "\(item.offset)-\(item.byteLength)-\(item.original)"
        guard !seen.contains(key) else { return }
        seen.insert(key)
        items.append(item)
    }

    private static func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (0x0600...0x06FF).contains(value)
                || (0x0750...0x077F).contains(value)
                || (0x08A0...0x08FF).contains(value)
                || (0xFB50...0xFDFF).contains(value)
                || (0xFE70...0xFEFF).contains(value)
        }
    }

    private static func looksLikeEndpoint(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 && trimmed.count <= 300 else { return false }
        if trimmed.hasPrefix("/") && trimmed.contains(where: { $0.isLetter || $0.isNumber }) { return true }
        let lower = trimmed.lowercased()
        return lower.contains("/api/")
            || lower.contains("api/")
            || lower.contains("endpoint")
            || lower.contains("plist")
            || lower.contains("install")
            || lower.contains("download")
            || lower.contains("server")
    }

    private static func looksLikeUsefulText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 && trimmed.count <= 240 else { return false }
        let letters = trimmed.filter { $0.isLetter }.count
        guard letters >= 3 else { return false }
        let lower = trimmed.lowercased()
        let keywords = [
            "api", "url", "token", "auth", "login", "license", "server", "bundle",
            "version", "download", "install", "sign", "certificate", "profile", "plist",
            "error", "success", "failed", "admob", "ads", "premium", "vip"
        ]
        if keywords.contains(where: { lower.contains($0) }) { return true }
        return trimmed.contains("_") || trimmed.contains(".") || trimmed.contains(":") || trimmed.contains("/")
    }

    private static func safeDisplay(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\u{0000}", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        if cleaned.count > 300 {
            return String(cleaned.prefix(300))
        }
        return cleaned
    }

    private static func functionGuess(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("http") || lower.contains("itms-services") { return "رابط/مسار اتصال داخل الديلب" }
        if lower.contains("license") || lower.contains("vip") || lower.contains("premium") { return "غالباً متعلق بترخيص أو مزايا مدفوعة" }
        if lower.contains("token") || lower.contains("auth") || lower.contains("login") { return "غالباً متعلق بالمصادقة أو تسجيل الدخول" }
        if lower.contains("download") || lower.contains("install") || lower.contains("plist") || lower.contains("ipa") { return "غالباً متعلق بالتحميل أو التثبيت" }
        if lower.contains("admob") || lower.contains("ads") || lower.contains("advert") { return "غالباً متعلق بالإعلانات" }
        if lower.contains("api") || lower.contains("server") || lower.contains("endpoint") { return "غالباً متعلق بسيرفر أو API" }
        if containsArabic(text) { return "نص عربي ظاهر داخل الديلب" }
        return "نص قابل للفحص والتعديل بنفس الطول أو أقصر"
    }

    private static func priority(_ kind: PatchKind) -> Int {
        switch kind {
        case .url: return 0
        case .arabic: return 1
        case .endpoint: return 2
        case .text: return 3
        }
    }
}
