import Foundation

/// Pure parsers shared by system adapters and covered by unit tests.
enum SystemParsing {
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let left = versionParts(candidate)
        let right = versionParts(current)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let candidatePart = index < left.count ? left[index] : 0
            let currentPart = index < right.count ? right[index] : 0
            if candidatePart != currentPart { return candidatePart > currentPart }
        }
        return false
    }

    static func versionParts(_ version: String) -> [Int] {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.drop(while: { $0 == "v" || $0 == "V" })
        let core = withoutPrefix.prefix(while: { $0.isNumber || $0 == "." })
        return core.split(separator: ".", omittingEmptySubsequences: true)
            .compactMap { Int($0) }
    }

    static func bool(fromDefaultsOutput output: String, default defaultValue: Bool = false) -> Bool {
        let value = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.isEmpty { return defaultValue }
        return value == "1" || value == "true" || value == "yes"
    }

    static func lowPowerModeValue(in output: String) -> Bool? {
        for line in output.components(separatedBy: .newlines)
            where line.lowercased().contains("lowpowermode") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if let value = parts.last {
                return value == "1" || value.lowercased() == "true"
            }
        }
        return nil
    }
}
