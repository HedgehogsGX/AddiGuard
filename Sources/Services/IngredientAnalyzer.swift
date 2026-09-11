import Foundation

enum IngredientAnalyzer {
    static func analyze(
        text: String,
        profile: UserProfile,
        catalog: [Additive] = AdditiveCatalog.all
    ) -> AnalysisResult {
        let ingredientTokens = IngredientTextParser.parse(text: text, additives: catalog)
        let exactMatches = removingCorrectionSubstringConflicts(
            from: detect(in: text, catalog: catalog, profile: profile),
            ingredientTokens: ingredientTokens
        )
        let detected = recoveredIngredientMatches(
            ingredientTokens: ingredientTokens,
            catalog: catalog,
            profile: profile,
            existing: exactMatches
        )
        .sorted {
            if $0.additive.risk.severity == $1.additive.risk.severity {
                return $0.additive.name < $1.additive.name
            }
            return $0.additive.risk.severity > $1.additive.risk.severity
        }

        let highestRisk = detected.map(\.additive.risk).max { $0.severity < $1.severity } ?? .unrated
        // `-1` means unavailable. Ingredient names alone provide neither dose nor
        // exposure, so a numeric "safety" score would be false precision.
        let score = -1

        return AnalysisResult(
            recognizedText: text.trimmingCharacters(in: .whitespacesAndNewlines),
            additives: detected,
            safetyScore: score,
            overallRisk: highestRisk,
            summary: summary(for: detected),
            ingredientTokens: ingredientTokens
        )
    }

    /// Adds only confirmed parser matches that the broad exact matcher did not find.
    /// `possibleMatch` tokens are deliberately excluded: one-character fuzzy recovery
    /// is useful as a review prompt, but is not authoritative enough to affect risk.
    private static func recoveredIngredientMatches(
        ingredientTokens: [IngredientToken],
        catalog: [Additive],
        profile: UserProfile,
        existing: [DetectedAdditive]
    ) -> [DetectedAdditive] {
        var result = existing
        var selectedIDs = Set(existing.map(\.additive.id))
        let additiveByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

        for token in ingredientTokens where token.kind == .matchedAdditive {
            guard let additiveID = token.matchedAdditiveID,
                  selectedIDs.insert(additiveID).inserted,
                  let additive = additiveByID[additiveID] else {
                continue
            }

            let adjustedAdditive = adjustedAdditive(additive, for: profile)
            result.append(
                DetectedAdditive(
                    additive: adjustedAdditive,
                    matchedTerm: token.text,
                    personalizedNote: personalizedNote(
                        for: additive,
                        adjustedRisk: adjustedAdditive.risk,
                        profile: profile
                    )
                )
            )
        }
        return result
    }

    /// Broad matching can see a valid additive name inside an OCR-damaged token.
    /// When the parser has already resolved that whole token through a reviewed
    /// correction, discard only a different additive whose exact alias is a proper
    /// substring of the damaged source. An independently parsed exact ingredient
    /// always wins and keeps the broad match.
    private static func removingCorrectionSubstringConflicts(
        from matches: [DetectedAdditive],
        ingredientTokens: [IngredientToken]
    ) -> [DetectedAdditive] {
        let exactTokenIDs = Set(
            ingredientTokens.compactMap { token -> String? in
                guard token.kind == .matchedAdditive,
                      !token.matchedViaReviewedCorrection else {
                    return nil
                }
                return token.matchedAdditiveID
            }
        )
        let correctedTokens = ingredientTokens.filter {
            $0.kind == .matchedAdditive && $0.matchedViaReviewedCorrection
        }
        guard !correctedTokens.isEmpty else { return matches }

        return matches.filter { match in
            if exactTokenIDs.contains(match.additive.id) {
                return true
            }

            let matchedKey = normalizeCompact(match.matchedTerm)
            guard !matchedKey.isEmpty else { return true }

            return !correctedTokens.contains { token in
                guard token.matchedAdditiveID != match.additive.id else { return false }
                let sourceKey = normalizeCompact(token.text)
                return sourceKey.count > matchedKey.count && sourceKey.contains(matchedKey)
            }
        }
    }

