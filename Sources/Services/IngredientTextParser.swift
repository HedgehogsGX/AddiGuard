import Foundation

/// A label ingredient preserved in source order for display and review.
struct IngredientToken: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        /// An exact catalog alias or a reviewed, whole-token OCR correction.
        case matchedAdditive
        /// A common food ingredient that is not an additive catalog entry.
        case ordinaryIngredient
        /// A unique one-character suggestion that still requires user confirmation.
        case possibleMatch
        /// Text found in the ingredient list that the local rules cannot classify.
        case unresolved
    }

    let id: String
    let text: String
    let kind: Kind
    let matchedAdditiveID: String?
    let matchedAdditiveName: String?
    /// True only for a confirmed additive promoted by a reviewed whole-token
    /// OCR correction. Fuzzy suggestions and exact catalog aliases are false.
    let matchedViaReviewedCorrection: Bool
}

/// Extracts labelled ingredient sections and classifies their leaf ingredients locally.
///
/// Fuzzy recovery intentionally runs only inside a section headed by `配料`/`配料表`
/// or `Ingredients`. Exact catalog matching elsewhere remains the responsibility of
/// `IngredientAnalyzer`, which preserves its existing backwards-compatible behavior.
enum IngredientTextParser {
    static func parse(
        text: String,
        additives: [Additive] = AdditiveCatalog.all
    ) -> [IngredientToken] {
        let matcher = CatalogMatcher(additives: additives)
        let sections = extractSections(from: text)
        var tokens: [IngredientToken] = []

        for (sectionIndex, section) in sections.enumerated() {
            let leaves = leafTokens(
                in: section,
                explicitlyAdditive: false,
                matcher: matcher
            )

            for (leafIndex, leaf) in leaves.enumerated() {
                let text = cleanedToken(leaf.text)
                guard !text.isEmpty else { continue }

                let classification = matcher.classify(
                    text,
                    explicitlyAdditive: leaf.explicitlyAdditive
                )
                let matchedAdditive: Additive?
                let kind: IngredientToken.Kind
                let matchedViaReviewedCorrection: Bool

                switch classification {
                case .matched(let additive, let viaReviewedCorrection):
                    matchedAdditive = additive
                    kind = .matchedAdditive
                    matchedViaReviewedCorrection = viaReviewedCorrection
                case .possible(let additive):
                    matchedAdditive = additive
                    kind = .possibleMatch
                    matchedViaReviewedCorrection = false
                case .ordinary:
                    matchedAdditive = nil
                    kind = .ordinaryIngredient
                    matchedViaReviewedCorrection = false
                case .unresolved:
                    matchedAdditive = nil
                    kind = .unresolved
                    matchedViaReviewedCorrection = false
                }

                tokens.append(
                    IngredientToken(
                        id: stableID(sectionIndex: sectionIndex, leafIndex: leafIndex),
                        text: text,
                        kind: kind,
                        matchedAdditiveID: matchedAdditive?.id,
                        matchedAdditiveName: matchedAdditive?.name,
                        matchedViaReviewedCorrection: matchedViaReviewedCorrection
                    )
                )
            }
        }

        return tokens
    }

    // MARK: - Section extraction

    private static func extractSections(from text: String) -> [String] {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedText.components(separatedBy: "\n")
        var sections: [String] = []
        var currentSection: String?

        func finishCurrentSection() {
            guard let currentSection else { return }
            let value = truncateAtMetadataHeading(currentSection)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                sections.append(value)
            }
        }

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            if let content = ingredientContent(afterHeadingIn: trimmedLine) {
                finishCurrentSection()
                currentSection = content
                continue
            }

