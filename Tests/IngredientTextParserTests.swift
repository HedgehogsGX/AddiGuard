import XCTest
@testable import AddiGuard

final class IngredientTextParserTests: XCTestCase {
    func testSpriteLabelParsesOrdinaryIngredientsAndAllSevenAdditives() {
        let text = """
        清爽柠檬味汽水
        配料：水、果葡糖浆、白砂糖、食品添加剂（二氧化碳、柠檬酸、柠檬酸钠、苯甲酸钠、蔗糖素、安塞蜜）、食用香精
        生产商：某饮料有限公司
        """

        let tokens = IngredientTextParser.parse(text: text)
        let additiveIDs = Set(
            tokens
                .filter { $0.kind == .matchedAdditive }
                .compactMap(\.matchedAdditiveID)
        )
        let expectedIDs = Set(
            [
                "二氧化碳", "柠檬酸", "柠檬酸钠", "苯甲酸钠",
                "蔗糖素", "安赛蜜", "食用香精"
            ].compactMap { catalogID(matching: $0) }
        )

        XCTAssertEqual(expectedIDs.count, 7)
        XCTAssertEqual(additiveIDs, expectedIDs)
        XCTAssertEqual(
            Set(
                IngredientAnalyzer.analyze(
                    text: text,
                    profile: UserProfile(prefersStricterWarnings: false)
                ).additives.map(\.additive.id)
            ),
            expectedIDs
        )
        XCTAssertEqual(
            tokens.filter { $0.kind == .ordinaryIngredient }.map(\.text),
            ["水", "果葡糖浆", "白砂糖"]
        )
        XCTAssertFalse(tokens.contains { $0.text.contains("生产商") })
    }

