import Foundation

enum PaletteSearch {
    static func score(query: String, in fields: [String]) -> Int? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return 0 }
        let haystack = normalize(fields.joined(separator: " "))
        guard !haystack.isEmpty else { return nil }

        if haystack == normalizedQuery { return 10_000 }
        if haystack.hasPrefix(normalizedQuery) { return 9_000 - haystack.count }
        if let range = haystack.range(of: normalizedQuery) {
            let distance = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
            return 8_000 - distance
        }
        let words = haystack.split(separator: " ")
        if words.contains(where: { $0.hasPrefix(normalizedQuery) }) {
            return 7_000 - haystack.count
        }
        return fuzzyScore(query: normalizedQuery, haystack: haystack)
    }

    private static func fuzzyScore(query: String, haystack: String) -> Int? {
        var queryIndex = query.startIndex
        var previousMatch: String.Index?
        var score = 0

        for index in haystack.indices {
            guard queryIndex < query.endIndex else { break }
            if haystack[index] == query[queryIndex] {
                score += 80
                if let previousMatch {
                    let gap = haystack.distance(from: previousMatch, to: index) - 1
                    score -= min(gap * 8, 80)
                    if gap == 0 { score += 25 }
                } else {
                    let leading = haystack.distance(from: haystack.startIndex, to: index)
                    score -= min(leading * 4, 80)
                }
                if index == haystack.startIndex || haystack[haystack.index(before: index)] == " " {
                    score += 35
                }
                previousMatch = index
                queryIndex = query.index(after: queryIndex)
            }
        }

        guard queryIndex == query.endIndex else { return nil }
        return max(1, score)
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9@._:/ -]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
