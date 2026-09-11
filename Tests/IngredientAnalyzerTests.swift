import XCTest
@testable import AddiGuard

final class IngredientAnalyzerTests: XCTestCase {
    func testDetectsAndSortsAdditivesByRisk() {
        let result = IngredientAnalyzer.analyze(
            text: "配料：柠檬酸、山梨酸钾、亚硝酸钠、维生素C",
            profile: UserProfile()
        )

        XCTAssertEqual(result.additives.map(\.additive.id), [
            "sodium-nitrite",
            "potassium-sorbate",
            "ascorbic-acid",
            "citric-acid"
        ])
        XCTAssertEqual(result.overallRisk, .high)
        XCTAssertEqual(result.safetyScore, -1)
    }

    func testEnglishNamesAndECodesAreCaseInsensitive() {
        let result = IngredientAnalyzer.analyze(
            text: "Ingredients: water, SODIUM BENZOATE, E300, e330",
            profile: UserProfile()
        )

        XCTAssertEqual(Set(result.additives.map(\.additive.id)), [
            "sodium-benzoate",
            "ascorbic-acid",
            "citric-acid"
        ])
    }

    func testSensitiveProfileRaisesVisiblePriorityAndAddsNote() {
        let general = IngredientAnalyzer.analyze(
            text: "配料：焦亚硫酸钠",
            profile: UserProfile()
        )
        let sensitive = IngredientAnalyzer.analyze(
            text: "配料：焦亚硫酸钠",
            profile: UserProfile(populationGroup: .child, allergySensitive: true)
        )

        XCTAssertEqual(general.additives.first?.additive.risk, .moderate)
        XCTAssertEqual(sensitive.additives.first?.additive.risk, .high)
        XCTAssertEqual(general.safetyScore, -1)
        XCTAssertEqual(sensitive.safetyScore, -1)
        XCTAssertNotNil(sensitive.additives.first?.personalizedNote)
    }

    func testUnknownIngredientsReturnEmptyResult() {
        let result = IngredientAnalyzer.analyze(
            text: "配料：水、面粉、鸡蛋",
            profile: UserProfile()
        )

        XCTAssertTrue(result.additives.isEmpty)
        XCTAssertEqual(result.safetyScore, -1)
        XCTAssertEqual(result.overallRisk, .unrated)
        XCTAssertTrue(result.summary.contains("不确定"))
    }

    func testRealNoodleLabelDetectsAllNamedAdditives() {
        let recognizedText = """
        产品名称：绿豆捞凉粉（即食）
        绿豆捞凉粉配料表：饮用水、绿豆淀粉、食用香精
        调味酱包配料表：芝麻酱、植物油、辣椒、大葱、酵母提取物、香辛料、食用香精、食品添加剂（辣椒红）
        调味汁包配料表：饮用水、食品添加剂（谷氨酸钠、5’-呈味核
        苷酸二钠）、白砂糖、食用盐、酿造食醋、酿造酱油（含焦糖色）
        """

        let result = IngredientAnalyzer.analyze(text: recognizedText, profile: UserProfile())

        XCTAssertEqual(Set(result.additives.map(\.additive.id)), [
            "food-flavouring",
            "paprika-extract",
            "monosodium-glutamate",
            "disodium-ribonucleotides",
            "caramel-colour"
        ])
        XCTAssertEqual(ProductNameParser.extract(from: recognizedText), "绿豆捞凉粉（即食）")
    }

    func testRealRiceDrinkLabelHasNoTrackedAdditives() {
        let recognizedText = """
        产品名称：有机胚芽米奶
        产品类型：植物饮料（谷物饮料）
        配料：饮用水、有机胚芽米浓浆≥50%（饮用水、有机胚芽米、有机葵花籽油、竹盐）
        """

        let result = IngredientAnalyzer.analyze(text: recognizedText, profile: UserProfile())

        XCTAssertTrue(result.additives.isEmpty)
        XCTAssertEqual(ProductNameParser.extract(from: recognizedText), "有机胚芽米奶")
    }