    func testReviewedOCRCorrectionPromotesAnSaiMiToConfirmedMatch() {
        let text = "配料：水、食品添加剂（安塞蜜）"
        let tokens = IngredientTextParser.parse(text: text)
        let corrected = tokens.first { $0.text == "安塞蜜" }

        XCTAssertEqual(corrected?.kind, .matchedAdditive)
        XCTAssertEqual(corrected?.matchedAdditiveID, "acesulfame-potassium")

        let analysis = IngredientAnalyzer.analyze(
            text: text,
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertTrue(analysis.additives.contains { $0.additive.id == "acesulfame-potassium" })
        XCTAssertTrue(analysis.additives.contains { $0.matchedTerm == "安塞蜜" })
    }

    func testOneCharacterFuzzyMatchStaysTentativeAndOutOfAnalysisResult() {
        let text = "配料：水、食品添加剂（苯甲酿钠）"
        let tokens = IngredientTextParser.parse(text: text)
        let possible = tokens.first { $0.text == "苯甲酿钠" }

        XCTAssertEqual(possible?.kind, .possibleMatch)
        XCTAssertEqual(possible?.matchedAdditiveID, "sodium-benzoate")
        XCTAssertEqual(possible?.matchedAdditiveName, "苯甲酸钠")

        let analysis = IngredientAnalyzer.analyze(
            text: text,
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertFalse(analysis.additives.contains { $0.additive.id == "sodium-benzoate" })
    }

    func testFuzzyMatchingDoesNotRunOutsideALabelledIngredientSection() {
        let text = "产品宣传：食品添加剂（苯甲酿钠）"

        XCTAssertTrue(IngredientTextParser.parse(text: text).isEmpty)
        XCTAssertTrue(
            IngredientAnalyzer.analyze(
                text: text,
                profile: UserProfile(prefersStricterWarnings: false)
            ).additives.isEmpty
        )
    }

    func testOrdinarySimilarWordsDoNotBecomePossibleAdditives() {
        let tokens = IngredientTextParser.parse(
            text: "配料：柠檬汁、食用香菇、白砂糖"
        )

        XCTAssertFalse(tokens.contains { $0.kind == .possibleMatch })
        XCTAssertFalse(tokens.contains { $0.kind == .matchedAdditive })
        XCTAssertEqual(tokens.first { $0.text == "白砂糖" }?.kind, .ordinaryIngredient)
    }

    func testExactMatchWinsBeforeAnyFuzzySuggestion() {
        let tokens = IngredientTextParser.parse(text: "配料：柠檬酸、柠檬汁")

        XCTAssertEqual(tokens.first { $0.text == "柠檬酸" }?.kind, .matchedAdditive)
        XCTAssertEqual(tokens.first { $0.text == "柠檬酸" }?.matchedAdditiveID, "citric-acid")
        XCTAssertNotEqual(tokens.first { $0.text == "柠檬汁" }?.kind, .possibleMatch)
    }

    func testNestedCompositionAndChinesePunctuationAreFlattenedInOrder() {
        let text = "配料表：酿造酱油（含焦糖色）；饮用水；食品添加剂：柠檬酸、安赛蜜。净含量：500毫升"
        let tokens = IngredientTextParser.parse(text: text)

        XCTAssertEqual(tokens.map(\.text), [
            "酿造酱油", "焦糖色", "饮用水", "柠檬酸", "安赛蜜"
        ])
        XCTAssertEqual(tokens.first { $0.text == "焦糖色" }?.kind, .matchedAdditive)
        XCTAssertEqual(tokens.first { $0.text == "饮用水" }?.kind, .ordinaryIngredient)
        XCTAssertFalse(tokens.contains { $0.text.contains("净含量") })
    }

    func testTokenIDsAreDeterministicAcrossParses() {
        let text = "配料：水、白砂糖、食品添加剂（柠檬酸）"

        XCTAssertEqual(
            IngredientTextParser.parse(text: text).map(\.id),
            IngredientTextParser.parse(text: text).map(\.id)
        )
    }

    func testPunctuationOnlyTokenDoesNotCrashClassification() {
        let text = "配料：%、水"
        let tokens = IngredientTextParser.parse(text: text)

        XCTAssertEqual(tokens.map(\.text), ["%", "水"])
        XCTAssertEqual(tokens.map(\.kind), [.unresolved, .ordinaryIngredient])
        XCTAssertNoThrow(
            IngredientAnalyzer.analyze(
                text: text,
                profile: UserProfile(prefersStricterWarnings: false)
            )
        )
    }

    func testRealVisionSpriteLinesRecoverCompleteIngredientList() {
        let text = """
        配料水 果葡糖菜、白砂糖，食品添加剂（二氣化碳.柠檬酸.柠
        碳酸钠.苯甲酸钠、蔗糖素、安赛蜜）.食用香精
        """

        let tokens = IngredientTextParser.parse(text: text)
        let ordinaryTokens = tokens.filter { $0.kind == .ordinaryIngredient }
        let expectedAdditiveIDs: Set<String> = [
            "carbon-dioxide",
            "citric-acid",
            "sodium-citrate",
            "sodium-benzoate",
            "sucralose",
            "acesulfame-potassium",
            "food-flavouring"
        ]

        XCTAssertEqual(ordinaryTokens.map(\.text), ["水", "果葡糖菜", "白砂糖"])
        XCTAssertEqual(
            Set(tokens.filter { $0.kind == .matchedAdditive }.compactMap(\.matchedAdditiveID)),
            expectedAdditiveIDs
        )
        XCTAssertTrue(tokens.contains {
            $0.text == "果葡糖菜" && $0.kind == .ordinaryIngredient
        })
        XCTAssertFalse(tokens.contains { $0.kind == .possibleMatch || $0.kind == .unresolved })

        let analysis = IngredientAnalyzer.analyze(
            text: text,
            profile: UserProfile(prefersStricterWarnings: false)
        )
        XCTAssertEqual(Set(analysis.additives.map(\.additive.id)), expectedAdditiveIDs)
    }

    func testWhitespaceSplittingRequiresEveryPieceToBeConfirmed() {
        let confirmed = IngredientTextParser.parse(text: "配料：水 果葡糖菜")
        XCTAssertEqual(confirmed.map(\.text), ["水", "果葡糖菜"])

        let wrappedName = IngredientTextParser.parse(text: "配料：柠檬 酸钠")
        XCTAssertEqual(wrappedName.map(\.text), ["柠檬 酸钠"])
        XCTAssertEqual(wrappedName.first?.matchedAdditiveID, "sodium-citrate")

        let arbitrary = IngredientTextParser.parse(text: "配料：未知 配料文字")
        XCTAssertEqual(arbitrary.map(\.text), ["未知 配料文字"])
        XCTAssertEqual(arbitrary.first?.kind, .unresolved)
    }

    func testOmittedHeadingColonStillRequiresStrongListEvidence() {
        XCTAssertTrue(IngredientTextParser.parse(text: "配料说明请查看包装，信息以实物为准。").isEmpty)
    }

    private func catalogID(matching alias: String) -> String? {
        AdditiveCatalog.all.first { $0.aliases.contains(alias) }?.id
    }
}
