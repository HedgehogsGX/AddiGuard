import XCTest
@testable import AddiGuard

/// Opt-in smoke test that calls the real OpenRouter endpoint.
///
/// Every other OpenRouter test is hermetic and asserts against a fixed payload,
/// so none of them notice when the configured model is withdrawn upstream. That
/// is exactly how `stealth/ox-alpha` stayed in the source after its stealth
/// testing period ended: the unit tests kept passing against the retired slug
/// while every real request returned HTTP 404.
///
/// The test is skipped unless `ADDIGUARD_LIVE_API_TESTS=1` is set, so CI and
/// ordinary local runs never spend credits or depend on the network. Run it by
/// hand after changing `OpenRouterConfiguration.defaultModel`, and periodically
/// to confirm the slug is still served.
///
/// The test runs inside the simulator, which does not inherit the shell
/// environment, so both variables need xcodebuild's `TEST_RUNNER_` prefix —
/// it forwards them to the runner with the prefix stripped. Setting them
/// without the prefix silently skips the test instead of running it:
///
/// ```
/// TEST_RUNNER_ADDIGUARD_LIVE_API_TESTS=1 \
/// TEST_RUNNER_OPENROUTER_API_KEY="$(awk -F= '/OPENROUTER_API_KEY/{print $2}' Config/Secrets.xcconfig | tr -d ' ')" \
/// xcodebuild -project AddiGuard.xcodeproj -scheme AddiGuard \
///   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///   -only-testing:AddiGuardTests/OpenRouterLiveSmokeTests test
/// ```
final class OpenRouterLiveSmokeTests: XCTestCase {
    /// Sends the production payload for a short ingredient list and requires a
    /// usable answer for every item, which fails loudly on a withdrawn model
    /// (404), a revoked key (401) or an exhausted balance (402).
    func testConfiguredModelStillAnswersTheProductionPayload() async throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(
            environment["ADDIGUARD_LIVE_API_TESTS"] == "1",
            "Set ADDIGUARD_LIVE_API_TESTS=1 to call the live OpenRouter API."
        )
        let apiKey = try XCTUnwrap(
            environment["OPENROUTER_API_KEY"],
            "Live smoke test needs OPENROUTER_API_KEY in the environment."
        )
        let configuration = try XCTUnwrap(
            OpenRouterConfiguration(apiKey: apiKey),
            "OPENROUTER_API_KEY was empty or still an unexpanded placeholder."
        )
        let provider = IngredientAnalysisAPIProvider.openRouter(
            configuration: configuration
        )

        let ingredients = [
            IngredientToken(
                id: "live-1",
                text: "柠檬酸",
                kind: .matchedAdditive,
                matchedAdditiveID: nil,
                matchedAdditiveName: nil,
                matchedViaReviewedCorrection: false
            ),
            IngredientToken(
                id: "live-2",
                text: "小麦粉",
                kind: .ordinaryIngredient,
                matchedAdditiveID: nil,
                matchedAdditiveName: nil,
                matchedViaReviewedCorrection: false
            )
        ]

        let request = try provider.makeRequest(ingredients)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(
            httpResponse.statusCode,
            200,
            """
            Live OpenRouter call for \(OpenRouterConfiguration.defaultModel) \
            returned \(httpResponse.statusCode). A 404 means the slug is no \
            longer served and OpenRouterConfiguration.defaultModel needs \
            updating. Body: \(String(decoding: data, as: UTF8.self).prefix(500))
            """
        )

        let insights = try provider.decodeInsights(data, httpResponse, ingredients)

        XCTAssertEqual(insights.map(\.id), ingredients.map(\.id))
        XCTAssertEqual(insights.map(\.ingredient), ingredients.map(\.text))
        for insight in insights {
            XCTAssertFalse(
                insight.commonRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Model returned an empty common_role for \(insight.ingredient)."
            )
            XCTAssertFalse(
                insight.analysis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Model returned an empty analysis for \(insight.ingredient)."
            )
        }
    }
}