    func testCatalogIncludesBroadGB2760Coverage() {
        XCTAssertEqual(GB2760Catalog.all.count, 287)
        XCTAssertGreaterThanOrEqual(AdditiveCatalog.all.count, 285)

        let result = IngredientAnalyzer.analyze(
            text: "配料：阿斯巴甜、安赛蜜、卡拉胶、黄原胶、甜菊糖苷、三氯蔗糖、丙酸钙、磷酸氢二钠、羧甲基纤维素钠、赤藓糖醇",
            profile: UserProfile()
        )

        XCTAssertEqual(result.additives.count, 10)
        XCTAssertTrue(result.additives.allSatisfy { $0.additive.sources.contains("GB 2760-2024") })
        XCTAssertTrue(result.additives.contains { $0.additive.name == "阿斯巴甜" })
        XCTAssertTrue(result.additives.contains { $0.additive.name == "磷酸及磷酸盐" })
    }

    func testRecognizesSpacedAndHyphenatedInternationalCodes() {
        let result = IngredientAnalyzer.analyze(
            text: "Ingredients: E 951, INS-415, e955, E 202",
            profile: UserProfile()
        )

        XCTAssertEqual(result.additives.count, 4)
        XCTAssertTrue(result.additives.contains { $0.additive.name == "阿斯巴甜" })
        XCTAssertTrue(result.additives.contains { $0.additive.name == "黄原胶" })
        XCTAssertTrue(result.additives.contains { $0.additive.id == "sucralose" })
        XCTAssertTrue(result.additives.contains { $0.additive.id == "potassium-sorbate" })
    }

    func testLongerSpecificNameDoesNotAlsoMatchItsPrefix() {
        let citrateOnly = IngredientAnalyzer.analyze(
            text: "配料：柠檬酸钠",
            profile: UserProfile()
        )
        XCTAssertEqual(citrateOnly.additives.count, 1)
        XCTAssertEqual(citrateOnly.additives.first?.additive.name, "柠檬酸钠")

        let both = IngredientAnalyzer.analyze(
            text: "配料：柠檬酸钠、柠檬酸",
            profile: UserProfile()
        )
        XCTAssertEqual(both.additives.count, 2)
        XCTAssertTrue(both.additives.contains { $0.additive.id == "citric-acid" })
    }

    func testUnreviewedStandardEntryIsNotMisrepresentedAsLowRisk() {
        let result = IngredientAnalyzer.analyze(
            text: "配料：亚硝酸钾",
            profile: UserProfile()
        )

        XCTAssertEqual(result.additives.count, 1)
        XCTAssertEqual(result.additives.first?.additive.risk, .unrated)
        XCTAssertEqual(result.overallRisk, .unrated)
        XCTAssertEqual(result.safetyScore, -1)
    }

    func testCodeAliasesRequireWordBoundaries() {
        let result = IngredientAnalyzer.analyze(
            text: "internal codeE250x reference",
            profile: UserProfile()
        )

        XCTAssertTrue(result.additives.isEmpty)
    }