    private enum MatchSpace {
        case compact
        case words
    }

    private struct MatchCandidate {
        let additive: Additive
        let catalogIndex: Int
        let matchedTerm: String
        let range: Range<Int>
        let space: MatchSpace
        let length: Int
        let isCompoundAlias: Bool
    }

    private static func detect(
        in text: String,
        catalog: [Additive],
        profile: UserProfile
    ) -> [DetectedAdditive] {
        let compactText = normalizeCompact(text)
        let wordText = normalizeWords(text)
        var candidates: [MatchCandidate] = []

        for (catalogIndex, additive) in catalog.enumerated() {
            for alias in additive.aliases {
                let usesCompactSpace = containsCJK(alias)
                let normalizedAlias = usesCompactSpace ? normalizeCompact(alias) : normalizeWords(alias)
                guard normalizedAlias.count >= 2 else { continue }
                let haystack = usesCompactSpace ? compactText : wordText
                let space: MatchSpace = usesCompactSpace ? .compact : .words

                for range in ranges(
                    of: normalizedAlias,
                    in: haystack,
                    requiresWordBoundaries: !usesCompactSpace
                ) where !isNegated(range, in: haystack, space: space) {
                    candidates.append(
                        MatchCandidate(
                            additive: additive,
                            catalogIndex: catalogIndex,
                            matchedTerm: alias,
                            range: range,
                            space: space,
                            length: normalizedAlias.count,
                            isCompoundAlias: usesCompactSpace && normalizedAlias.contains(" ")
                        )
                    )
                }
            }
        }

        candidates.sort {
            if $0.isCompoundAlias != $1.isCompoundAlias { return !$0.isCompoundAlias }
            if $0.length != $1.length { return $0.length > $1.length }
            if $0.additive.risk.severity != $1.additive.risk.severity {
                return $0.additive.risk.severity > $1.additive.risk.severity
            }
            return $0.catalogIndex < $1.catalogIndex
        }

        var occupiedCompact: [Range<Int>] = []
        var occupiedWords: [Range<Int>] = []
        var selectedIDs = Set<String>()
        var detected: [DetectedAdditive] = []

        for candidate in candidates where !selectedIDs.contains(candidate.additive.id) {
            let occupied = candidate.space == .compact ? occupiedCompact : occupiedWords
            guard !occupied.contains(where: { $0.overlaps(candidate.range) }) else { continue }

            selectedIDs.insert(candidate.additive.id)
            switch candidate.space {
            case .compact: occupiedCompact.append(candidate.range)
            case .words: occupiedWords.append(candidate.range)
            }
            let adjustedAdditive = adjustedAdditive(candidate.additive, for: profile)
            detected.append(
                DetectedAdditive(
                    additive: adjustedAdditive,
                    matchedTerm: candidate.matchedTerm,
                    personalizedNote: personalizedNote(
                        for: candidate.additive,
                        adjustedRisk: adjustedAdditive.risk,
                        profile: profile
                    )
                )
            )
        }
        return detected
    }

    private static func folded(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }

    private static func normalizeCompact(_ value: String) -> String {
        var output = ""
        var lastWasBoundary = true
        for character in folded(value) {
            if character.isLetter || character.isNumber {
                output.append(character)
                lastWasBoundary = false
            } else if character.isNewline {
                // A new OCR observation is a hard phrase boundary. Without this,
                // `柠檬酸\n钠：0mg` incorrectly becomes `柠檬酸钠`.
                if !lastWasBoundary {
                    output.append(" ")
                    lastWasBoundary = true
                }
            } else if character.isWhitespace || compactJoiners.contains(character) {
                // Same-line OCR spaces and name punctuation remain joinable, e.g.
                // `柠檬 酸钠` and `5’-呈味核苷酸二钠`.
                continue
            } else if !lastWasBoundary {
                // Other punctuation is an ingredient/phrase boundary. Keeping one
                // sentinel prevents `柠檬酸、钠` from becoming `柠檬酸钠`.
                output.append(" ")
                lastWasBoundary = true
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let compactJoiners: Set<Character> = [
        "-", "‐", "‑", "‒", "–", "—", "'", "’", "′", "\"", "“", "”"
    ]

    private static func normalizeWords(_ value: String) -> String {
        var output = ""
        var lastWasSpace = true
        for character in folded(value) {
            if character.isLetter || character.isNumber {
                output.append(character)
                lastWasSpace = false
            } else if !lastWasSpace {
                output.append(" ")
                lastWasSpace = true
            }
        }
        let tokens = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
        var mergedTokens: [String] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if ["e", "ins"].contains(token),
               index + 1 < tokens.count,
               tokens[index + 1].first?.isNumber == true {
                mergedTokens.append(token + tokens[index + 1])
                index += 2
            } else {
                mergedTokens.append(token)
                index += 1
            }
        }
        return mergedTokens.joined(separator: " ")
    }

    private static func containsCJK(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value) ||
                (0x4E00...0x9FFF).contains(scalar.value) ||
                (0xF900...0xFAFF).contains(scalar.value)
        }
    }

