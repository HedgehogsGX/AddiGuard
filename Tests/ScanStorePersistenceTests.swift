import XCTest
@testable import AddiGuard

final class ScanStorePersistenceTests: XCTestCase {
    func testVersionOneAPIPreferenceMigratesToOfflineWithoutConsent() throws {
        let legacyJSON = """
        {
          "version": 1,
          "records": [],
          "profile": {
            "populationGroup": "general",
            "allergySensitive": false,
            "prefersStricterWarnings": true
          },
          "recognitionMode": "api"
        }
        """

        let state = try JSONDecoder().decode(
            PersistedScanState.self,
            from: try XCTUnwrap(legacyJSON.data(using: .utf8))
        )

        XCTAssertEqual(state.analysisMode, .offline)
        XCTAssertNil(state.onlineAnalysisConsentVersion)
    }

    func testCurrentAnalysisModeAndConsentRoundTrip() throws {
        let state = PersistedScanState(
            version: PersistedScanState.currentVersion,
            records: [],
            profile: UserProfile(),
            analysisMode: .api,
            onlineAnalysisConsentVersion: OnlineAnalysisConsent.currentVersion
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PersistedScanState.self, from: data)

        XCTAssertEqual(decoded.analysisMode, .api)
        XCTAssertEqual(
            decoded.onlineAnalysisConsentVersion,
            OnlineAnalysisConsent.currentVersion
        )
    }

    func testCurrentAPIModeWithoutMatchingConsentFailsClosedToOffline() throws {
        let json = """
        {
          "version": 2,
          "records": [],
          "profile": {
            "populationGroup": "general",
            "allergySensitive": false,
            "prefersStricterWarnings": true
          },
          "analysisMode": "api"
        }
        """
        let state = try JSONDecoder().decode(
            PersistedScanState.self,
            from: try XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertEqual(state.analysisMode, .offline)
    }

    @MainActor
    func testHistoryIsRedactedImmediatelyButKeepsStructuredIngredients() {
        let store = ScanStore()
        store.clearHistory()
        let sourceText = "产品名称：测试\n配料：水、白砂糖、柠檬酸"

        let transient = store.analyzeAndSave(text: sourceText, productName: "测试")
        let history = store.records.first

        XCTAssertEqual(transient.result.recognizedText, sourceText)
        XCTAssertEqual(history?.result.recognizedText, "")
        XCTAssertEqual(
            history?.result.ingredientTokens.map(\.text),
            ["水", "白砂糖", "柠檬酸"]
        )
    }
}
