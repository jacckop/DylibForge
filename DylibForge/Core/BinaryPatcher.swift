import Foundation

struct BinaryPatcher {
    static func patchedData(originalData: Data, items: [PatchItem]) throws -> Data {
        var output = originalData
        let changedItems = items.filter { $0.isChanged }

        for item in changedItems {
            guard item.canPatch else { throw DylibForgeError.invalidReplacement(item: item) }
            let end = item.offset + item.byteLength
            guard item.offset >= 0 && end <= output.count else { throw DylibForgeError.invalidRange(item: item) }

            var replacementBytes = Array(item.replacement.utf8)
            let paddingCount = item.byteLength - replacementBytes.count
            if paddingCount > 0 {
                replacementBytes.append(contentsOf: Array(repeating: UInt8(0), count: paddingCount))
            }

            output.replaceSubrange(item.offset..<end, with: replacementBytes)
        }

        return output
    }
}