    private static func ranges(
        of needle: String,
        in haystack: String,
        requiresWordBoundaries: Bool
    ) -> [Range<Int>] {
        let needleCharacters = Array(needle)
        let haystackCharacters = Array(haystack)
        guard !needleCharacters.isEmpty, needleCharacters.count <= haystackCharacters.count else { return [] }

        var result: [Range<Int>] = []
        let lastStart = haystackCharacters.count - needleCharacters.count
        for start in 0...lastStart {
            let end = start + needleCharacters.count
            guard Array(haystackCharacters[start..<end]) == needleCharacters else { continue }
            if requiresWordBoundaries {
                let hasLeadingBoundary = start == 0 || haystackCharacters[start - 1] == " "
                let hasTrailingBoundary = end == haystackCharacters.count || haystackCharacters[end] == " "
                guard hasLeadingBoundary && hasTrailingBoundary else { continue }
            }
            result.append(start..<end)
        }
        return result
    }

    private static func isNegated(_ range: Range<Int>, in haystack: String, space: MatchSpace) -> Bool {
        let characters = Array(haystack)

        switch space {
        case .compact:
            var segmentStart = range.lowerBound
            while segmentStart > 0, characters[segmentStart - 1] != " " { segmentStart -= 1 }
            var segmentEnd = range.upperBound
            while segmentEnd < characters.count, characters[segmentEnd] != " " { segmentEnd += 1 }

            let compactPrefix = String(characters[segmentStart..<range.lowerBound])
            let compactSuffix = String(characters[range.upperBound..<segmentEnd])

            var previousStart = segmentStart
            while previousStart > 0, characters[previousStart - 1] == " " { previousStart -= 1 }
            let previousEnd = previousStart
            while previousStart > 0, characters[previousStart - 1] != " " { previousStart -= 1 }
            let previousSegment = String(characters[previousStart..<previousEnd])

            var nextStart = segmentEnd
            while nextStart < characters.count, characters[nextStart] == " " { nextStart += 1 }
            var nextEnd = nextStart
            while nextEnd < characters.count, characters[nextEnd] != " " { nextEnd += 1 }
            let nextSegment = String(characters[nextStart..<nextEnd])

            let prefixMarkers = [
                "不含", "无添加", "未添加", "不添加", "零添加", "0添加",
                "没有添加", "不使用", "未使用", "未检出", "无检出"
            ]
            let suffixMarkers = ["未检出", "无检出", "未添加", "不含"]
            return prefixMarkers.contains { compactPrefix.contains($0) || previousSegment.hasSuffix($0) }
                || suffixMarkers.contains { compactSuffix.contains($0) || nextSegment.hasPrefix($0) }
        case .words:
            let prefixStart = max(0, range.lowerBound - 48)
            let suffixEnd = min(characters.count, range.upperBound + 32)
            let prefix = String(characters[prefixStart..<range.lowerBound])
            let suffix = String(characters[range.upperBound..<suffixEnd])
            let paddedPrefix = " \(prefix) "
            let paddedSuffix = " \(suffix) "
            let prefixMarkers = [
                " no ", " without ", " free from ", " free of ",
                " not detected ", " contains no ", " does not contain "
            ]
            let suffixMarkers = [" not detected ", " absent ", " not added "]
            return prefixMarkers.contains { paddedPrefix.contains($0) }
                || suffixMarkers.contains { paddedSuffix.contains($0) }
        }
    }

