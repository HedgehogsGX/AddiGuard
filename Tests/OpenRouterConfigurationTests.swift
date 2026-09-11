import XCTest
@testable import AddiGuard

final class OpenRouterConfigurationTests: XCTestCase {
    func testConfigurationUsesOxAlphaAndRejectsMissingValues() throws {
        let configuration = try XCTUnwrap(
            OpenRouterConfiguration(apiKey: "dummy-local-key")
        )

        XCTAssertEqual(configuration.model, "z-ai/glm-5.3-flash")
        XCTAssertEqual(
            configuration.endpoint.absoluteString,
            "https://openrouter.ai/api/v1/chat/completions"
        )
        XCTAssertEqual(configuration.credentialSource, .direct)
        XCTAssertEqual(configuration.credentialFingerprint.count, 24)
        XCTAssertNil(OpenRouterConfiguration(apiKey: "  \n"))
        XCTAssertNil(OpenRouterConfiguration(apiKey: "$(OPENROUTER_API_KEY)"))
    }

    func testAnalysisServiceIsConfiguredOnlyWhenCredentialExists() throws {
        let configuration = try XCTUnwrap(
            OpenRouterConfiguration(apiKey: "dummy-local-key")
        )

        XCTAssertTrue(
            IngredientAnalysisService.makeLive(configuration: configuration).isAPIConfigured
        )
        XCTAssertFalse(IngredientAnalysisService.makeLive(configuration: nil).isAPIConfigured)
    }

    func testLocalDevelopmentLaunchKeyIsUsedAndPersisted() throws {
        var savedKey: String?
        let configuration = try XCTUnwrap(
            OpenRouterConfiguration.localDevelopment(
                environment: ["OPENROUTER_API_KEY": "  launch-key\n"],
                loadStoredKey: { XCTFail("Stored key should not be read"); return nil },
                saveStoredKey: { savedKey = $0; return true }
            )
        )

        XCTAssertEqual(configuration.apiKey, "launch-key")
        XCTAssertEqual(configuration.credentialSource, .launchEnvironment)
        XCTAssertEqual(savedKey, "launch-key")
    }

    func testInvalidLaunchValueFailsClosedWithoutReadingStoredKey() {
        var readStoredKey = false
        let configuration = OpenRouterConfiguration.localDevelopment(
            environment: ["OPENROUTER_API_KEY": "$(OPENROUTER_API_KEY)"],
            loadStoredKey: {
                readStoredKey = true
                return "stale-key"
            },
            saveStoredKey: { _ in XCTFail("Invalid value must not be saved"); return false }
        )

        XCTAssertNil(configuration)
        XCTAssertFalse(readStoredKey)
    }

    func testLocalDevelopmentFallsBackToStoredCredential() throws {
        let configuration = try XCTUnwrap(
            OpenRouterConfiguration.localDevelopment(
                environment: [:],
                loadStoredKey: { "stored-key" },
                saveStoredKey: { _ in XCTFail("Stored key should not be rewritten"); return false }
            )
        )

        XCTAssertEqual(configuration.apiKey, "stored-key")
        XCTAssertEqual(configuration.credentialSource, .keychain)
    }
}
