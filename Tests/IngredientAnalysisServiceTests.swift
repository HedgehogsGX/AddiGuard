import XCTest
@testable import AddiGuard

final class IngredientAnalysisServiceTests: XCTestCase {
    private let consent = OnlineAnalysisConsent.currentVersion

    func testOfflineModeNeverInvokesRemoteAnalyzer() async throws {
        let calls = LockedCounter()
        let service = IngredientAnalysisService(
            remoteAnalyzer: RemoteIngredientAnalyzer { _ in
                calls.increment()
                throw RecognitionServiceError.invalidResponse
            }
        )

        let result = try await service.analyze(
            text: "配料：水、白砂糖、柠檬酸",
            profile: UserProfile(),
            using: .offline,
            consentVersion: nil
        )

        XCTAssertEqual(calls.value, 0)
        XCTAssertEqual(result.analysisSource, .local)
        XCTAssertEqual(result.ingredientTokens.map(\.text), ["水", "白砂糖", "柠檬酸"])
        XCTAssertTrue(result.ingredientInsights.isEmpty)
    }

    func testOnlineModeSendsEveryLocallyParsedIngredientAndKeepsLocalRisk() async throws {
        let captured = LockedTokenTexts()
        let text = "配料：水、柠檬酸、苯甲酿钠、神秘原料"
        let local = IngredientAnalyzer.analyze(text: text, profile: UserProfile())
        let service = IngredientAnalysisService(
            remoteAnalyzer: RemoteIngredientAnalyzer { tokens in
                captured.append(tokens.map(\.text))
                return tokens.map(Self.insight)
            }
        )

        let result = try await service.analyze(
            text: text,
            profile: UserProfile(),
            using: .api,
            consentVersion: consent
        )

        XCTAssertEqual(captured.values.flatMap { $0 }, local.ingredientTokens.map(\.text))
        XCTAssertEqual(result.ingredientInsights.map(\.ingredient), local.ingredientTokens.map(\.text))
        XCTAssertEqual(result.additives, local.additives)
        XCTAssertEqual(result.overallRisk, local.overallRisk)
        XCTAssertEqual(result.summary, local.summary)
        XCTAssertEqual(result.analysisSource, .openRouter)
    }

    func testOnlineModeRequiresCurrentConsentBeforeNetworkCall() async {
        let calls = LockedCounter()
        let service = IngredientAnalysisService(
            remoteAnalyzer: RemoteIngredientAnalyzer { tokens in
                calls.increment()
                return tokens.map(Self.insight)
            }
        )

        do {
            _ = try await service.analyze(
                text: "配料：水",
                profile: UserProfile(),
                using: .api,
                consentVersion: nil
            )
            XCTFail("Expected consent error")
        } catch RecognitionServiceError.onlineConsentRequired {
            XCTAssertEqual(calls.value, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOnlineModeFailsClosedWhenNoIngredientSectionExists() async {
        let calls = LockedCounter()
        let service = IngredientAnalysisService(
            remoteAnalyzer: RemoteIngredientAnalyzer { tokens in
                calls.increment()
                return tokens.map(Self.insight)
            }
        )

        do {
            _ = try await service.analyze(
                text: "产品名称：饮料\n生产商：示例公司\n电话：123456",
                profile: UserProfile(),
                using: .api,
                consentVersion: consent
            )
            XCTFail("Expected local parsing to fail closed")
        } catch RecognitionServiceError.noIngredientsFound {
            XCTAssertEqual(calls.value, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOnlineModeBatchesWithoutDroppingOrReorderingItems() async throws {
        let captured = LockedTokenTexts()
        let names = (0..<45).map { "原料\($0)" }
        let service = IngredientAnalysisService(
            remoteAnalyzer: RemoteIngredientAnalyzer { tokens in
                captured.append(tokens.map(\.text))
                return tokens.map(Self.insight)
            }
        )

        let result = try await service.analyze(
            text: "配料：" + names.joined(separator: "、"),
            profile: UserProfile(),
            using: .api,
            consentVersion: consent
        )

        XCTAssertEqual(captured.values.map(\.count), [20, 20, 5])
        XCTAssertEqual(result.ingredientInsights.map(\.ingredient), names)
    }

    func testMismatchedRemoteIDsAreRejectedWithoutPartialResult() async {
        let service = IngredientAnalysisService(
            remoteAnalyzer: RemoteIngredientAnalyzer { tokens in
                var insights = tokens.map(Self.insight)
                let first = insights.removeFirst()
                insights.insert(
                    IngredientInsight(
                        id: "unknown-id",
                        ingredient: first.ingredient,
                        category: first.category,
                        commonRole: first.commonRole,
                        analysis: first.analysis,
                        reviewNote: first.reviewNote,
                        confidence: first.confidence
                    ),
                    at: 0
                )
                return insights
            }
        )

        do {
            _ = try await service.analyze(
                text: "配料：水、白砂糖",
                profile: UserProfile(),
                using: .api,
                consentVersion: consent
            )
            XCTFail("Expected strict ID validation")
        } catch RecognitionServiceError.invalidResponse {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private static func insight(_ token: IngredientToken) -> IngredientInsight {
        IngredientInsight(
            id: token.id,
            ingredient: token.text,
            category: .uncertain,
            commonRole: "用于食品配方",
            analysis: "需要结合具体产品资料核对。",
            reviewNote: nil,
            confidence: .low
        )
    }
}

private final class LockedTokenTexts: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [[String]] = []

    var values: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: [String]) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}