    func testEAndINSCodesResolveToTheSameCuratedRecord() {
        let citricAcid = IngredientAnalyzer.analyze(
            text: "Codes: E330, INS 330, E号330, INS号330",
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertEqual(citricAcid.additives.count, 1)
        XCTAssertEqual(citricAcid.additives.first?.additive.id, "citric-acid")
        XCTAssertEqual(citricAcid.additives.first?.additive.risk, .low)

        let sodiumNitrite = IngredientAnalyzer.analyze(
            text: "Codes: E250, INS-250",
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertEqual(sodiumNitrite.additives.count, 1)
        XCTAssertEqual(sodiumNitrite.additives.first?.additive.id, "sodium-nitrite")
        XCTAssertEqual(sodiumNitrite.additives.first?.additive.risk, .high)
    }

    func testNisinAndEthoxyquinUseTheirOwnCodes() {
        let nisin = IngredientAnalyzer.analyze(
            text: "E234 INS234",
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertEqual(nisin.additives.count, 1)
        XCTAssertEqual(nisin.additives.first?.additive.name, "乳酸链球菌素")
        XCTAssertEqual(nisin.additives.first?.additive.code, "E234")

        let ethoxyquin = IngredientAnalyzer.analyze(
            text: "E324 INS324",
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertEqual(ethoxyquin.additives.count, 1)
        XCTAssertEqual(ethoxyquin.additives.first?.additive.name, "乙氧基喹")
        XCTAssertEqual(ethoxyquin.additives.first?.additive.code, "E324")
    }

    func testMultiCodeGBRowDoesNotExposeOneMisleadingDisplayCode() {
        let groupedNitrites = GB2760Catalog.all.first { $0.name == "亚硝酸钠,亚硝酸钾" }
        XCTAssertNotNil(groupedNitrites)
        XCTAssertNil(groupedNitrites?.code)
        XCTAssertFalse(groupedNitrites?.aliases.contains(where: {
            let compact = $0.replacingOccurrences(of: " ", with: "").lowercased()
            return ["e249", "ins249", "e250", "ins250"].contains(compact)
        }) == true)

        let ambiguousCode = IngredientAnalyzer.analyze(
            text: "E249",
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertTrue(ambiguousCode.additives.isEmpty)
        XCTAssertEqual(ambiguousCode.overallRisk, .unrated)
        XCTAssertEqual(ambiguousCode.safetyScore, -1)
    }

    func testVitaminEAliasesUseGreekAlphaRatherThanCyrillicA() {
        let vitaminE = GB2760Catalog.all.first { $0.name == "维生素E" }
        XCTAssertNotNil(vitaminE)
        XCTAssertTrue(vitaminE?.aliases.contains(where: { $0.contains("α") }) == true)
        XCTAssertFalse(vitaminE?.aliases.contains(where: { $0.contains("а") }) == true)
    }

    func testIngredientPunctuationPreventsCrossBoundaryMatch() {
        let result = IngredientAnalyzer.analyze(
            text: "配料：柠檬酸、钠",
            profile: UserProfile(prefersStricterWarnings: false)
        )

        XCTAssertEqual(result.additives.map(\.additive.id), ["citric-acid"])
        XCTAssertFalse(result.additives.contains { $0.additive.name == "柠檬酸钠" })
    }

    func testNewlineIsHardBoundaryButSameLineWhitespaceRemainsJoinable() {
        let separateLines = IngredientAnalyzer.analyze(
            text: "配料：柠檬酸\n钠：0mg",
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertTrue(separateLines.additives.contains { $0.additive.id == "citric-acid" })
        XCTAssertFalse(separateLines.additives.contains { $0.additive.id == "sodium-citrate" })

        let sameLine = IngredientAnalyzer.analyze(
            text: "配料：柠檬 酸钠",
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertEqual(sameLine.additives.map(\.additive.id), ["sodium-citrate"])
    }

    func testReviewedLineBreakCorrectionSuppressesSubstringBroadMatch() {
        let text = """
        配料水 果葡糖菜、白砂糖，食品添加剂（二氣化碳.柠檬酸.柠
        碳酸钠.苯甲酸钠、蔗糖素、安赛蜜）.食用香精
        """
        let result = IngredientAnalyzer.analyze(
            text: text,
            profile: UserProfile(prefersStricterWarnings: false)
        )

        XCTAssertEqual(Set(result.additives.map(\.additive.id)), [
            "carbon-dioxide",
            "citric-acid",
            "sodium-citrate",
            "sodium-benzoate",
            "sucralose",
            "acesulfame-potassium",
            "food-flavouring"
        ])
        XCTAssertFalse(result.additives.contains { $0.additive.id == "gb2760-216" })
    }

    func testCorrectionReconciliationPreservesSeparateExactAdditiveTokens() {
        let result = IngredientAnalyzer.analyze(
            text: "配料：柠檬酸钠、碳酸钠",
            profile: UserProfile(prefersStricterWarnings: false)
        )

        XCTAssertTrue(result.additives.contains { $0.additive.id == "sodium-citrate" })
        XCTAssertTrue(result.additives.contains { $0.additive.id == "gb2760-216" })
    }

    func testObviousNegationSuppressesDetection() {
        let labels = [
            "不含亚硝酸钠；配料：柠檬酸",
            "无添加亚硝酸钠；配料：柠檬酸",
            "配料：柠檬酸；亚硝酸钠（未检出）"
        ]

        for label in labels {
            let result = IngredientAnalyzer.analyze(
                text: label,
                profile: UserProfile(prefersStricterWarnings: false)
            )
            XCTAssertFalse(result.additives.contains { $0.additive.id == "sodium-nitrite" }, label)
            XCTAssertTrue(result.additives.contains { $0.additive.id == "citric-acid" }, label)
        }
    }

    func testAtomicMatchesWinOverGroupedAliasAndSummaryIncludesUnrated() {
        let result = IngredientAnalyzer.analyze(
            text: "配料：亚硝酸钠、亚硝酸钾",
            profile: UserProfile(prefersStricterWarnings: false)
        )

        XCTAssertTrue(result.additives.contains { $0.additive.id == "sodium-nitrite" && $0.additive.risk == .high })
        XCTAssertTrue(result.additives.contains { $0.additive.name == "亚硝酸钠,亚硝酸钾" && $0.additive.risk == .unrated })
        XCTAssertTrue(result.summary.contains("已评级"))
        XCTAssertTrue(result.summary.contains("未评级"))
    }

    func testStrictWarningsProduceVisibleRiskChange() {
        let normal = IngredientAnalyzer.analyze(
            text: "配料：柠檬酸",
            profile: UserProfile(prefersStricterWarnings: false)
        )
        let strict = IngredientAnalyzer.analyze(
            text: "配料：柠檬酸",
            profile: UserProfile(prefersStricterWarnings: true)
        )

        XCTAssertEqual(normal.additives.first?.additive.risk, .low)
        XCTAssertEqual(strict.additives.first?.additive.risk, .moderate)
        XCTAssertEqual(strict.overallRisk, .moderate)
        XCTAssertTrue(strict.additives.first?.personalizedNote?.contains("严格预警") == true)
    }

    func testPlainLanguageSummariesCoverEveryCatalogEntry() {
        for additive in AdditiveCatalog.all {
            XCTAssertFalse(
                additive.plainLanguageSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                additive.id
            )
            XCTAssertNotEqual(additive.plainLanguageSummary, additive.summary, additive.id)
        }

        let curatedMarkers = [
            "sodium-nitrite": "腌制肉制品",
            "bha": "油脂",
            "bht": "油脂",
            "sodium-benzoate": "酸性",
            "potassium-sorbate": "霉菌",
            "sodium-metabisulfite": "亚硫酸盐",
            "monosodium-glutamate": "味精",
            "disodium-ribonucleotides": "核苷酸盐",
            "paprika-extract": "辣椒",
            "caramel-colour": "棕色着色剂",
            "food-flavouring": "混合物",
            "ascorbic-acid": "维生素 C",
            "citric-acid": "有机酸",
            "lecithin": "乳化剂"
        ]
        for (id, marker) in curatedMarkers {
            let additive = AdditiveCatalog.all.first { $0.id == id }
            XCTAssertNotNil(additive, id)
            XCTAssertTrue(additive?.plainLanguageSummary.contains(marker) == true, id)
        }

        let categoryMarkers = [
            "food-processing-aid": "生产过程",
            "food-enzyme-preparation": "具体酶",
            "nutrient-fortifier": "维生素、矿物质",
            "compound-food-additive": "两种或更多"
        ]
        for (id, marker) in categoryMarkers {
            let additive = AdditiveCatalog.all.first { $0.id == id }
            XCTAssertTrue(additive?.plainLanguageSummary.contains(marker) == true, id)
        }

        let gbEntry = AdditiveCatalog.all.first { $0.id.hasPrefix("gb2760-") }
        XCTAssertTrue(gbEntry?.plainLanguageSummary.contains("国家食品添加剂标准目录") == true)
        XCTAssertTrue(gbEntry?.plainLanguageSummary.contains("不能仅凭") == true)
    }

    func testPlainLanguageSummaryHasFutureEntryFallback() {
        let futureEntry = Additive(
            id: "future-entry",
            name: "未来新增成分",
            englishName: "Future entry",
            code: nil,
            aliases: ["未来新增成分"],
            function: "待补充",
            risk: .unrated,
            summary: "专业说明待补充。",
            healthEffects: [],
            recommendation: "请进一步核对。",
            sources: []
        )

        XCTAssertTrue(futureEntry.plainLanguageSummary.contains("未来新增成分"))
        XCTAssertTrue(futureEntry.plainLanguageSummary.contains("进一步核对"))
    }

    func testPlainLanguageSummaryDoesNotChangeCodableSchema() throws {
        let additive = try XCTUnwrap(AdditiveCatalog.all.first { $0.id == "citric-acid" })
        let encoded = try JSONEncoder().encode(additive)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertNil(object["plainLanguageSummary"])
        XCTAssertEqual(try JSONDecoder().decode(Additive.self, from: encoded), additive)
    }
}
