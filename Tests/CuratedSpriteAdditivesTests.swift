import XCTest
@testable import AddiGuard

final class CuratedSpriteAdditivesTests: XCTestCase {
    private let profile = UserProfile(prefersStricterWarnings: false)

    func testSpriteAdditivesResolveToReviewedRecordsAcrossLabelSpellings() {
        let spellingsByID: [String: [String]] = [
            "acesulfame-potassium": [
                "安赛蜜", "乙酰磺胺酸钾", "安赛蜜（又名乙酰磺胺酸钾）",
                "acesulfame potassium", "Ace-K", "E950", "INS 950"
            ],
            "sucralose": [
                "三氯蔗糖", "蔗糖素", "三氯蔗糖（又名蔗糖素）",
                "sucralose", "E955", "INS 955"
            ],
            "carbon-dioxide": ["二氧化碳", "carbon dioxide", "CO2", "E290", "INS 290"],
            "sodium-citrate": [
                "柠檬酸钠", "柠檬酸三钠", "枸橼酸钠", "trisodium citrate",
                "sodium citrate", "E331(iii)", "INS 331(iii)"
            ]
        ]

        for (expectedID, spellings) in spellingsByID {
            for spelling in spellings {
                let result = IngredientAnalyzer.analyze(
                    text: "配料：\(spelling)",
                    profile: profile
                )
                XCTAssertEqual(result.additives.map(\.additive.id), [expectedID], spelling)
                XCTAssertFalse(result.additives.first?.additive.id.hasPrefix("gb2760-") == true, spelling)
            }
        }
    }

    func testReviewedEntriesClaimUnambiguousAliasesFromGenericGBRows() throws {
        let expected: [(id: String, risk: RiskLevel, marker: String)] = [
            ("acesulfame-potassium", .moderate, "15 mg/kg"),
            ("sucralose", .moderate, "15 mg/kg"),
            ("carbon-dioxide", .low, "不作具体规定"),
            ("sodium-citrate", .low, "不作具体规定")
        ]

        for item in expected {
            let additive = try XCTUnwrap(AdditiveCatalog.all.first { $0.id == item.id })
            XCTAssertEqual(additive.risk, item.risk, item.id)
            XCTAssertTrue(additive.summary.contains(item.marker), item.id)
            XCTAssertGreaterThanOrEqual(additive.healthEffects.count, 2, item.id)
            XCTAssertTrue(additive.sources.contains("GB 2760-2024"), item.id)
            XCTAssertTrue(additive.sources.contains("WHO/JECFA"), item.id)
            XCTAssertFalse(additive.recommendation.contains("尚未"), item.id)
        }

        let genericAliases = Set(
            AdditiveCatalog.all
                .filter { $0.id.hasPrefix("gb2760-") }
                .flatMap(\.aliases)
        )
        XCTAssertFalse(genericAliases.contains("安赛蜜"))
        XCTAssertFalse(genericAliases.contains("三氯蔗糖"))
        XCTAssertFalse(genericAliases.contains("二氧化碳"))
        XCTAssertFalse(genericAliases.contains("柠檬酸钠"))
    }

    func testReviewedEntriesHaveSpecificPlainLanguageExplanations() throws {
        let markers = [
            "acesulfame-potassium": "乙酰磺胺酸钾",
            "sucralose": "蔗糖素",
            "carbon-dioxide": "气泡",
            "sodium-citrate": "柠檬酸的钠盐"
        ]

        for (id, marker) in markers {
            let additive = try XCTUnwrap(AdditiveCatalog.all.first { $0.id == id })
            XCTAssertTrue(additive.plainLanguageSummary.contains(marker), id)
            XCTAssertFalse(additive.plainLanguageSummary.contains("当前没有更具体"), id)
            XCTAssertFalse(additive.plainLanguageSummary.contains("本地目录目前只确认"), id)
        }
    }

    func testBareE331RemainsAmbiguousInsteadOfClaimingTrisodiumCitrate() {
        let result = IngredientAnalyzer.analyze(
            text: "配料：E331",
            profile: profile
        )

        XCTAssertFalse(result.additives.contains { $0.additive.id == "sodium-citrate" })
        XCTAssertEqual(result.overallRisk, .unrated)
    }
}
