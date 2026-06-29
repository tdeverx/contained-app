import Foundation

enum PaletteSearch {
    static func score(query: String, in fields: [String]) -> Int? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return 0 }
        let haystacks = ([fields.joined(separator: " ")] + fields)
            .map(normalize)
            .filter { !$0.isEmpty }
        guard !haystacks.isEmpty else { return nil }

        return haystacks.compactMap { score(query: normalizedQuery, haystack: $0) }.max()
    }

    private static func score(query normalizedQuery: String, haystack: String) -> Int? {
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
        if let wordStartScore = wordStartScore(query: normalizedQuery, words: words, haystackLength: haystack.count) {
            return wordStartScore
        }
        if let typoScore = typoScore(query: normalizedQuery, words: words) {
            return typoScore
        }
        return fuzzyScore(query: normalizedQuery, haystack: haystack)
    }

    private static func wordStartScore(query: String, words: [Substring], haystackLength: Int) -> Int? {
        let compactQuery = query.replacingOccurrences(of: " ", with: "")
        guard !compactQuery.isEmpty else { return nil }

        let initials = String(words.compactMap(\.first))
        if initials.hasPrefix(compactQuery) {
            return 7_500 - haystackLength
        }
        if let range = initials.range(of: compactQuery) {
            let distance = initials.distance(from: initials.startIndex, to: range.lowerBound)
            return 7_400 - distance * 20 - haystackLength
        }

        let queryWords = query.split(separator: " ")
        guard !queryWords.isEmpty else { return nil }

        var wordIndex = words.startIndex
        var matchedWords = 0
        for queryWord in queryWords {
            var found = false
            while wordIndex < words.endIndex {
                if words[wordIndex].hasPrefix(queryWord) {
                    matchedWords += 1
                    found = true
                    wordIndex = words.index(after: wordIndex)
                    break
                }
                wordIndex = words.index(after: wordIndex)
            }
            if !found { return nil }
        }

        return 7_250 + matchedWords * 20 - haystackLength
    }

    private static func typoScore(query: String, words: [Substring]) -> Int? {
        guard !query.contains(" "), query.count >= 4 else { return nil }
        let limit = query.count >= 8 ? 2 : 1
        return words.enumerated().compactMap { index, word -> Int? in
            let candidate = String(word)
            guard abs(candidate.count - query.count) <= limit else { return nil }
            let distance = editDistance(query, candidate, limit: limit)
            guard distance <= limit else { return nil }
            return 6_700 - distance * 250 - index * 10
        }.max()
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

    private static func editDistance(_ lhs: String, _ rhs: String, limit: Int) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)
        var previousPrevious = previous

        for i in 1...a.count {
            current[0] = i
            var rowMinimum = current[0]
            for j in 1...b.count {
                let substitutionCost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + substitutionCost
                )
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    current[j] = min(current[j], previousPrevious[j - 2] + 1)
                }
                rowMinimum = min(rowMinimum, current[j])
            }
            if rowMinimum > limit { return limit + 1 }
            previousPrevious = previous
            previous = current
        }

        return previous[b.count]
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