            guard currentSection != nil else { continue }
            if startsWithMetadataHeading(trimmedLine) {
                finishCurrentSection()
                currentSection = nil
            } else {
                currentSection = [currentSection, trimmedLine]
                    .compactMap { $0 }
                    .joined(separator: " ")
            }
        }

        finishCurrentSection()
        return sections
    }

    private static func ingredientContent(afterHeadingIn line: String) -> String? {
        let markers = ["配料表", "配料", "ingredients list", "ingredients"]

        for marker in markers {
            guard let markerRange = line.range(
                of: marker,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "zh_CN")
            ) else { continue }
            let rawTail = String(line[markerRange.upperBound...])
            let whitespaceTrimmed = rawTail.trimmingCharacters(in: .whitespaces)

            if whitespaceTrimmed.isEmpty {
                return ""
            }
            if let first = whitespaceTrimmed.first, headingSeparators.contains(first) {
                return String(whitespaceTrimmed.dropFirst())
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Accept a heading separated from its value by whitespace, but reject
            // prose such as “请拍摄配料表照片”. Product-prefixed headings such as
            // “调味汁包配料表：” are already handled by the colon branch above.
            if rawTail.first?.isWhitespace == true,
               !startsWithMetadataHeading(whitespaceTrimmed) {
                return whitespaceTrimmed
            }

            // Vision occasionally drops the colon after a heading. Only accept
            // that shape when the heading starts the line and the tail has strong
            // list punctuation, so prose mentioning 配料/ingredients is not captured.
            let headingPrefix = String(line[..<markerRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if headingPrefix.isEmpty, looksLikeIngredientList(whitespaceTrimmed) {
                return whitespaceTrimmed
            }
        }
        return nil
    }

    private static func looksLikeIngredientList(_ value: String) -> Bool {
        let foldedValue = canonical(value)
        let proseMarkers = ["说明", "照片", "请查看", "请参考", "information", "instructions"]
        guard !proseMarkers.contains(where: { foldedValue.contains(canonical($0)) }) else {
            return false
        }

        let separatorCount = value.filter { ingredientSeparators.contains($0) }.count
        return separatorCount >= 2
    }

    private static let headingSeparators: Set<Character> = [":", "：", "﹕"]

    private static let metadataHeadings = [
        "产品名称", "品名", "产品类型", "产品类别", "生产者", "生产商", "制造商", "经销商",
        "委托方", "受委托方", "地址", "产地", "原产国", "食品生产许可证", "生产许可证",
        "许可证", "执行标准", "产品标准", "标准号", "保质期", "生产日期", "净含量", "规格",
        "营养成分", "营养信息", "贮存", "储存", "保存方法", "食用方法", "服务热线", "服务电话",
        "条形码", "manufacturer", "distributed by", "nutrition facts", "nutrition information",
        "best before", "net weight", "storage", "country of origin"
    ]

    private static func startsWithMetadataHeading(_ value: String) -> Bool {
        let foldedValue = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "zh_CN")
        )
        return metadataHeadings.contains { heading in
            guard foldedValue.hasPrefix(heading) else { return false }
            let boundaryIndex = foldedValue.index(foldedValue.startIndex, offsetBy: heading.count)
            guard boundaryIndex < foldedValue.endIndex else { return true }
            let boundary = foldedValue[boundaryIndex]
            return boundary.isWhitespace || headingSeparators.contains(boundary)
        }
    }

    private static func truncateAtMetadataHeading(_ value: String) -> String {
        var earliest: String.Index?

        for heading in metadataHeadings {
            var searchStart = value.startIndex
            while searchStart < value.endIndex,
                  let range = value.range(
                    of: heading,
                    options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                    range: searchStart..<value.endIndex,
                    locale: Locale(identifier: "zh_CN")
                  ) {
                let isSeparated = range.lowerBound > value.startIndex && {
                    let previous = value[value.index(before: range.lowerBound)]
                    return previous.isWhitespace || ingredientSeparators.contains(previous)
                }()
                let hasHeadingBoundary = range.upperBound == value.endIndex || {
                    let next = value[range.upperBound]
                    return next.isWhitespace || headingSeparators.contains(next)
                }()
                if isSeparated && hasHeadingBoundary {
                    if earliest == nil || range.lowerBound < earliest! {
                        earliest = range.lowerBound
                    }
                    break
                }
                searchStart = range.upperBound
            }
        }

        guard let earliest else { return value }
        return String(value[..<earliest])
    }

    // MARK: - Tokenization

    private struct LeafToken {
        let text: String
        let explicitlyAdditive: Bool
    }

    private static func leafTokens(
        in value: String,
        explicitlyAdditive: Bool,
        matcher: CatalogMatcher,
        depth: Int = 0
    ) -> [LeafToken] {
        guard depth < 5 else {
            return [LeafToken(text: value, explicitlyAdditive: explicitlyAdditive)]
        }

        var result: [LeafToken] = []
        var activeAdditiveContext = explicitlyAdditive
        for rawSegment in splitAtTopLevelSeparators(value) {
            let segment = cleanedToken(rawSegment)
            guard !segment.isEmpty else { continue }

            if let forcedContent = contentAfterAdditiveLabel(in: segment) {
                result.append(contentsOf: leafTokens(
                    in: forcedContent,
                    explicitlyAdditive: true,
                    matcher: matcher,
                    depth: depth + 1
                ))
                // In `食品添加剂：A、B、C`, the label applies to the remaining
                // siblings, not only the text before the first comma.
                activeAdditiveContext = true
                continue
            }

            if let confirmedPieces = confirmedWhitespacePieces(
                in: segment,
                matcher: matcher
            ) {
                result.append(contentsOf: confirmedPieces.map {
                    LeafToken(text: $0, explicitlyAdditive: activeAdditiveContext)
                })
                continue
            }

            guard let group = firstParentheticalGroup(in: segment) else {
                result.append(LeafToken(text: segment, explicitlyAdditive: activeAdditiveContext))
                continue
            }

            let prefix = cleanedToken(group.prefix)
            let inner = cleanedToken(group.inner)
            let suffix = cleanedToken(group.suffix)

            if isAdditiveGroupLabel(prefix) {
                result.append(contentsOf: leafTokens(
                    in: inner,
                    explicitlyAdditive: true,
                    matcher: matcher,
                    depth: depth + 1
                ))
                if !suffix.isEmpty {
                    result.append(contentsOf: leafTokens(
                        in: suffix,
                        explicitlyAdditive: activeAdditiveContext,
                        matcher: matcher,
                        depth: depth + 1
                    ))
                }
                continue
            }

            // Parentheses often contain an alias or E-number for the same additive.
            // Preserve that as one token rather than producing duplicate rows.
            if matcher.exactMatch(for: prefix) != nil || matcher.exactMatch(for: segment) != nil {
                result.append(LeafToken(text: segment, explicitlyAdditive: activeAdditiveContext))
                continue
            }

            let strippedInner = strippingContainmentPrefix(inner)
            let exposesComposition = containsIngredientSeparator(inner)
                || strippedInner != inner
                || matcher.exactMatch(for: strippedInner) != nil

            if exposesComposition {
                if !prefix.isEmpty {
                    result.append(LeafToken(text: prefix, explicitlyAdditive: activeAdditiveContext))
                }
                result.append(contentsOf: leafTokens(
                    in: strippedInner,
                    explicitlyAdditive: activeAdditiveContext,
                    matcher: matcher,
                    depth: depth + 1
                ))
                if !suffix.isEmpty {
                    result.append(contentsOf: leafTokens(
                        in: suffix,
                        explicitlyAdditive: activeAdditiveContext,
                        matcher: matcher,
                        depth: depth + 1
                    ))
                }
            } else {
                result.append(LeafToken(text: segment, explicitlyAdditive: activeAdditiveContext))
            }
        }
        return result
    }

    private static let ingredientSeparators: Set<Character> = [
        ",", "，", "、", ";", "；", ".", "。", "•", "·", "|", "｜"
    ]

    private static func confirmedWhitespacePieces(
        in value: String,
        matcher: CatalogMatcher
    ) -> [String]? {
        let pieces = value
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard pieces.count > 1,
              pieces.allSatisfy({ matcher.isConfirmedStandaloneToken($0) }) else {
            return nil
        }
        return pieces
    }

    private static func splitAtTopLevelSeparators(_ value: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var stack: [Character] = []

        for character in value {
            if let expectedCloser = parenthesisPairs[character] {
                stack.append(expectedCloser)
                current.append(character)
            } else if stack.last == character {
                stack.removeLast()
                current.append(character)
            } else if stack.isEmpty, ingredientSeparators.contains(character) {
                segments.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        segments.append(current)
        return segments
    }

    private static let parenthesisPairs: [Character: Character] = [
        "(": ")", "（": "）", "[": "]", "【": "】"
    ]

    private struct ParentheticalGroup {
        let prefix: String
        let inner: String
        let suffix: String
    }

    private static func firstParentheticalGroup(in value: String) -> ParentheticalGroup? {
        let characters = Array(value)
        guard let openingIndex = characters.firstIndex(where: { parenthesisPairs[$0] != nil }),
              let expectedCloser = parenthesisPairs[characters[openingIndex]] else {
            return nil
        }

        var depth = 0
        for index in openingIndex..<characters.count {
            let character = characters[index]
            if character == characters[openingIndex] {
                depth += 1
            } else if character == expectedCloser {
                depth -= 1
                if depth == 0 {
                    return ParentheticalGroup(
                        prefix: String(characters[..<openingIndex]),
                        inner: String(characters[(openingIndex + 1)..<index]),
                        suffix: String(characters[(index + 1)...])
                    )
                }
            }
        }
        return nil
    }

    private static func contentAfterAdditiveLabel(in value: String) -> String? {
        let separators: Set<Character> = [":", "：", "﹕"]
        guard let separatorIndex = value.firstIndex(where: { separators.contains($0) }) else {
            return nil
        }
        let label = String(value[..<separatorIndex])
        guard isAdditiveGroupLabel(label) else { return nil }
        return String(value[value.index(after: separatorIndex)...])
    }

    private static func isAdditiveGroupLabel(_ value: String) -> Bool {
        let key = canonical(value)
        return [
            "食品添加剂", "添加剂", "复配食品添加剂",
            "foodadditive", "foodadditives", "additive", "additives"
        ].contains(key)
    }

    private static func containsIngredientSeparator(_ value: String) -> Bool {
        value.contains(where: { ingredientSeparators.contains($0) })
    }

    private static func strippingContainmentPrefix(_ value: String) -> String {
        let prefixes = ["其中含有", "其中含", "内含", "含有", "含"]
        for prefix in prefixes where value.hasPrefix(prefix) {
            return cleanedToken(String(value.dropFirst(prefix.count)))
        }
        return value
    }

    private static func cleanedToken(_ value: String) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines.union(
                CharacterSet(charactersIn: ",，、;；.。•·|｜:：﹕")
            )
        )
    }

    /// Deliberately excludes ingredient text so the identifier sent to an API is
    /// opaque and cannot reveal extra label content by itself.
    private static func stableID(sectionIndex: Int, leafIndex: Int) -> String {
        "ingredient-\(sectionIndex)-\(leafIndex)"
    }

    // MARK: - Matching

    private enum Classification {
        case matched(Additive, viaReviewedCorrection: Bool)
        case possible(Additive)
        case ordinary
        case unresolved
    }

    private struct CatalogMatcher {
        private struct AliasEntry {
            let key: String
            let additive: Additive
            let catalogIndex: Int
        }

        private let exactAliases: [String: Additive]
        private let chineseAliases: [AliasEntry]

        init(additives: [Additive]) {
            var exactAliases: [String: Additive] = [:]
            var chineseAliases: [AliasEntry] = []
            var seenChineseAliases = Set<String>()

            for (catalogIndex, additive) in additives.enumerated() {
                for alias in additive.aliases + [additive.name] {
                    let key = canonical(alias)
                    guard key.count >= 2 else { continue }
                    // Catalog order is authoritative: reviewed entries precede the
                    // broader GB supplement in AdditiveCatalog.
                    if exactAliases[key] == nil {
                        exactAliases[key] = additive
                    }
                    let uniqueKey = "\(additive.id)|\(key)"
                    if isChineseOnly(key), key.count <= 14,
                       seenChineseAliases.insert(uniqueKey).inserted {
                        chineseAliases.append(
                            AliasEntry(key: key, additive: additive, catalogIndex: catalogIndex)
                        )
                    }
                }
            }
            self.exactAliases = exactAliases
            self.chineseAliases = chineseAliases
        }

        func exactMatch(for text: String) -> Additive? {
            guard !isNegated(text) else { return nil }
            for key in matchingKeys(for: text) {
                if let additive = exactAliases[key] {
                    return additive
                }
            }
            return nil
        }

        func classify(_ text: String, explicitlyAdditive: Bool) -> Classification {
            guard !isNegated(text) else { return .unresolved }
            if let exact = exactMatch(for: text) {
                return .matched(exact, viaReviewedCorrection: false)
            }

            let keys = matchingKeys(for: text)
            guard let primaryKey = keys.first else { return .unresolved }
            for key in keys {
                if let correctedAlias = knownOCRCorrections[key],
                   let corrected = exactAliases[correctedAlias] {
                    return .matched(corrected, viaReviewedCorrection: true)
                }
            }

            if keys.contains(where: isReviewedOrdinaryCorrection) {
                return .ordinary
            }

            if let possible = uniqueFuzzyMatch(
                for: primaryKey,
                explicitlyAdditive: explicitlyAdditive
            ) {
                return .possible(possible)
            }

            return isOrdinaryIngredient(primaryKey) ? .ordinary : .unresolved
        }

        func isConfirmedStandaloneToken(_ text: String) -> Bool {
            guard !isNegated(text) else { return false }
            if exactMatch(for: text) != nil { return true }

            let keys = matchingKeys(for: text)
            return keys.contains { key in
                if let correctedAlias = knownOCRCorrections[key],
                   exactAliases[correctedAlias] != nil {
                    return true
                }
                return isOrdinaryIngredient(key) || isReviewedOrdinaryCorrection(key)
            }
        }

        private func isReviewedOrdinaryCorrection(_ key: String) -> Bool {
            guard let correctedKey = knownOrdinaryOCRCorrections[key] else { return false }
            return isOrdinaryIngredient(correctedKey)
        }

        private func uniqueFuzzyMatch(
            for key: String,
            explicitlyAdditive: Bool
        ) -> Additive? {
            let minimumLength = explicitlyAdditive ? 3 : 4
            guard key.count >= minimumLength,
                  isChineseOnly(key),
                  explicitlyAdditive || hasAdditiveShape(key) else {
                return nil
            }

            let matches = chineseAliases.filter { alias in
                alias.key.count == key.count
                    && alias.key.count >= minimumLength
                    && substitutionDistance(alias.key, key) == 1
            }
            let grouped = Dictionary(grouping: matches, by: { $0.additive.id })
            guard grouped.count == 1,
                  let onlyMatches = grouped.values.first else {
                return nil
            }
            return onlyMatches.min(by: { $0.catalogIndex < $1.catalogIndex })?.additive
        }
    }

    /// Reviewed whole-token corrections only. These are not global character
    /// substitutions, so a typo in product or manufacturer prose cannot be promoted.
    private static let knownOCRCorrections: [String: String] = [
        "安塞蜜": "安赛蜜",
        "安赛密": "安赛蜜",
        "安塞密": "安赛蜜",
        "苯甲酸纳": "苯甲酸钠",
        "柠檬酸纳": "柠檬酸钠",
        "三氯庶糖": "三氯蔗糖",
        "庶糖素": "蔗糖素",
        "二氧化炭": "二氧化碳",
        "二氣化碳": "二氧化碳",
        "柠碳酸钠": "柠檬酸钠"
    ]

    /// Corrections in this map affect only ordinary/additive classification; the
    /// original OCR text remains the token's displayed `text`.
    private static let knownOrdinaryOCRCorrections: [String: String] = [
        "果葡糖菜": "果葡糖浆"
    ]

    private static let ordinaryIngredients: Set<String> = [
        "水", "饮用水", "纯净水", "矿泉水", "天然水", "白砂糖", "绵白糖", "红糖", "冰糖",
        "果糖", "葡萄糖", "果葡糖浆", "高果糖浆", "麦芽糖浆", "玉米糖浆", "蜂蜜", "食用盐",
        "海盐", "植物油", "大豆油", "菜籽油", "花生油", "葵花籽油", "棕榈油", "面粉", "小麦粉",
        "淀粉", "玉米淀粉", "马铃薯淀粉", "木薯淀粉", "鸡蛋", "全蛋液", "牛奶", "生牛乳",
        "乳粉", "奶粉", "乳清粉", "可可粉", "咖啡", "茶叶", "果汁", "浓缩果汁", "酵母",
        "香辛料", "芝麻", "芝麻酱", "花生", "大葱", "葱", "姜", "蒜",
        "water", "sugar", "white sugar", "fructose", "glucose", "glucose syrup", "corn syrup",
        "salt", "sea salt", "vegetable oil", "soybean oil", "flour", "wheat flour", "starch", "egg",
        "milk", "milk powder", "cocoa powder", "coffee", "tea", "fruit juice", "yeast", "spices"
    ].reduce(into: Set<String>()) { result, value in
        result.insert(canonical(value))
    }

    private static func isOrdinaryIngredient(_ key: String) -> Bool {
        if ordinaryIngredients.contains(key) { return true }
        let withoutQuantity = String(key.prefix { !$0.isNumber })
        return !withoutQuantity.isEmpty && ordinaryIngredients.contains(withoutQuantity)
    }

    private static func matchingKeys(for text: String) -> [String] {
        var keys = [canonical(text)]
        if let group = firstParentheticalGroup(in: text) {
            keys.append(canonical(group.prefix))
            keys.append(canonical(group.inner))
        }
        var seen = Set<String>()
        return keys.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static func isNegated(_ value: String) -> Bool {
        let key = canonical(value)
        let prefixMarkers = [
            "不含", "无添加", "未添加", "不添加", "零添加", "0添加",
            "没有添加", "不使用", "未使用", "未检出", "无检出"
        ]
        let suffixMarkers = ["未检出", "无检出", "未添加", "不含"]
        return prefixMarkers.contains(where: { key.hasPrefix($0) })
            || suffixMarkers.contains(where: { key.hasSuffix($0) })
    }

    private static func hasAdditiveShape(_ value: String) -> Bool {
        let suffixes = [
            "酸", "酸钠", "酸钾", "酸钙", "胶", "素", "酯", "醇", "酶", "色", "盐",
            "剂", "蜜", "精", "酮", "酚", "铵", "钙", "钠", "钾", "铁", "锌"
        ]
        return suffixes.contains(where: { value.hasSuffix($0) })
    }

    private static func substitutionDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        guard left.count == right.count else { return .max }
        var differenceCount = 0
        for (leftCharacter, rightCharacter) in zip(left, right) where leftCharacter != rightCharacter {
            differenceCount += 1
            if differenceCount > 1 { return differenceCount }
        }
        return differenceCount
    }

    private static func canonical(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "zh_CN")
            )
            .filter { $0.isLetter || $0.isNumber }
            .lowercased()
    }

    private static func isChineseOnly(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
        }
    }
}