    private static func adjustedAdditive(_ additive: Additive, for profile: UserProfile) -> Additive {
        var adjustedRisk = additive.risk
        let isAllergyRelevant = ["sodium-metabisulfite", "sodium-benzoate", "lecithin"].contains(additive.id)
        if profile.allergySensitive, isAllergyRelevant {
            adjustedRisk = elevated(adjustedRisk)
        }
        if profile.prefersStricterWarnings, adjustedRisk == .low {
            adjustedRisk = .moderate
        }
        guard adjustedRisk != additive.risk else { return additive }

        return Additive(
            id: additive.id,
            name: additive.name,
            englishName: additive.englishName,
            code: additive.code,
            aliases: additive.aliases,
            function: additive.function,
            risk: adjustedRisk,
            summary: additive.summary,
            healthEffects: additive.healthEffects,
            recommendation: additive.recommendation,
            sources: additive.sources
        )
    }

    private static func elevated(_ risk: RiskLevel) -> RiskLevel {
        switch risk {
        case .low: .moderate
        case .moderate: .high
        case .high: .high
        case .unrated: .unrated
        }
    }

    private static func personalizedNote(
        for additive: Additive,
        adjustedRisk: RiskLevel,
        profile: UserProfile
    ) -> String? {
        var notes: [String] = []
        let isAllergyRelevant = ["sodium-metabisulfite", "sodium-benzoate", "lecithin"].contains(additive.id)
        if profile.allergySensitive, isAllergyRelevant, adjustedRisk != additive.risk {
            notes.append("已根据你的过敏敏感设置将关注等级从\(additive.risk.title)调整为\(adjustedRisk.title)。")
        }
        if profile.prefersStricterWarnings, additive.risk == .low, adjustedRisk == .moderate {
            notes.append("已启用严格预警：关注等级从较低关注调整为需核对。")
        }

        switch profile.populationGroup {
        case .child where [.moderate, .high].contains(adjustedRisk):
            notes.append("儿童需结合体重、食品类别和实际摄入量核对，必要时咨询专业人员。")
        case .pregnant where adjustedRisk == .high:
            notes.append("孕期请结合食品类别与实际摄入量核对，存在疑问时咨询医生或营养专业人员。")
        case .chronicCondition where additive.id == "monosodium-glutamate":
            notes.append("请把该成分计入全天钠摄入，并遵循医生给出的饮食建议。")
        default:
            break
        }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    private static func summary(for matches: [DetectedAdditive]) -> String {
        guard !matches.isEmpty else {
            return "暂未在本地知识库中识别到常见添加剂，结果为不确定，不能据此判断为较低关注或安全。请核对 OCR 文本或咨询专业人员。"
        }

        let highCount = matches.filter { $0.additive.risk == .high }.count
        let moderateCount = matches.filter { $0.additive.risk == .moderate }.count
        let lowCount = matches.filter { $0.additive.risk == .low }.count
        let unratedCount = matches.filter { $0.additive.risk == .unrated }.count

        var ratedParts: [String] = []
        if highCount > 0 { ratedParts.append("高关注 \(highCount) 种") }
        if moderateCount > 0 { ratedParts.append("需核对 \(moderateCount) 种") }
        if lowCount > 0 { ratedParts.append("较低关注 \(lowCount) 种") }

        var parts: [String] = []
        if !ratedParts.isEmpty {
            parts.append("已评级：\(ratedParts.joined(separator: "、"))。")
        }
        if unratedCount > 0 {
            parts.append("未评级：另有 \(unratedCount) 种已收录但尚未独立分级，不能据此判断安全性；请结合食品类别和用量核对标准。")
        }
        if highCount > 0 || moderateCount > 0 {
            parts.append("请核对食品类别、标示用量或实际摄入量及适用标准，必要时咨询专业人员。")
        } else if lowCount > 0 {
            parts.append("关注等级不代表具体产品一定安全，仍需结合食品类别和实际摄入量判断。")
        }
        return parts.joined(separator: " ")
    }
}
