import XCTest
@testable import AddiGuard

final class OpenRouterIngredientAnalysisProviderTests: XCTestCase {
    private let endpoint = URL(
        string: "https://openrouter.ai/api/v1/chat/completions"
    )!

    func testRequestContainsOnlyOpaqueIDsAndSourceTextAsIngredientData() throws {
        let key = "dummy-analysis-key"
        let provider = try makeProvider(apiKey: key)
        let ingredients = [
            ingredient(
                id: "LOCAL_SECRET_ID_ALPHA",
                text: "水",
                kind: .ordinaryIngredient
            ),
            ingredient(
                id: "LOCAL_SECRET_ID_BETA",
                text: "山梨酸钾",
                kind: .matchedAdditive,
                matchedAdditiveID: "catalog-secret-id",
                matchedAdditiveName: "内部目录名称",
                matchedViaReviewedCorrection: true
            )
        ]

        let request = try provider.makeRequest(ingredients)
        let body = try XCTUnwrap(request.httpBody)
        let bodyText = String(decoding: body, as: UTF8.self)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )

        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer \(key)"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
        XCTAssertEqual(Set(object.keys), [
            "model", "messages", "stream", "temperature", "reasoning",
            "max_tokens", "response_format", "provider"
        ])
        XCTAssertEqual(object["model"] as? String, "z-ai/glm-5.3-flash")
        XCTAssertEqual(object["stream"] as? Bool, false)
        XCTAssertEqual(object["temperature"] as? Double, 0)
        XCTAssertEqual(object["max_tokens"] as? Int, 4_096)

        let reasoning = try XCTUnwrap(object["reasoning"] as? [String: Any])
        XCTAssertEqual(reasoning["effort"] as? String, "low")
        XCTAssertEqual(reasoning["exclude"] as? Bool, true)
        XCTAssertEqual(Set(reasoning.keys), ["effort", "exclude"])

        let responseFormat = try XCTUnwrap(
            object["response_format"] as? [String: Any]
        )
        XCTAssertEqual(responseFormat["type"] as? String, "json_object")

        let preferences = try XCTUnwrap(
            object["provider"] as? [String: Any]
        )
        XCTAssertEqual(preferences["require_parameters"] as? Bool, true)
        XCTAssertEqual(preferences["data_collection"] as? String, "deny")
        XCTAssertEqual(Set(preferences.keys), [
            "require_parameters", "data_collection"
        ])

        let messages = try XCTUnwrap(object["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["system", "user"])
        let userContent = try XCTUnwrap(messages[1]["content"] as? String)
        let input = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(userContent.utf8))
                as? [String: Any]
        )
        XCTAssertEqual(Set(input.keys), ["items"])
        let wireItems = try XCTUnwrap(input["items"] as? [[String: Any]])
        XCTAssertEqual(wireItems.count, ingredients.count)
        XCTAssertTrue(wireItems.allSatisfy {
            Set($0.keys) == ["id", "source_text"]
        })
        XCTAssertEqual(
            wireItems.compactMap { $0["source_text"] as? String },
            ingredients.map(\.text)
        )

        let wireIDs = wireItems.compactMap { $0["id"] as? String }
        XCTAssertEqual(Set(wireIDs).count, ingredients.count)
        XCTAssertTrue(wireIDs.allSatisfy { !$0.isEmpty })
        XCTAssertTrue(Set(wireIDs).isDisjoint(with: Set(ingredients.map(\.id))))

