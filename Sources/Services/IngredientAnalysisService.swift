import Foundation
import SwiftUI

enum OnlineAnalysisConsent {
    /// Increment whenever the provider, transmitted fields, or retention disclosure changes.
    static let currentVersion = 1
}

struct IngredientAnalysisHTTPTransport: @unchecked Sendable {
    let send: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(send: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.send = send
    }

    static func ephemeral(timeout: TimeInterval = 45) -> IngredientAnalysisHTTPTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        let session = URLSession(
            configuration: configuration,
            delegate: RejectRedirectDelegate.shared,
            delegateQueue: nil
        )

        return IngredientAnalysisHTTPTransport { request in
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw RecognitionServiceError.invalidResponse
            }
            return (data, response)
        }
    }

    static let live = IngredientAnalysisHTTPTransport.ephemeral()
}

private final class RejectRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = RejectRedirectDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

struct RemoteIngredientAnalyzer: @unchecked Sendable {
    let isConfigured: Bool
    private let operation: @Sendable ([IngredientToken]) async throws -> [IngredientInsight]

    init(
        isConfigured: Bool = true,
        operation: @escaping @Sendable ([IngredientToken]) async throws -> [IngredientInsight]
    ) {
        self.isConfigured = isConfigured
        self.operation = operation
    }

    func analyze(_ tokens: [IngredientToken]) async throws -> [IngredientInsight] {
        try await operation(tokens)
    }

    static let unconfigured = RemoteIngredientAnalyzer(isConfigured: false) { _ in
        throw RecognitionServiceError.apiNotConfigured
    }

    static func openRouter(
        configuration: OpenRouterConfiguration,
        transport: IngredientAnalysisHTTPTransport = .live
    ) -> RemoteIngredientAnalyzer {
        let provider = IngredientAnalysisAPIProvider.openRouter(configuration: configuration)
        return RemoteIngredientAnalyzer { tokens in
            let request = try provider.makeRequest(tokens)
            try validateOpenRouterRequest(request)

            let data: Data
            let response: HTTPURLResponse
            do {
                (data, response) = try await transport.send(request)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as RecognitionServiceError {
                throw error
            } catch let error as URLError {
                throw mapTransportError(error)
            } catch {
                if Task.isCancelled { throw CancellationError() }
                throw RecognitionServiceError.transportFailure
            }

            try Task.checkCancellation()
            guard data.count <= 512_000 else {
                throw RecognitionServiceError.invalidResponse
            }
            try validateHTTPStatus(response.statusCode)
            return try provider.decodeInsights(data, response, tokens)
        }
    }
}

struct IngredientAnalysisService: @unchecked Sendable {
    static let maximumIngredientCount = 100
    static let maximumBatchCount = 20
    static let maximumIngredientLength = 160
    static let maximumTotalLength = 6_000

    private let remoteAnalyzer: RemoteIngredientAnalyzer

    var isAPIConfigured: Bool { remoteAnalyzer.isConfigured }

    init(remoteAnalyzer: RemoteIngredientAnalyzer) {
        self.remoteAnalyzer = remoteAnalyzer
    }

    func analyze(
        text: String,
        profile: UserProfile,
        using mode: AnalysisMode,
        consentVersion: Int?
    ) async throws -> AnalysisResult {
        let localResult = IngredientAnalyzer.analyze(text: text, profile: profile)
        guard mode == .api else { return localResult }

        guard consentVersion == OnlineAnalysisConsent.currentVersion else {
            throw RecognitionServiceError.onlineConsentRequired
        }
        guard remoteAnalyzer.isConfigured else {
            throw RecognitionServiceError.apiNotConfigured
        }

        let tokens = localResult.ingredientTokens
        try validateTokensForOnlineAnalysis(tokens)

        var insights: [IngredientInsight] = []
        insights.reserveCapacity(tokens.count)
        for start in stride(from: 0, to: tokens.count, by: Self.maximumBatchCount) {
            try Task.checkCancellation()
            let end = min(start + Self.maximumBatchCount, tokens.count)
            let batch = Array(tokens[start..<end])
            let batchInsights = try await remoteAnalyzer.analyze(batch)
            guard batchInsights.map(\.id) == batch.map(\.id) else {
                throw RecognitionServiceError.invalidResponse
            }
            insights.append(contentsOf: batchInsights)
        }

        try Task.checkCancellation()
        return AnalysisResult(
            recognizedText: localResult.recognizedText,
            additives: localResult.additives,
            safetyScore: localResult.safetyScore,
            overallRisk: localResult.overallRisk,
            summary: localResult.summary,
            ingredientTokens: localResult.ingredientTokens,
            ingredientInsights: insights,
            analysisSource: .openRouter
        )
    }

    static let live = makeLive(configuration: OpenRouterConfiguration.localDevelopment())

    static func makeLive(configuration: OpenRouterConfiguration?) -> IngredientAnalysisService {
        IngredientAnalysisService(
            remoteAnalyzer: configuration.map {
                RemoteIngredientAnalyzer.openRouter(configuration: $0)
            }
                ?? .unconfigured
        )
    }

    private func validateTokensForOnlineAnalysis(_ tokens: [IngredientToken]) throws {
        guard !tokens.isEmpty else {
            throw RecognitionServiceError.noIngredientsFound
        }
        guard tokens.count <= Self.maximumIngredientCount else {
            throw RecognitionServiceError.payloadTooLarge
        }

        let totalLength = tokens.reduce(0) { $0 + $1.text.count }
        guard totalLength <= Self.maximumTotalLength else {
            throw RecognitionServiceError.payloadTooLarge
        }

        let ids = tokens.map(\.id)
        guard Set(ids).count == ids.count,
              tokens.allSatisfy({ token in
                  let text = token.text.trimmingCharacters(in: .whitespacesAndNewlines)
                  return !text.isEmpty
                      && text == token.text
                      && text.count <= Self.maximumIngredientLength
                      && !text.unicodeScalars.contains(where: { scalar in
                          CharacterSet.controlCharacters.contains(scalar)
                      })
              }) else {
            throw RecognitionServiceError.invalidRequest
        }
    }
}

private struct IngredientAnalysisServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue = IngredientAnalysisService.live
}

extension EnvironmentValues {
    var ingredientAnalysisService: IngredientAnalysisService {
        get { self[IngredientAnalysisServiceEnvironmentKey.self] }
        set { self[IngredientAnalysisServiceEnvironmentKey.self] = newValue }
    }
}

private func validateOpenRouterRequest(_ request: URLRequest) throws {
    guard let url = request.url,
          url.scheme?.lowercased() == "https",
          url.host?.lowercased() == "openrouter.ai",
          url.port == nil || url.port == 443,
          url.path == "/api/v1/chat/completions"
    else {
        throw RecognitionServiceError.invalidEndpoint
    }
    guard request.httpMethod == "POST",
          request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true,
          request.httpBody?.isEmpty == false else {
        throw RecognitionServiceError.invalidRequest
    }
}

private func validateHTTPStatus(_ statusCode: Int) throws {
    switch statusCode {
    case 200..<300: return
    case 400, 422: throw RecognitionServiceError.invalidRequest
    case 401: throw RecognitionServiceError.authenticationFailed
    case 402: throw RecognitionServiceError.insufficientCredits
    case 403: throw RecognitionServiceError.requestRejected
    case 404: throw RecognitionServiceError.modelUnavailable
    case 408: throw RecognitionServiceError.timedOut
    case 413: throw RecognitionServiceError.payloadTooLarge
    case 429: throw RecognitionServiceError.rateLimited
    case 500..<600: throw RecognitionServiceError.serverUnavailable
    default: throw RecognitionServiceError.unexpectedStatus(statusCode)
    }
}

private func mapTransportError(_ error: URLError) -> Error {
    switch error.code {
    case .cancelled: CancellationError()
    case .timedOut: RecognitionServiceError.timedOut
    case .notConnectedToInternet,
         .networkConnectionLost,
         .cannotFindHost,
         .cannotConnectToHost,
         .dnsLookupFailed,
         .internationalRoamingOff,
         .dataNotAllowed:
        RecognitionServiceError.noConnection
    default:
        RecognitionServiceError.transportFailure
    }
}