        XCTAssertFalse(bodyText.contains(key))
        XCTAssertFalse(bodyText.contains("LOCAL_SECRET_ID"))
        XCTAssertFalse(bodyText.contains("catalog-secret-id"))
        XCTAssertFalse(bodyText.contains("内部目录名称"))
        for forbidden in [
            "image_url", "profile", "history", "tools", "plugins",
            "response-healing", "zdr"
        ] {
            XCTAssertFalse(bodyText.lowercased().contains(forbidden))
        }
    }

    func testRequestRejectsEmptyInvalidAndInsecureInputs() throws {
        let provider = try makeProvider()

        assertRecognitionError(.noIngredientsFound) {
            _ = try provider.makeRequest([])
        }
        assertRecognitionError(.invalidRequest) {
            _ = try provider.makeRequest([
                ingredient(id: "valid-id", text: " \n ")
            ])
        }
        assertRecognitionError(.invalidRequest) {
            _ = try provider.makeRequest([
                ingredient(id: "duplicate", text: "水"),
                ingredient(id: "duplicate", text: "糖")
            ])
        }

        let insecureConfiguration = try XCTUnwrap(
            OpenRouterConfiguration(
                apiKey: "dummy-analysis-key",
                endpoint: URL(string: "http://example.com/chat")!
            )
        )
        let insecureProvider = IngredientAnalysisAPIProvider.openRouter(
            configuration: insecureConfiguration
        )
        assertRecognitionError(.insecureEndpoint) {
            _ = try insecureProvider.makeRequest([
                ingredient(id: "valid-id", text: "水")
            ])
        }
    }

    func testDecoderValidatesAndRestoresLocalOrderAndIDs() throws {
        let provider = try makeProvider()
        let ingredients = [
            ingredient(id: "local-water", text: "水"),
            ingredient(id: "local-sorbate", text: "山梨酸钾")
        ]
        let wireItems = try requestWireItems(provider, ingredients: ingredients)
        let firstID = try XCTUnwrap(wireItems[0]["id"] as? String)
        let secondID = try XCTUnwrap(wireItems[1]["id"] as? String)

        let responseItems = [
            outputItem(
                id: secondID,
                sourceText: "山梨酸钾",
                category: "food_additive",
                commonRole: "防腐剂",
                analysis: "常用于帮助抑制霉菌和酵母。",
                reviewNote: "仅凭名称不能判断用量或合规性。",
                confidence: "high"
            ),
            outputItem(
                id: firstID,
                sourceText: "水",
                category: "ordinary_food",
                commonRole: "食品原料",
                analysis: "常见基础原料。",
                reviewNote: NSNull(),
                confidence: "high"
            )
        ]

        let insights = try provider.decodeInsights(
            responseData(items: responseItems),
            httpResponse(),
            ingredients
        )

        XCTAssertEqual(insights.map(\.id), ingredients.map(\.id))
        XCTAssertEqual(insights.map(\.ingredient), ingredients.map(\.text))
        XCTAssertEqual(insights.map(\.category), [.ordinaryFood, .foodAdditive])
        XCTAssertEqual(insights.map(\.commonRole), ["食品原料", "防腐剂"])
        XCTAssertNil(insights[0].reviewNote)
        XCTAssertEqual(
            insights[1].reviewNote,
            "仅凭名称不能判断用量或合规性。"
        )
    }

    func testDecoderRejectsMissingDuplicateUnknownOrExtraIDs() throws {
        let provider = try makeProvider()
        let ingredients = [
            ingredient(id: "local-a", text: "水"),
            ingredient(id: "local-b", text: "糖")
        ]
        let wireItems = try requestWireItems(provider, ingredients: ingredients)
        let firstID = try XCTUnwrap(wireItems[0]["id"] as? String)
        let secondID = try XCTUnwrap(wireItems[1]["id"] as? String)
        let first = outputItem(id: firstID, sourceText: "水")
        let second = outputItem(id: secondID, sourceText: "糖")

        let invalidItemSets = [
            [first],
            [first, first],
            [first, outputItem(id: "unknown", sourceText: "糖")],
            [first, second, outputItem(id: "extra", sourceText: "盐")]
        ]

        for items in invalidItemSets {
            assertRecognitionError(.invalidResponse) {
                _ = try provider.decodeInsights(
                    responseData(items: items),
                    httpResponse(),
                    ingredients
                )
            }
        }
    }

    func testDecoderRequiresByteExactSourceText() throws {
        let provider = try makeProvider()
        let decomposed = "Cafe\u{301}"
        let ingredients = [ingredient(id: "local-cafe", text: decomposed)]
        let wireItems = try requestWireItems(provider, ingredients: ingredients)
        let wireID = try XCTUnwrap(wireItems[0]["id"] as? String)

        XCTAssertEqual(decomposed, "Café")
        XCTAssertNotEqual(Array(decomposed.utf8), Array("Café".utf8))
        assertRecognitionError(.invalidResponse) {
            _ = try provider.decodeInsights(
                responseData(items: [
                    outputItem(id: wireID, sourceText: "Café")
                ]),
                httpResponse(),
                ingredients
            )
        }
    }

    func testDecoderRejectsMalformedOrNonExactAnalysisJSON() throws {
        let provider = try makeProvider()
        let ingredients = [ingredient(id: "local-water", text: "水")]
        let wireItems = try requestWireItems(provider, ingredients: ingredients)
        let wireID = try XCTUnwrap(wireItems[0]["id"] as? String)
        let validItem = outputItem(id: wireID, sourceText: "水")

        var extraFieldItem = validItem
        extraFieldItem["unexpected"] = true
        var missingNullableField = validItem
        missingNullableField.removeValue(forKey: "review_note")
        var invalidCategory = validItem
        invalidCategory["category"] = "medical_verdict"
        var oversizedRole = validItem
        oversizedRole["common_role"] = String(repeating: "角", count: 101)
        var oversizedAnalysis = validItem
        oversizedAnalysis["analysis"] = String(repeating: "析", count: 401)
        var oversizedReviewNote = validItem
        oversizedReviewNote["review_note"] = String(repeating: "核", count: 301)
        var controlledText = validItem
        controlledText["analysis"] = "第一行\n第二行"

        let invalidObjects: [[String: Any]] = [
            ["items": [validItem], "unexpected": true],
            ["items": [extraFieldItem]],
            ["items": [missingNullableField]],
            ["items": [invalidCategory]],
            ["items": [oversizedRole]],
            ["items": [oversizedAnalysis]],
            ["items": [oversizedReviewNote]],
            ["items": [controlledText]]
        ]
        for object in invalidObjects {
            let content = try jsonString(object)
            assertRecognitionError(.invalidResponse) {
                _ = try provider.decodeInsights(
                    responseData(content: content),
                    httpResponse(),
                    ingredients
                )
            }
        }

        let validJSON = try jsonString(["items": [validItem]])
        for content in [
            "not-json",
            "```json\n\(validJSON)\n```",
            "\(validJSON) trailing prose"
        ] {
            assertRecognitionError(.invalidResponse) {
                _ = try provider.decodeInsights(
                    responseData(content: content),
                    httpResponse(),
                    ingredients
                )
            }
        }
    }

    func testDecoderValidatesHTTPChoiceRoleAndFinishReason() throws {
        let provider = try makeProvider()
        let ingredients = [ingredient(id: "local-water", text: "水")]
        let wireItems = try requestWireItems(provider, ingredients: ingredients)
        let wireID = try XCTUnwrap(wireItems[0]["id"] as? String)
        let validContent = try jsonString([
            "items": [outputItem(id: wireID, sourceText: "水")]
        ])

        assertRecognitionError(.authenticationFailed) {
            _ = try provider.decodeInsights(
                Data("not-json".utf8),
                httpResponse(statusCode: 401),
                ingredients
            )
        }
        assertRecognitionError(.serverUnavailable) {
            _ = try provider.decodeInsights(
                Data(),
                httpResponse(statusCode: 503),
                ingredients
            )
        }
        assertRecognitionError(.invalidResponse) {
            _ = try provider.decodeInsights(
                responseData(content: validContent, choiceCount: 0),
                httpResponse(),
                ingredients
            )
        }
        assertRecognitionError(.invalidResponse) {
            _ = try provider.decodeInsights(
                responseData(content: validContent, choiceCount: 2),
                httpResponse(),
                ingredients
            )
        }
        assertRecognitionError(.invalidResponse) {
            _ = try provider.decodeInsights(
                responseData(content: validContent, role: "user"),
                httpResponse(),
                ingredients
            )
        }
        assertRecognitionError(.responseTruncated) {
            _ = try provider.decodeInsights(
                responseData(content: validContent, finishReason: "length"),
                httpResponse(),
                ingredients
            )
        }
        assertRecognitionError(.requestRejected) {
            _ = try provider.decodeInsights(
                responseData(
                    content: validContent,
                    finishReason: "content_filter"
                ),
                httpResponse(),
                ingredients
            )
        }
        assertRecognitionError(.invalidResponse) {
            _ = try provider.decodeInsights(
                responseData(content: validContent, finishReason: "tool_calls"),
                httpResponse(),
                ingredients
            )
        }

        let topLevelError = try JSONSerialization.data(withJSONObject: [
            "error": ["message": "provider failed"],
            "choices": [[
                "finish_reason": "stop",
                "message": ["role": "assistant", "content": validContent]
            ]]
        ])
        assertRecognitionError(.invalidResponse) {
            _ = try provider.decodeInsights(
                topLevelError,
                httpResponse(),
                ingredients
            )
        }
    }

    private func makeProvider(
        apiKey: String = "dummy-analysis-key"
    ) throws -> IngredientAnalysisAPIProvider {
        let configuration = try XCTUnwrap(
            OpenRouterConfiguration(apiKey: apiKey)
        )
        return .openRouter(configuration: configuration)
    }

    private func ingredient(
        id: String,
        text: String,
        kind: IngredientToken.Kind = .ordinaryIngredient,
        matchedAdditiveID: String? = nil,
        matchedAdditiveName: String? = nil,
        matchedViaReviewedCorrection: Bool = false
    ) -> IngredientToken {
        IngredientToken(
            id: id,
            text: text,
            kind: kind,
            matchedAdditiveID: matchedAdditiveID,
            matchedAdditiveName: matchedAdditiveName,
            matchedViaReviewedCorrection: matchedViaReviewedCorrection
        )
    }

    private func requestWireItems(
        _ provider: IngredientAnalysisAPIProvider,
        ingredients: [IngredientToken]
    ) throws -> [[String: Any]] {
        let request = try provider.makeRequest(ingredients)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let messages = try XCTUnwrap(object["messages"] as? [[String: Any]])
        let userContent = try XCTUnwrap(messages[1]["content"] as? String)
        let input = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(userContent.utf8))
                as? [String: Any]
        )
        return try XCTUnwrap(input["items"] as? [[String: Any]])
    }

    private func outputItem(
        id: String,
        sourceText: String,
        category: String = "ordinary_food",
        commonRole: String = "食品原料",
        analysis: String = "常见食品配料。",
        reviewNote: Any = NSNull(),
        confidence: String = "high"
    ) -> [String: Any] {
        [
            "id": id,
            "source_text": sourceText,
            "category": category,
            "common_role": commonRole,
            "analysis": analysis,
            "review_note": reviewNote,
            "confidence": confidence
        ]
    }

    private func responseData(
        items: [[String: Any]],
        finishReason: String? = "stop",
        role: String = "assistant",
        choiceCount: Int = 1
    ) throws -> Data {
        try responseData(
            content: jsonString(["items": items]),
            finishReason: finishReason,
            role: role,
            choiceCount: choiceCount
        )
    }

    private func responseData(
        content: String,
        finishReason: String? = "stop",
        role: String = "assistant",
        choiceCount: Int = 1
    ) throws -> Data {
        var choice: [String: Any] = [
            "message": ["role": role, "content": content]
        ]
        if let finishReason {
            choice["finish_reason"] = finishReason
        }
        return try JSONSerialization.data(withJSONObject: [
            "id": "generation-analysis-test",
            "model": "z-ai/glm-5.3-flash",
            "usage": [
                "prompt_tokens": 120,
                "completion_tokens": 80,
                "cost": 0.001
            ],
            "choices": Array(repeating: choice, count: choiceCount)
        ])
    }

    private func jsonString(_ object: Any) throws -> String {
        String(
            decoding: try JSONSerialization.data(withJSONObject: object),
            as: UTF8.self
        )
    }

    private func httpResponse(statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: endpoint,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func assertRecognitionError(
        _ expected: RecognitionServiceError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () throws -> Void
    ) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            XCTAssertEqual(
                error as? RecognitionServiceError,
                expected,
                file: file,
                line: line
            )
        }
    }
}
